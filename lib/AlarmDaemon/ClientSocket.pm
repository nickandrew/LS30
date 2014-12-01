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

use AlarmDaemon::CommonSocket qw();

use base qw(AlarmDaemon::CommonSocket);


# ---------------------------------------------------------------------------

=item new($selector, $socket, $handler)

Return a new instance of AlarmDaemon::ClientSocket for the specified socket.

=cut

sub new {
	my ($class, $selector, $socket, $handler) = @_;

	my $self = {
		socket   => $socket,
		selector => $selector,
		handler  => $handler,
	};

	bless $self, $class;

	$self->{selector}->addObject($self);

	return $self;
}


# ---------------------------------------------------------------------------

=item disconnect()

If connected, close our socket and forget it.

=cut

sub disconnect {
	my ($self) = @_;

	if ($self->{socket}) {
		$self->{selector}->removeSelect($self->socket());
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

Read data from the socket. Pass it to our handler object.

=cut

sub handleRead {
	my ($self, $selector, $socket) = @_;

	my $buffer;
	my $handler = $self->{handler};

	my $n = $self->{socket}->recv($buffer, 128);
	if (!defined $n) {

		# Error on the socket
		LS30::Log::timePrint("Client socket error");
		$handler->removeClient($self);
		$self->disconnect();
		return;
	}

	my $l = length($buffer);

	if ($l == 0) {

		# Other end closed connection
		$handler->removeClient($self);
		$self->disconnect();
		return;
	}

	$handler->clientRead($buffer);
}

1;
