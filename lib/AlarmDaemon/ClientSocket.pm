#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

AlarmDaemon::ClientSocket - A client socket

=head1 DESCRIPTION

This class maintains a socket connection to a client.

=head1 METHODS

=over

=cut

package AlarmDaemon::ClientSocket;

use strict;
use warnings;

use AlarmDaemon::CommonSocket qw();

use base qw(AlarmDaemon::CommonSocket);


# ---------------------------------------------------------------------------

=item new($socket)

Return a new instance of AlarmDaemon::ClientSocket for the specified socket.

=cut

sub new {
	my ($class, $socket) = @_;

	my $self = {
		socket   => $socket,
	};

	bless $self, $class;

	$self->_defineonfunc('Disconnect');
	$self->_defineonfunc('Read');

	$self->{poller} = AnyEvent->io(
		fh   => $socket,
		poll => 'r',
		cb   => sub {
			$self->handleRead();
		}
	);

	return $self;
}


# ---------------------------------------------------------------------------

=item disconnect()

If connected, close our socket and forget it.

=cut

sub disconnect {
	my ($self) = @_;

	if ($self->{socket}) {
		delete $self->{poller};
		close($self->{socket});
		undef $self->{socket};
	}
}


# ---------------------------------------------------------------------------

=item watchdogTime()

Not currently defined. Return undef.

=cut

sub watchdogTime {
	my ($self) = @_;

	return undef;
}


# ---------------------------------------------------------------------------

=item watchdogEvent()

Not currently defined. Return undef.

=cut

sub watchdogEvent {
	my ($self) = @_;

	return undef;
}


# ------------------------------------------------------------------------

=item handleRead()

Read data from the socket. Call onRead/onDisconnect functions as appropriate.

=cut

sub handleRead {
	my ($self) = @_;

	my $buffer;

	my $n = $self->{socket}->recv($buffer, 128);

	if (!defined $n) {

		# Error on the socket
		LS30::Log::error("Client socket error");
		$self->_runonfunc('Disconnect');
		$self->disconnect();
		return;
	}

	my $l = length($buffer);

	if ($l == 0) {

		# Other end closed connection
		$self->_runonfunc('Disconnect');
		$self->disconnect();
		return;
	}

	$self->_runonfunc('Read', $buffer);
}

1;
