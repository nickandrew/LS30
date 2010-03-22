#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#  Act as a proxy, logging all comms to and from a remote host/port
#
#  Usage: alarm-daemon.pl [-l port] [-h host:port]
#
#  -l port       Listen on specified port
#  -h host:port  Connect to specified port
#
#  All I/O to/from the remote host is logged.

use strict;

use Getopt::Std qw(getopts);
use IO::Select qw();
use IO::Socket::INET qw();
use Socket qw();

use AlarmDaemon::ClientSocket qw();
use AlarmDaemon::ServerSocket qw();
use LS30::Log qw();

use vars qw($opt_h $opt_l);

$| = 1;
getopts('h:l:');

$opt_h || die "Need option -h host:port";
$opt_l || die "Need option -l local_port";

$SIG{'INT'} = sub {
	LS30::Log::timePrint("SIGINT received, exiting");
	exit(4);
};

$SIG{'PIPE'} = sub {
	LS30::Log::timePrint("SIGPIPE received, exiting");
	exit(4);
};

my $listener = IO::Socket::INET->new(
	LocalPort => $opt_l,
	Proto => "tcp",
	Type => Socket::SOCK_STREAM(),
	ReuseAddr => 1,
	Listen => 5,
);

my $select = IO::Select->new();
$select->add($listener);

my $conn = AlarmDaemon::ServerSocket->new($opt_h);

if (! $conn) {
	die "Unable to connect to server";
}

$select->add( [$conn->socket(), \&serverRead, $conn] );

LS30::Log::timePrint("Listening");

my $pending_data = '';
my $client_sockets = { };
my $count_clients = 0;

eventLoop();

LS30::Log::timePrint("While loop exited");

exit(0);

# ---------------------------------------------------------------------------
# Send a buffer to the server
# ---------------------------------------------------------------------------

sub sendData {
	my $buffer = shift;

	if ($conn) {
		$conn->send($buffer);
		LS30::Log::timePrint("Sent: $buffer");
	} else {
		LS30::Log::timePrint("Not sent: $buffer");
	}
}

# ---------------------------------------------------------------------------
# Send a buffer to all clients.
# If no clients connected, store it in $pending_data until somebody connects.
# ---------------------------------------------------------------------------

sub emitBuffer {
	my ($obj, $buffer) = @_;

	if ($count_clients == 0) {
		LS30::Log::timePrint("Pending: $buffer");
		$pending_data .= $buffer;
		return;
	}

	my $rest = '';
	if ($count_clients > 1) {
		$rest = " to $count_clients clients";
	}

	LS30::Log::timePrint("Emitting: $buffer$rest");

	foreach my $socket (values %$client_sockets) {
		send($socket, $buffer, 0);
	}
}

# ------------------------------------------------------------------------
# Main event processing loop
# ------------------------------------------------------------------------

sub eventLoop {

	while (1) {

		# How long to wait in select() ?
		my $now = time();
		my $wait_til = $now;
		my $wait_ref;
		my $t;

		$t = $conn->watchdogTime();
		if (defined $t && $t > $wait_til) {
			$wait_til = $t;
			$wait_ref = $conn;
		}

		my $howlong = $wait_til - $now;
		if ($howlong <= 0) {
			if ($wait_ref) {
				$wait_ref->watchdogEvent();
				next;
			}
			$howlong = 60;
		}

		my @read = $select->can_read($howlong);

		if (@read) {

			foreach my $handle (@read) {
				if (ref($handle) eq 'ARRAY') {
					# Function is 2nd item, Object is 3rd item
					my $func = $handle->[1];
					my $obj = $handle->[2];

					&$func($obj);

					next;
				}

				if ($handle == $listener) {
					# Accept the connection
					acceptConnection($listener);
					next;
				}
				else {
					LS30::Log::timePrint("can_read on unknown handle $handle");
				}

			}

		}
	}

}

# ---------------------------------------------------------------------------
# Accept a new client connection.
# ---------------------------------------------------------------------------

sub acceptConnection {
	my ($listener) = @_;

	my ($socket, $address) = $listener->accept();
	if (! $address) {
		LS30::Log::timePrint("Accept failed");
		return;
	}

	LS30::Log::timePrint("New client");
	$client_sockets->{$socket} = $socket;
	my $client = AlarmDaemon::ClientSocket->new($socket);
	$select->add( [$socket, \&clientRead, $client] );
	$count_clients ++;

	if ($pending_data) {
		LS30::Log::timePrint("Sent pending: $pending_data");
		send($socket, $pending_data, 0);
		$pending_data = '';
	}
}

# ---------------------------------------------------------------------------
# Read data from the server connection.
# ---------------------------------------------------------------------------

sub serverRead {
	my ($conn) = @_;

	my ($rc, $buffer) = $conn->doRead();

	if (!defined $rc) {
		# Error
		$select->remove($conn->socket());
		$conn->disconnect();
		$conn->connect();
		$select->add( [$conn->socket(), \&serverRead, $conn] );
	}
	elsif ($rc == -1) {
		$select->remove($conn->socket());
		$conn->disconnect();
		$conn->connect();
		$select->add( [$conn->socket(), \&serverRead, $conn] );
		# EOF
	}
	else {
		# Process input data
		if (defined $buffer) {
			emitBuffer(undef, $buffer);
		}
	}
}

# ---------------------------------------------------------------------------
# Close a client socket
# ---------------------------------------------------------------------------

sub closeClient {
	my ($client) = @_;

	LS30::Log::timePrint("Removing client");

	my $socket = $client->socket();
	$select->remove($socket);
	delete $client_sockets->{$socket};
	$client->disconnect();
	$count_clients --;
}

# ---------------------------------------------------------------------------
# Read data from a client socket.
# ---------------------------------------------------------------------------

sub clientRead {
	my ($client) = @_;

	my ($rc, $buffer) = $client->doRead();

	if (!defined $rc) {
		# Error
		closeClient($client);
	}
	elsif ($rc == -1) {
		# EOF
		closeClient($client);
	}
	else {
		# Process input data
		if (defined $buffer) {
			sendData($buffer);
		}
	}
}
