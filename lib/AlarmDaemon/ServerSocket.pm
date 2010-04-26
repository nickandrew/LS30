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

use AlarmDaemon::SocketFactory qw();
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
		pending => '',
	};

	bless $self, $class;

	if (!  $self->connect()) {
		return undef;
	}

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

=item connect()

Connect to our server. Set SO_KEEPALIVE so we detect a broken connection
eventually (many minutes). Also set our last_rcvd_time to the current
time to detect quicker if the server has gone away.

=cut

sub connect {
	my ($self) = @_;

	my $socket = AlarmDaemon::SocketFactory->new(
		PeerAddr => $self->{peer_addr},
		Proto => 'tcp',
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
		# Error on the socket
		return;
	}

	if (length($buffer) == 0) {
		# EOF: Other end closed the connection
		return;
	}

	$self->addBuffer($buffer);
}


# ---------------------------------------------------------------------------

=item addBuffer($buffer)

Filter data received from the LS30 to clean up the protocol.

The LS30 output is pretty unclean, with varying numbers of \r and \n
at times. Examples:

  Received: (1688181602005009)\r\n
  Received: \nMINPIC=0a585012345600108b6173\r\n
  Received: (1688181602005009)\r\nATE0\r\nATS0=3\r\nAT&G7\r\n
  Received: \nMINPIC=0a14101234560000846173\r\n\r\n\n(16881814000100
  Received: 2f)\r\n

Add $buffer to our queue of data pending processing. Any complete lines
(lines ending in CR or LF) are passed to processLine().

=cut

sub addBuffer {
	my ($self, $buffer) = @_;

	$self->{pending} .= $buffer;
	my $pending = $self->{pending};

	while ($pending ne '') {

		if (substr($pending, 0, 1) eq "\r") {
			# Skip leading \r
			$pending = substr($pending, 1);
			next;
		}

		if (substr($pending, 0, 1) eq "\n") {
			# Skip leading \n
			$pending = substr($pending, 1);
			next;
		}

		if ($pending =~ /^([^\r\n]+)[\r\n]+(.*)/s) {
			# Here's a full line to process
			my $line = $1;
			$pending = $2;
			processLine($self, $line);
		} else {
			last;
		}
	}

	$self->{pending} = $pending;
}


# ---------------------------------------------------------------------------

=item processLine($line)

Process one full line of received data. Run an appropriate handler.

=cut

sub processLine {
	my ($self, $line) = @_;

	$self->{handler}->serverRead($line . "\r\n");
}


=back

=cut

1;
