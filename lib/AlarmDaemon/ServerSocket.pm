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

__PACKAGE__->_defineonfunc('Connect');
__PACKAGE__->_defineonfunc('ConnectFail');
__PACKAGE__->_defineonfunc('Disconnect');
__PACKAGE__->_defineonfunc('Read');


# ---------------------------------------------------------------------------

=item I<new($peer_addr, %args)>

Connect to the server (identified as host:port) and return the newly
instantiated AlarmDaemon::ServerSocket object. If unable to connect,
return undef.

Optional args hashref:

  no_connect                 Do not try to connect automatically

  on_connect_fail            Sub to be called when a connect fails

  on_disconnect              Sub to be called after a disconnection

=cut

sub new {
	my ($class, $peer_addr, %args) = @_;

	my $self = {
		current_state     => 'disconnected',
		peer_addr         => $peer_addr,
		watchdog_interval => 320,
		pending           => '',
		retry_default     => 5,
	};

	bless $self, $class;

	# Set function to be called on connect failure
	if ($args{on_connect_fail}) {
		$self->onConnectFail($args{on_connect_fail});
	}

	# Set function to be called after a disconnection
	if ($args{on_disconnect}) {
		$self->onDisconnect($args{on_disconnect});
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

=item I<onConnectFail(sub)>

Get/set a subroutine to be called on any connect failure.
The subroutine is called with $self as its argument.

=cut

sub xxonConnectFailxx {
	my $self = shift;

	if (scalar @_) {
		$self->_onfunc('ConnectFail', shift);

		# Try to bootstrap connection here; call it now
		if (!$self->isConnected()) {
			$self->_runonfunc('ConnectFail');
		}

		return $self;
	}
	return $self->_onfunc('ConnectFail');
}


# ---------------------------------------------------------------------------
# Process the disconnection action.
# ---------------------------------------------------------------------------

sub _disconnected {
	my $self = shift;

	$self->_runonfunc('Disconnect');
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
		LS30::Log::error("Cannot create a new socket to $self->{peer_addr}");
		$self->_runonfunc('ConnectFail');
		return 0;
	}

	$self->{socket}         = $socket;
	$self->{last_rcvd_time} = time();
	$self->{current_state}  = 'connected';
	$self->{retry_interval} = $self->{retry_default};

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

	$self->_runonfunc('Connect');

	return 1;
}


# ---------------------------------------------------------------------------

=item I<disconnect()>

If the socket is currently open, then close it and forget it.

=cut

sub disconnect {
	my ($self) = @_;

	if ($self->{socket}) {
		delete $self->{poller};
		close($self->{socket});
		undef $self->{socket};
		$self->{current_state} = 'disconnected';
	}
}


# ---------------------------------------------------------------------------

=item I<retryConnect()>

Wait, then try to connect asynchronously.
Use exponential backoff.
Recursion may be enabled by calling this function in onConnectFail and
onDisconnect subs.

=cut

sub retryConnect {
	my ($self) = @_;

	my $cv = AnyEvent->condvar;

	# Try again after an exponential backoff delay
	my $retry_interval = $self->_retryInterval();
	LS30::Log::timePrint("Attempt connect after $retry_interval");

	my $timer;
	$timer = AnyEvent->timer(
		after => $retry_interval,
		cb    => sub {
			undef $timer;

			if ($self->connect()) {
				LS30::Log::timePrint("(Re)connected");
				$cv->send(1);
			}
			else {
				$cv->send(0);
			}
		},
	);

	return $cv;
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
# Return retry interval with exponential backoff (up to 64 seconds)
# Initial value returned is whatever is set elsewhere in this class.
# ---------------------------------------------------------------------------

sub _retryInterval {
	my ($self) = @_;

	my $retry_interval = $self->{retry_interval} || $self->{retry_default};

	if ($retry_interval >= 32) {
		$self->{retry_interval} = 64;
	} else {
		$self->{retry_interval} = $retry_interval * 2;
	}

	return $retry_interval;
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
		LS30::Log::timePrint("Timeout: disconnecting from " . $self->peerhost());
		$self->disconnect();
		return;
	}

	my $retry_interval = $self->_retryInterval();
	$self->{retry_when} += $retry_interval;

	$self->tryConnect();
}


# ------------------------------------------------------------------------

=item I<handleRead()>

Read data from the socket and postprocess it.

The call chain is: handleRead -> addBuffer -> processLine

=cut

sub handleRead {
	my ($self) = @_;

	my $buffer;
	$self->{last_rcvd_time} = time();

	my $n = $self->{socket}->recv($buffer, 128);

	if (!defined $n) {

		# Error on the socket
		LS30::Log::timePrint("Socket error from " . $self->peerhost());
		$self->disconnect();
		$self->_disconnected();
		return;
	}

	if (length($buffer) == 0) {

		# EOF: Other end closed the connection
		LS30::Log::timePrint("Disconnect from " . $self->peerhost());
		$self->disconnect();
		$self->_disconnected();
		return;
	}

	$self->_runonfunc('Read', $buffer);
}


# ---------------------------------------------------------------------------

=item I<send($buffer)>

If not connected, die. Then send data to our socket.

=cut

sub send {
	my ($self, $buffer) = @_;

	if (!$self->isConnected()) {
		die "Cannot send() to a non-connected AlarmDaemon::ServerSocket";
	}

	$self->SUPER::send($buffer);
	return;
}


=back

=cut

1;
