#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30Connection - Maintain a connection to LS30 device

=head1 DESCRIPTION

This class keeps a TCP connection to an LS30 device and performs some of
the protocol decoding.

=head1 METHODS

=over

=cut

package LS30Connection;

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Date::Format qw(time2str);

use AlarmDaemon::SocketFactory qw();
use LS30::Log qw();

# ---------------------------------------------------------------------------

=item new($server_address)

Return a new LS30Connection. At this time, the socket is not connected.

=cut

sub new {
	my ($class, $server_address) = @_;

	if (!defined $server_address) {
		$server_address = $ENV{'LS30_SERVER'};

		if (!$server_address) {
			die "Environment LS30_SERVER must be set to host:port of LS30 server";
		}
	}

	my $self = {
		server_address => $server_address,
		pending        => '',
		handler        => undef,
	};

	bless $self, $class;

	return $self;
}


# ---------------------------------------------------------------------------

=item connect()

Connect to our server. Return 1 if a connection was made, else 0.

=cut

sub connect {
	my ($self) = @_;

	my $server_address = $self->{server_address};

	if (!$server_address) {
		die "No server address";
	}

	my $conn = AlarmDaemon::SocketFactory->new(
		PeerAddr => $self->{server_address},
		Proto    => "tcp",
	);

	if (!$conn) {
		return 0;
	}

	$self->{socket} = $conn;

	return 1;
}


# ---------------------------------------------------------------------------

=item disconnect()

Disconnect from our server and delete the socket.

=cut

sub disconnect {
	my ($self) = @_;

	if ($self->{socket}) {
		$self->{socket}->close();
		delete $self->{socket};
	}
}


# ---------------------------------------------------------------------------

=item socket()

Return our socket reference.

=cut

sub socket {
	my ($self) = @_;

	return $self->{socket};
}


# ---------------------------------------------------------------------------

=item handleRead($selector, $socket)

Attempt to read data from our socket. Call disconnect_event() if there is
an error or EOF. Otherwise, process all data received.

=cut

sub handleRead {
	my ($self, $selector, $socket) = @_;

	my $buffer;
	my $n = $socket->recv($buffer, 256);

	if (!defined $n) {

		# Error
		$self->disconnect_event($selector, $socket);
	} else {
		$n = length($buffer);
		if ($n == 0) {

			# EOF
			$self->disconnect_event($selector, $socket);
		} else {
			$self->addBuffer($buffer);
		}
	}
}


# ---------------------------------------------------------------------------

=item disconnect_event($selector, $socket)

There was an Error or EOF on our socket connection. Remove us from the
specified selector, close our socket (disconnect) and run the Disconnect
event handler.

=cut

sub disconnect_event {
	my ($self, $selector, $socket) = @_;

	$selector->removeSelect($socket);
	$self->disconnect();

	$self->runHandler('Disconnect');
}


# ---------------------------------------------------------------------------

=item sendCommand($string)

Send a command to the connected socket.

=cut

sub sendCommand {
	my ($self, $string) = @_;

	my $socket = $self->{socket};

	if (!$socket) {
		die "Unable to sendCommand(): Not connected";
	}

	$socket->send($string);
	if ($ENV{LS30_DEBUG}) {
		LS30::Log::timePrint("Sent: $string");
	}
}


# ---------------------------------------------------------------------------

=item setHandler($object)

Keep a reference to the object which will process all our emitted events.

=cut

sub setHandler {
	my ($self, $object) = @_;

	$self->{handler} = $object;
}


# ---------------------------------------------------------------------------

=item addBuffer($buffer)

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

Since the LS30 can garble its output, also use some heuristics to
determine if a line which makes no sense in total can be processed
in part.

=cut

sub processLine {
	my ($self, $line) = @_;

	if ($line =~ /^MINPIC=([0-9a-f]+)$/) {
		my $minpic = $1;
		$self->runHandler('MINPIC', $minpic);
		return;
	}

	if ($line =~ /^XINPIC=([0-9a-f]+)$/) {
		my $minpic = $1;
		$self->runHandler('MINPIC', $minpic);
		return;
	}

	if ($line =~ /^\(([0-9a-f]+)\)$/) {
		my $contact_id = $1;
		$self->runHandler('CONTACTID', $contact_id);
		return;
	}

	if ($line eq '!&') {

		# This is only a prompt
		return;
	}

	if ($line =~ /^(!.+&)$/) {
		my $response = $1;
		$self->runHandler('Response', $response);
		return;
	}

	if ($line =~ /^(AT.+)/) {

		# Ignore AT command
		$self->runHandler('AT', $line);
		return;
	}

	if ($line =~ /^(GSM=.+)/) {

		# Ignore GSM command
		$self->runHandler('GSM', $line);
		return;
	}

	LS30::Log::timePrint("Unrecognised: $line");

	# Try munged I/O
	if ($line =~ /^(.+)(MINPIC=.+)/) {
		my ($junk, $minpic) = ($1, $2);
		LS30::Log::timePrint("Skipping junk $junk");
		processLine($minpic);
		return;
	}

	if ($line =~ /^(.+)(XINPIC=.+)/) {
		my ($junk, $minpic) = ($1, $2);
		LS30::Log::timePrint("Skipping junk $junk");
		processLine($minpic);
		return;
	}

	if ($line =~ /^(.+)(\(.+\))/) {
		my ($junk, $contactid) = ($1, $2);
		LS30::Log::timePrint("Skipping junk $junk");
		$self->processLine($contactid);
		return;
	}

	if ($line =~ /^(.+)(!.+&)/) {
		my ($junk, $response) = ($1, $2);
		LS30::Log::timePrint("Skipping junk $junk");
		$self->processLine($response);
		return;
	}

	if ($line =~ /^(.+)(AT.+)/) {
		my ($junk, $at) = ($1, $2);
		LS30::Log::timePrint("Skipping junk $junk");
		$self->processLine($at);
		return;
	}

	if ($line =~ /^(.+)(GSM=.+)/) {
		my ($junk, $gsm) = ($1, $2);
		LS30::Log::timePrint("Skipping junk $junk");
		$self->processLine($gsm);
		return;
	}

	LS30::Log::timePrint("Ignoring: $line");
}


# ---------------------------------------------------------------------------

=item runHandler($type, @args)

Run the handler function appropriate to the specified type $type.
Further arguments depend on the value of $type.

=cut

sub runHandler {
	my $self = shift;
	my $type = shift;

	my $object = $self->{handler};

	if (!defined $object) {
		LS30::Log::timePrint("Cannot run handler for $type");
		return;
	}

	if ($type eq 'MINPIC') {
		$object->handleMINPIC(@_);
	} elsif ($type eq 'CONTACTID') {
		$object->handleCONTACTID(@_);
	} elsif ($type eq 'Response') {
		$object->handleResponse(@_);
	} elsif ($type eq 'AT') {
		$object->handleAT(@_);
	} elsif ($type eq 'GSM') {
		$object->handleGSM(@_);
	} elsif ($type eq 'Disconnect') {
		$object->handleDisconnect(@_);
	} else {
		LS30::Log::timePrint("No handler function defined for $type");
	}
}

1;
