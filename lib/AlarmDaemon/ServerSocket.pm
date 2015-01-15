#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
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
use warnings;

use AlarmDaemon::CommonSocket qw();
use AlarmDaemon::SocketFactory qw();
use LS30::Log qw();
use Timer qw();

use base qw(AlarmDaemon::CommonSocket Timer);


# ---------------------------------------------------------------------------

=item I<new($peer_addr)>

Connect to the server (identified as host:port) and return the newly
instantiated AlarmDaemon::ServerSocket object. If unable to connect,
return undef.

=cut

sub new {
	my ($class, $peer_addr) = @_;

	my $self = {
		current_state     => 'disconnected',
		peer_addr         => $peer_addr,
		handler           => undef,
		watchdog_interval => 320,
		pending           => '',
	};

	bless $self, $class;

	if (!$self->connect()) {
		return undef;
	}

	return $self;
}


# ---------------------------------------------------------------------------

=item I<isConnected()>

Return 1 if this socket is presently connected to a server, else 0.

=cut

sub isConnected {
	my ($self) = @_;

	return 1 if ($self->{current_state} eq 'connected');
	return 0;
}

# ---------------------------------------------------------------------------

=item I<connect()>

Connect to our server. Set SO_KEEPALIVE so we detect a broken connection
eventually (many minutes). Also set our last_rcvd_time to the current
time to detect quicker if the server has gone away.

=cut

sub connect {
	my ($self) = @_;

	if ($self->isConnected()) {
		# Nothing to do
		return 1;
	}

	my $socket = AlarmDaemon::SocketFactory->new(
		PeerAddr => $self->{peer_addr},
		Proto    => 'tcp',
	);

	if (!$socket) {
		warn "Unable to create a new socket to $self->{peer_addr}";
		return 0;
	}

	$self->{socket}         = $socket;
	$self->{last_rcvd_time} = time();
	$self->{current_state}  = 'connected';

	# Setting SO_KEEPALIVE will eventually cause a client socket error if
	# connection is broken
	if (!setsockopt($socket, Socket::SOL_SOCKET(), Socket::SO_KEEPALIVE(), 1)) {
		warn "Unable to set keepalive\n";
	}

	my $w;
	$w = AnyEvent->io(
		fh   => $socket,
		poll => 'r',
		cb   => sub {
			$self->handleRead();
		}
	);

	$self->{poller} = $w;

	return 1;
}


# ---------------------------------------------------------------------------

=item I<disconnect()>

If the socket is currently open, then close it and forget it.

=cut

sub disconnect {
	my ($self) = @_;

	if ($self->{socket}) {
		LS30::Log::timePrint("Disconnecting");
		delete $self->{poller};
		close($self->{socket});
		undef $self->{socket};
		$self->{current_state} = 'disconnected';
		my $now = time();
		$self->{retry_base}     = $now;
		$self->{retry_when}     = $now + 2;
		$self->{retry_interval} = 4;
	}
}


# ---------------------------------------------------------------------------

=item I<tryConnect()>

Try to connect again.
Log success or failure.

=cut

sub tryConnect {
	my ($self) = @_;

	if ($self->connect()) {
		LS30::Log::timePrint("Reconnected");
	} else {
		LS30::Log::timePrint("Reconnect failed");
	}
}


# ---------------------------------------------------------------------------

=item I<setHandler($object)>

Keep a reference to the object which will process all our emitted events.

=cut

sub setHandler {
	my ($self, $object) = @_;

	$self->{handler} = $object;
}


# ---------------------------------------------------------------------------

=item I<watchdogTime()>

Returns a time_t value representing at what time this object will detect
a timeout, if no recent data has been received from the server.

=cut

sub watchdogTime {
	my ($self) = @_;

	my $current_state = $self->{current_state};

	if ($current_state eq 'disconnected') {
		my $when = $self->{retry_when};
		return $when;
	}

	if ($self->{last_rcvd_time}) {
		return $self->{last_rcvd_time} + $self->{watchdog_interval};
	}

	return undef;
}


# ---------------------------------------------------------------------------

=item I<watchdogEvent()>

Called when the watchdog timer expires.

If we're not connected, try to reconnect.

=cut

sub watchdogEvent {
	my ($self) = @_;

	my $current_state = $self->{current_state};

	if ($current_state eq 'connected') {

		# Disconnect and wait before reconnecting.
		LS30::Log::timePrint("Timeout: disconnecting from server");
		$self->disconnect();
		return;
	}

	my $retry_interval = $self->{retry_interval};
	if ($retry_interval < 64) {
		$retry_interval *= 2;
		$self->{retry_interval} = $retry_interval;
	}
	$self->{retry_when} += $retry_interval;

	$self->tryConnect();
}


# ------------------------------------------------------------------------

=item I<handleRead()>

Read data from the socket and postprocess it.

The call chain is: handleRead -> addBuffer -> processLine -> serverRead

=cut

sub handleRead {
	my ($self) = @_;

	my $buffer;
	$self->{last_rcvd_time} = time();

	my $n = $self->{socket}->recv($buffer, 128);
	if (!defined $n) {

		# Error on the socket
		$self->disconnect();
		return;
	}

	if (length($buffer) == 0) {

		# EOF: Other end closed the connection
		$self->disconnect();
		return;
	}

	$self->addBuffer($buffer);
}


# ---------------------------------------------------------------------------

=item I<addBuffer($buffer)>

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
			$self->processLine($line);
		} else {
			last;
		}
	}

	$self->{pending} = $pending;
}


# ---------------------------------------------------------------------------

=item I<processLine($line)>

Process one full line of received data. Run an appropriate handler.

=cut

sub processLine {
	my ($self, $line) = @_;

	$self->{handler}->serverRead($line . "\r\n");
}


=back

=cut

1;
