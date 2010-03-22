#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
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


# ---------------------------------------------------------------------------

=item new($socket)

Return a new instance of AlarmDaemon::ClientSocket for the specified socket.

=cut

sub new {
	my ($class, $socket) = @_;

	my $self = {
		socket => $socket,
	};

	bless $self, $class;

	return $self;
}


# ---------------------------------------------------------------------------

=item socket()

Return a reference to our socket connection.

=cut

sub socket {
	my ($self) = @_;

	return $self->{socket};
}


# ---------------------------------------------------------------------------

=item send($buffer)

If connected, send data to our socket connection.

=cut

sub send {
	my ($self, $buffer) = @_;

	if ($self->{socket}) {
		$self->{socket}->send($buffer);
	}
}


# ---------------------------------------------------------------------------

=item disconnect()

If connected, close our socket and forget it.

=cut

sub disconnect {
	my ($self) = @_;

	if ($self->{socket}) {
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

=item ($length, $buffer) = doRead()

Read data from the socket. Return the number of characters read,
and the data in a buffer.

Upon socket error, return undef. Upon EOF, return -1.
Otherwise, the number of characters returned can be > 0.

=cut

sub doRead {
	my ($self) = @_;

	my $buffer;
	$self->{last_rcvd_time} = time();

	my $n = $self->{socket}->recv($buffer, 128);
	if (!defined $n) {
		return (undef, undef);
	}

	my $l = length($buffer);

	if ($l == 0) {
		return -1;
	}

	return ($l, $buffer);
}

1;
