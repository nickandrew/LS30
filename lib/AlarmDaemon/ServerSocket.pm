#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   A server socket connection used by the Alarm Daemon

=head1 NAME

AlarmDaemon::ServerSocket - A server socket connection used by the Alarm Daemon

=head1 DESCRIPTION

This class implements a socket connection to an LS30 server. It sanitises the
data received from the socket, because the LS30 uses inconsistent end-of-line
markers and sometimes garbles its transmission by sending one line inside
another.

=head1 METHODS

=over

=cut

package AlarmDaemon::ServerSocket;

use strict;

use IO::Socket::INET qw();
use Socket qw();

use LS30::Log qw();


# ---------------------------------------------------------------------------

=item new($peer_addr, $handler)

Connect to the server (identified as host:port) and return the newly
instantiated AlarmDaemon::ServerSocket object. If unable to connect,
return undef.

=cut

sub new {
	my ($class, $peer_addr, $handler) = @_;

	my $self = {
		peer_addr => $peer_addr,
		handler => $handler,
		watchdog_interval => 600,
		eol_state => 1,
	};

	bless $self, $class;

	if (!  $self->connect()) {
		return undef;
	}

	return $self;
}


# ---------------------------------------------------------------------------

=item socket()

Return the IO::Socket::INET connection.

=cut

sub socket {
	my ($self) = @_;

	return $self->{socket};
}


# ---------------------------------------------------------------------------

=item connect()

Connect to our server. Set SO_KEEPALIVE so we detect a broken connection
eventually (many minutes). Also set our last_rcvd_time to the current
time to detect quicker if the server has gone away.

=cut

sub connect {
	my ($self) = @_;

	my $socket = IO::Socket::INET->new(
		PeerAddr => $self->{peer_addr},
		Proto => 'tcp',
		Type => IO::Socket::SOCK_STREAM(),
	);

	if ($socket) {
		$self->{socket} = $socket;
		$self->{last_rcvd_time} = time();

		# Setting SO_KEEPALIVE will eventually cause a client socket error if
		# connection is broken
		if (! setsockopt($socket, Socket::SOL_SOCKET(), Socket::SO_KEEPALIVE(), 1)) {
			warn "Unable to set keepalive\n";
		};

		return 1;
	}

	return 0;
}


# ---------------------------------------------------------------------------

=item send($buffer)

Send the data to the socket.

=cut

sub send {
	my ($self, $buffer) = @_;

	if ($self->{socket}) {
		$self->{socket}->send($buffer);
	}
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


# ---------------------------------------------------------------------------

=item timeout()

Called when there is a watchdog timeout (i.e. no data received from the
server within a configurable amount of time).

Currently broken.

=cut

sub timeout {
	my ($self) = @_;

	die "timeout() broken";

	print "Timeout: $self\n";
	$self->disconnect();
	$self->connect();
	print "Reconnected\n";
}


# ---------------------------------------------------------------------------

=item watchdogTime()

Returns a time_t value representing at what time this object will detect
a timeout, if no recent data has been received from the server.

Currently broken.

=cut

sub watchdogTime {
	my ($self) = @_;

	if ($self->{last_rcvd_time}) {
		return $self->{last_rcvd_time} + $self->{watchdog_interval};
	}

	return undef;
}


# ---------------------------------------------------------------------------

=item watchdogEvent()

Called when the watchdog timer expires. Currently do nothing.

=cut

sub watchdogEvent {
	my ($self) = @_;

}


# ------------------------------------------------------------------------

=item doRead()

Read data from the socket. Postprocess it, and return the number of
cooked characters read, and the data in a buffer.
Upon socket error, return undef. Upon EOF, return -1.
Otherwise, the number of characters returned can be >= 0.

=cut

sub doRead {
	my ($self) = @_;

	my $buffer;
	$self->{last_rcvd_time} = time();

	my $n = $self->{socket}->recv($buffer, 128);
	if (!defined $n) {
		return (undef, undef);
	}

	if (length($buffer) == 0) {
		return -1;
	}

	return $self->filterInput($buffer);
}


# ------------------------------------------------------------------------

=item handleRead()

Read data from the socket. Postprocess it, and call our handler's
serverRead() function with the result.

=cut

sub handleRead {
	my ($self) = @_;

	my $buffer;
	$self->{last_rcvd_time} = time();

	my $n = $self->{socket}->recv($buffer, 128);
	if (!defined $n) {
		return;
	}

	if (length($buffer) == 0) {
		return;
	}

	my ($l, $data) = $self->filterInput($buffer);
	if ($l > 0) {
		$self->{handler}->serverRead($data);
	}
}


# ---------------------------------------------------------------------------

=item filterInput($buffer)

Filter data received from the LS30 to clean up the protocol.

The LS30 output is pretty unclean, with varying numbers of \r and \n
at times. Examples:

  Received: (1688181602005009)\r\n
  Received: \nMINPIC=0a585012345600108b6173\r\n
  Received: (1688181602005009)\r\nATE0\r\nATS0=3\r\nAT&G7\r\n
  Received: \nMINPIC=0a14101234560000846173\r\n\r\n\n(16881814000100
  Received: 2f)\r\n

So: sequences of \r and \n are filtered to a single \r\n
Otherwise, the buffer contents are emitted unchanged

Return the number of characters emitted and the string.

=cut

sub filterInput {
	my ($self, $buffer) = @_;

	LS30::Log::timePrint("Input: $buffer");
	$buffer =~ s/[\r\n]+/\r\n/gs;

	if ($self->{eol_state}) {
		# We are at end of line already, so cut any leading \r\n from the buffer
		$buffer =~ s/^\r\n//s;
	}

	# If we finished with a \n, then we are at eol for next time through
	if ($buffer ne '') {
		if (substr($buffer, length($buffer) - 1, 1) eq "\n") {
			$self->{eol_state} = 1;
		} else {
			$self->{eol_state} = 0;
		}
	}

	return (length($buffer), $buffer);
}

=back

=cut

1;
