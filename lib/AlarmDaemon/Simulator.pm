#!/usr/bin/env perl
#   Copyright (C) 2010-2016, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

AlarmDaemon::Simulator - Connect clients and listeners

=head1 DESCRIPTION

This class simulates an LS-30 alarm system. All the connected sockets
are clients. Any requests received from the clients are parsed and
actioned and appropriate responses sent.

There is also a set of listening sockets; connections on any of them
are accepted and become new clients.

=head1 METHODS

=over

=cut

package AlarmDaemon::Simulator;

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Date::Format qw(time2str);
use Date::Parse qw(str2time);
use YAML qw();

use AlarmDaemon::ClientSocket qw();
use AlarmDaemon::ListenSocket qw();
use AlarmDaemon::ServerSocket qw();
use LS30Connection qw();
use LS30Command qw();
use LS30::Commander qw();
use LS30::Log qw();
use AnyEvent;

# ---------------------------------------------------------------------------

=item I<new()>

Return a new instance of this simulator class.

=cut

sub new {
	my ($class) = @_;

	my $self = {
		clients        => 0,
		client_sockets => {},
		condvar        => AnyEvent->condvar,
		listeners      => {},
		state          => {},
		state_file     => undef,
	};

	bless $self, $class;

	return $self;
}

# ---------------------------------------------------------------------------
# Save updated state
# ---------------------------------------------------------------------------

sub _saveState {
	my ($self) = @_;

	if ($self->{state_file}) {
		YAML::DumpFile($self->{state_file}, $self->{state});
	}
}

=item I<stateFile($filename)>

Set (and load) YAML file containing default/initial state

=cut

sub stateFile {
	my ($self, $filename) = @_;

	if (!-r $filename) {
		die "Cannot read state file: $filename";
	}

	$self->{state} = YAML::LoadFile($filename);
	$self->{state_file} = $filename;
}

=item I<addListener($socket)>

Listen on the specified socket for incoming connections. The simulator
can listen on several sockets.

=cut

sub addListener {
	my ($self, $socket) = @_;

	my $listener = AlarmDaemon::ListenSocket->new($socket);
	if (!$listener) {
		LS30::Log::error("Unable to add listener");
		return;
	}

	$listener->onAccept(sub { $self->addClient(@_); });

	$self->{listeners}->{$socket} = $listener;
	return $self;
}

# ---------------------------------------------------------------------------

=item I<addRemoteClient($remote_addr)>

Add a new connection to a remote client. This process will initiate
the connection, and retry connect with exponential backoff upon
connection failure and accidental disconnection.

The other end is a client, not a server, so it's added to client_sockets.

=cut

sub addRemoteClient {
	my ($self, $remote_addr) = @_;

	my $client = AlarmDaemon::ServerSocket->new($remote_addr);

	$client->onConnectFail(sub { $client->retryConnect(); });
	$client->onRead(sub { $self->clientRead(shift, $client); });

	$client->onConnect(sub {
		LS30::Log::timePrint("Connected to " . $client->peerhost());
		$self->{client_sockets}->{$client} = $client;
		$self->{clients}++;
	});

	$client->onDisconnect(sub {
		LS30::Log::timePrint("Disconnected");
		if (exists $self->{client_sockets}->{$client}) {
			delete $self->{client_sockets}->{$client};
			$self->{clients}--;
		}

		$client->retryConnect();
	});

	# Try initial connection
	$client->connect();
}

# ---------------------------------------------------------------------------

=item I<addClient($socket)>

This function is called by the listening socket whenever a new
client connects.

=cut

sub addClient {
	my ($self, $socket) = @_;

	my $client = AlarmDaemon::ClientSocket->new($socket);
	$self->{client_sockets}->{$socket} = $client;
	$self->{clients}++;

	$client->onRead(sub { $self->clientRead(shift, $client); });
	$client->onDisconnect(sub { $self->removeClient($client); });

	LS30::Log::timePrint("New client " . $client->peerhost());
}

=item I<removeClient($client)>

This function is called by the client AlarmDaemon::ClientSocket
when the peer disconnects.

=cut

sub removeClient {
	my ($self, $client) = @_;

	my $socket = $client->socket();
	if (exists $self->{client_sockets}->{$socket}) {
		delete $self->{client_sockets}->{$socket};
		$self->{clients}--;
		LS30::Log::timePrint("Removed client " . $client->peerhost());
	}
}

=item I<eventLoop()>

Run the event loop. Since the daemon is expected to run forever, this
function never returns.

=cut

sub eventLoop {
	my ($self) = @_;

	$self->{condvar}->recv();
}

# ---------------------------------------------------------------------------
# Broadcast a string (followed by \r\n) to all connected clients
# ---------------------------------------------------------------------------

sub _sendAllClients {
	my ($self, $data) = @_;

	if ($self->{clients}) {
		LS30::Log::timePrint("Broadcast: $data");
	} else {
		LS30::Log::timePrint("Ignoring (no clients): $data");
	}

	foreach my $object (values %{ $self->{client_sockets} }) {
		$object->send($data . "\r\n");
	}
}

