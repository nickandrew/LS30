#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Common code for sockets - abstract superclass

=head1 NAME

AlarmDaemon::CommonSocket - abstract Socket superclass

=head1 DESCRIPTION

This class contains methods common to all the Socket classes

=head1 METHODS

=over

=cut

use strict;

package AlarmDaemon::CommonSocket;


# ---------------------------------------------------------------------------

=item socket()

Return a reference to our socket.

=cut

sub socket {
	my ($self) = @_;

	return $self->{socket};
}


# ---------------------------------------------------------------------------

=item send($buffer)

If connected, send data to our socket.

=cut

sub send {
	my ($self, $buffer) = @_;

	if ($self->{socket}) {
		$self->{socket}->send($buffer);
	}
}

=back

=cut

1;
