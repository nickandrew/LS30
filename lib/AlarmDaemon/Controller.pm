#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#  Act as a proxy, logging all comms to and from a remote host/port

=head1 NAME

AlarmDaemon::Controller - Connect server, clients and listeners

=head1 DESCRIPTION

This class connects clients and servers such that data received from
any client is forwarded to the (single) server. Any data received
from the server is forwarded to all clients. There is also a set
of listening sockets; connections on any of them are accepted and
become new clients.

=head1 METHODS

=over

=cut

package AlarmDaemon::Controller;

use strict;
use warnings;

use AlarmDaemon::ClientSocket qw();
use AlarmDaemon::ListenSocket qw();
use AlarmDaemon::ServerSocket qw();
use LS30Connection qw();
use LS30::Commander qw();
use LS30::Log qw();
use AnyEvent;


=item I<new()>

Return a new instance of this controller class.

=cut

sub new {
	my ($class) = @_;

	my $self = {
		clients        => 0,
		client_sockets => {},
		condvar        => AnyEvent->condvar,
		listeners      => {},
		server         => undef,
	};

	bless $self, $class;

	return $self;
}

=item I<addListener($socket)>

Listen on the specified socket for incoming connections. The controller
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

=item I<addServer($peer_addr)>

Connect to the specified peer address, which is our server device.

Only a single server may be used at one time.

=cut

sub addServer {
	my ($self, $peer_addr) = @_;

	my $object = LS30Connection->new($peer_addr, reconnect => 1);
	if (!$object) {
		LS30::Log::error("Unable to instantiate an LS30Connection to $peer_addr");
		return;
	}

	$object->connect();

	# Broadcast all added_device events to all clients
	$object->onAddedDevice(sub { $self->_sendAllClients(@_); });

	my $ls30cmdr = LS30::Commander->new($object, 5);
	if (!$ls30cmdr) {
		die "Unable to instantiate a new LS30::Commander to $peer_addr";
	}

	$self->{server} = $ls30cmdr;

	$ls30cmdr->onMINPIC(sub {
		my ($minpic_string) = @_;
		$self->_sendAllClients('MINPIC=' . $minpic_string);
	});

	$ls30cmdr->onXINPIC(sub {
		my ($xinpic_string) = @_;
		$self->_sendAllClients('XINPIC=' . $xinpic_string);
	});

	$ls30cmdr->onCONTACTID(sub {
		my ($contactid_string) = @_;
		$self->_sendAllClients('(' . $contactid_string . ')');
	});
}

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
buffer are treated as commands: the command is queued to the server,
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

		my $cv = $self->{server}->queueCommand($line);
		$cv->cb(sub {
			my $resp = $cv->recv();
			# send this response back to the client

			LS30::Log::timePrint("Response: $resp");
			$client->send($resp . "\r\n");
		});

		$buffer = $rest;
	}

	$self->{client}->{$socket}->{buffer} = $buffer;
}

=back

=cut

1;