=item I<clientRead($data, $client)>

This function is called by a client object whenever data has been
received on that connection.

The received data is accumulated in a buffer. All strings up to & in the
buffer are treated as commands: the command is sent to the simulator engine,
and when a response is received, the response is sent back to the client.

That means responses are sent only to the client that requested it.

It also means requests can be queued for some time pending all other
requests being sent and responses received.

CRs and LFs in the input stream are ignored.

=cut

sub clientRead {
	my ($self, $data, $client) = @_;

	LS30::Log::timePrint("Received: $data");

	# Which client sent this?
	my $socket = $client->socket();
	my $buffer = $self->{client}->{$socket}->{buffer};
	$buffer .= $data;

	while (1) {
		# Clear out leading CR/LF
		if ($buffer =~ /^[\r\n]+(.*)/) {
			$buffer = $1;
			next;
		}

		if ($buffer !~ /^([^\r\n]*&)(.*)/) {
			# It's not a full command or it's a command with an error
			if ($buffer =~ /^(.*)\r?\n(.*)/) {
				my ($line, $rest) = ($1, $2);
				LS30::Log::timePrint("Ignored: $line");
				$buffer = $rest;
				next;
			}

			# Wait for more characters
			last;
		}

		my ($line, $rest) = ($1, $2);

		my $resp = $self->simulateCommand($line);
		if ($resp) {
			$client->send($resp . "\r\n");
		}

		$buffer = $rest;
	}

	$self->{client}->{$socket}->{buffer} = $buffer;
}

=item I<simulateCommand($string)>

Simulate receiving a command, actioning it, and sending back a
response. Return the response (sans CR LF).

=cut

sub simulateCommand {
	my ($self, $input) = @_;

	# Parse request string
	my $cmd = LS30Command::parseRequest($input);

	if (!$cmd) {
		# Oops
		LS30::Log::error("Unparseable command: <$input>");
		return undef;
	}

	if ($cmd->{error}) {
		# Oops
		my $error = $cmd->{error};
		LS30::Log::error("Unparseable command: <$input> error: $error");
		return undef;
	}

	my $subsys = $cmd->{subsys};
	my $action = $cmd->{action};

	if ($subsys eq 'settings') {
		if (!$cmd->{action}) {
			# What?
			return undef;
		}

		if ($cmd->{action} eq 'query') {
			my $variable = $cmd->{title};
			if (LS30Command::isSetting($variable)) {
				my $value = $self->{state}->{settings}->{$variable}->{value};
				$value = '' if (!defined $value);

				my $saved_response = $self->{state}->{settings}->{$variable}->{response};

				my $args = {
					title => $variable,
					action => 'query',
					value => $value,
				};

				my $string = LS30Command::formatResponse($args);
				return $string;
			}

			# Query other non-setting things
			if ($variable eq 'Information Burglar Sensor') {
				return '!ibno&';
			}

			if ($variable eq 'Information Controller') {
				return '!icno&';
			}

			if ($variable eq 'Information Fire Sensor') {
				return '!ifno&';
			}

			LS30::Log::error("Not a setting: $variable");
			return $input;
		}
		elsif ($cmd->{action} eq 'set') {

			my $variable = $cmd->{title};
			if (LS30Command::isSetting($variable)) {
				$self->{state}->{settings}->{$variable}->{value} = $cmd->{value};
				$self->_saveState();
			} else {
				LS30::Log::error("Not a setting: $variable");
				return $input;
			}

			# Cheat a bit and make the response the same as the request
			return $input;
		}
		elsif ($cmd->{action} eq 'clear') {

			my $variable = $cmd->{title};
			if (!LS30Command::canClear($variable)) {
				LS30::Log::error("Not clearable: $variable");
				return $input;
			}

			$self->{state}->{settings}->{$variable}->{value} = '';
			$self->_saveState();
			# Cheat a bit and make the response the same as the request
			return $input;
		}
	}
	elsif ($subsys eq 'eventlog') {
		# Pretend there's only 1 event in the log
		return '!ev13840101030101281159001&';
	}
	elsif ($subsys eq 'datetime') {
		my $now = time();

		if ($action eq 'set') {
			# Calculate an offset between current time and set time
			my $then = str2time("$cmd->{date} $cmd->{time}");
			$self->{state}->{datetime}->{offset} = $then - $now;
			$self->_saveState();
			return $input;
		}

		# query
		my $offset = $self->{state}->{datetime}->{offset} || 0;
		my $args = {
			title => 'Date/Time',
			date  => time2str('%Y-%m-%d', $now + $offset),
			time  => time2str('%T', $now + $offset),
			dow   => time2str('%a', $now + $offset),
		};

		my $response = LS30Command::formatResponse($args);
		return $response;
	}
	elsif ($subsys eq 'cms') {
		# '!l5&' who knows what it means
		return $input;
	}

	# No response is the best response
	return undef;
}

=back

=cut

1;
