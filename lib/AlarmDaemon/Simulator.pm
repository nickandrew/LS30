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
		settings       => {},
		settings_file  => undef,
	};

	bless $self, $class;

	return $self;
}

=item I<settingsFile($filename)>

Set (and load) YAML file containing default/initial settings

=cut

sub settingsFile {
	my ($self, $filename) = @_;

	if (!-r $filename) {
		die "Cannot read settings file: $filename";
	}

	$self->{settings} = YAML::LoadFile($filename);
	$self->{settings_file} = $filename;
}

=item I<addListener($socket)>

Listen on the specified socket for incoming connections. The simulator
can listen on several sockets.

=cut

sub addListener {
	my ($self, $socket) = @_;

	my $listener = AlarmDaemon::ListenSocket->new($socket, $self);
	if (!$listener) {
		LS30::Log::error("Unable to add listener");
		return;
	}

	$self->{listeners}->{$socket} = $listener;
	return $self;
}

=item I<addClient($socket)>

This function is called by the listening socket whenever a new
client connects.

=cut

sub addClient {
	my ($self, $socket) = @_;

	my $client = AlarmDaemon::ClientSocket->new($socket, $self);
	$self->{client_sockets}->{$socket} = $client;
	$self->{clients}++;

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

	# This should be good enough to parse most commands, too
	my $cmd = LS30Command::parseResponse($input);

	if (!$cmd) {
		# Oops
		return undef;
	}

	if ($cmd->{error}) {
		# Oops
		return undef;
	}

	if ($cmd->{action}) {
		if ($cmd->{action} eq 'query') {
			my $variable = $cmd->{title};
			if (!LS30Command::isSetting($variable)) {
				return undef;
			}
			my $value = $self->{settings}->{$variable}->{value};
			$value = '' if (!defined $value);

			my $saved_response = $self->{settings}->{$variable}->{response};

			my $args = {
				title => $variable,
				action => 'query',
				value => $value,
			};

			my $string = LS30Command::formatResponse($args);
			return $string;
		}
		elsif ($cmd->{action} eq 'set') {
			# TODO extract value, modify settings
			# TODO format a response
		}
		else {
			# TODO what?
		}
	} else {
		# TODO what?
	}
}

=back

=cut

1;
