#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   A listening socket connection used by the Alarm Daemon

=head1 NAME

AlarmDaemon::ListenSocket - A listening socket connection used by the Alarm Daemon

=head1 DESCRIPTION

This class implements a listening socket.

=head1 METHODS

=over

=cut

package AlarmDaemon::ListenSocket;

use strict;


# ---------------------------------------------------------------------------

=item new($socket, $handler)

Create a new listening socket.

=cut

sub new {
	my ($class, $socket, $handler) = @_;

	if (! $socket) {
		return undef;
	}

	my $self = {
		socket => $socket,
		handler => $handler,
	};

	bless $self, $class;

	return $self;
}


# ---------------------------------------------------------------------------

=item socket()

Return the Socket connection.

=cut

sub socket {
	my ($self) = @_;

	return $self->{socket};
}


# ---------------------------------------------------------------------------

=item send($buffer)

Send the data to the socket.

=cut

sub send {
	my ($self, $buffer) = @_;

	die "Cannot send data to a listening socket";
}


# ---------------------------------------------------------------------------

=item disconnect()

If the socket is currently open, then close it and forget it.

=cut

sub disconnect {
	my ($self) = @_;

	if ($self->{socket}) {
		close($self->{socket});
		undef $self->{socket};
	}
}


# ------------------------------------------------------------------------

=item handleRead()

This socket has 'data available for read'. That means a new connection
to accept.

=cut

sub handleRead {
	my ($self, $selector, $socket) = @_;

	my $handler = $self->{handler};
	my ($new_sock, $address) = $socket->accept();

	if (! $address) {
		warn "Socket accept failed\n";
		return;
	}

	# How to setup the new socket?
	$handler->addClient($new_sock);
}

=back

=cut

1;
