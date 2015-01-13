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

sub new {
	my ($class) = @_;

	my $self = {
		clients        => 0,
		client_sockets => {},
		condvar        => AnyEvent->condvar,
		listeners      => {},
		pending_data   => undef,
		server         => undef,
	};

	bless $self, $class;

	return $self;
}

sub addListener {
	my ($self, $socket) = @_;

	my $listener = AlarmDaemon::ListenSocket->new($socket, $self);
	if (!$listener) {
		LS30::Log::timePrint("Unable to add listener");
		return;
	}

	$self->{listeners}->{$socket} = $listener;
	return $self;
}

sub addServer {
	my ($self, $peer_addr) = @_;

	my $object = LS30Connection->new($peer_addr);
	if (!$object) {
		LS30::Log::timePrint("Unable to instantiate an LS30Connection to $peer_addr");
		return;
	}

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

sub addClient {
	my ($self, $socket) = @_;

	my $client = AlarmDaemon::ClientSocket->new($socket, $self);
	$self->{client_sockets}->{$socket} = $client;
	$self->{clients}++;

	LS30::Log::timePrint("New client " . $client->peerhost());

	if (defined $self->{pending_data}) {
		LS30::Log::timePrint("Sent pending: $self->{pending_data}");
		$client->send($self->{pending_data});
		$self->{pending_data} = undef;
	}
}

sub removeClient {
	my ($self, $client) = @_;

	my $socket = $client->socket();
	if (exists $self->{client_sockets}->{$socket}) {
		delete $self->{client_sockets}->{$socket};
		$self->{clients}--;
		LS30::Log::timePrint("Removed client " . $client->peerhost());
	}
}

sub eventLoop {
	my ($self) = @_;

	$self->{condvar}->recv();
}

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

sub clientRead {
	my ($self, $data, $client) = @_;

	LS30::Log::timePrint("Received: $data");

	# Which client sent this?
	my $socket = $client->socket();
	my $buffer = $self->{client}->{$socket}->{buffer};
	$buffer .= $data;

	while ($buffer =~ /^([^\r\n]*\r?\n)(.*)/) {
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

1;
