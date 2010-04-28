#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
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

use AlarmDaemon::ClientSocket qw();
use AlarmDaemon::ListenSocket qw();
use AlarmDaemon::ServerSocket qw();
use LS30::Log qw();
use Selector qw();

sub new {
	my ($class) = @_;

	my $self = {
		clients => 0,
		client_sockets => { },
		pending_data => undef,
		selector => undef,
		server => undef,
	};

	bless $self, $class;

	$self->{selector} = Selector->new();

	return $self;
}

sub addListener {
	my ($self, $socket) = @_;

	my $listener = AlarmDaemon::ListenSocket->new($socket, $self);
	if (! $listener) {
		warn "Unable to add listener\n";
		return;
	}

	$self->{selector}->addSelect([$socket, $listener]);
}

sub addServer {
	my ($self, $peer_addr) = @_;

	my $object = AlarmDaemon::ServerSocket->new($peer_addr);
	if (! $object) {
		warn "Unable to instantiate an AlarmDaemon::ServerSocket to $peer_addr\n";
		return;
	}

	$object->setHandler($self);
	$self->{server} = $object;
	$self->{selector}->addObject($object);
}

sub addClient {
	my ($self, $socket) = @_;

	LS30::Log::timePrint("New client");
	my $client = AlarmDaemon::ClientSocket->new($socket, $self);
	$self->{client_sockets}->{$socket} = $client;
	$self->{selector}->addSelect( [$socket, $client] );
	$self->{clients} ++;

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
		$self->{selector}->removeSelect( [$socket, $client] );
		delete $self->{client_sockets}->{$socket};
		$self->{clients} --;
		LS30::Log::timePrint("Removed client");
	}
}

sub eventLoop {
	my ($self) = @_;

	$self->{selector}->eventLoop();
}

sub serverRead {
	my ($self, $buffer) = @_;

	if ($self->{clients} == 0) {
		LS30::Log::timePrint("Pending: $buffer");
		$self->{pending_data} .= $buffer;
		return;
	}

	my $rest = '';
	if ($self->{clients} > 1) {
		$rest = " to $self->{clients} clients";
	}

	LS30::Log::timePrint("Emitting: $buffer$rest");

	foreach my $object (values %{$self->{client_sockets}}) {
		$object->send($buffer);
	}
}

sub clientRead {
	my ($self, $buffer) = @_;

	$self->{server}->send($buffer);
}

1;
