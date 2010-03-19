#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
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

use Data::Dumper qw(Dumper);
use Date::Format qw(time2str);
use IO::Select;
use IO::Socket::INET;

use LS30::Log qw();

# ---------------------------------------------------------------------------

=item new($server_address)

Return a new LS30Connection. At this time, the socket is not connected.

=cut

sub new {
	my ($class, $server_address) = @_;

	if (!defined $server_address) {
		$server_address = $ENV{'LS30_SERVER'};

		if (! $server_address) {
			die "Environment LS30_SERVER must be set to host:port of LS30 server";
		}
	}

	my $self = {
		server_address => $server_address,
		last_response => undef,
		pending => '',
		handler => { },
	};

	bless $self, $class;

	return $self;
}


# ---------------------------------------------------------------------------

=item Connect()

Connect to our server. Return 1 if a connection was made, else 0.

=cut

sub Connect {
	my ($self) = @_;

	my $server_address = $self->{server_address};

	if (! $server_address) {
		die "No server address";
	}

	my $conn = IO::Socket::INET->new(
		PeerAddr => $self->{server_address},
		Proto => "tcp",
		Type => SOCK_STREAM,
	);

	if (! $conn) {
		return 0;
	}

	$self->{socket} = $conn;

	return 1;
}


# ---------------------------------------------------------------------------

=item Disconnect()

Disconnect from our server and delete the socket.

=cut

sub Disconnect {
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

=item sendCommand($string)

Send a command and return the response to the command.

Return undef on timeout or other error.

=cut

sub sendCommand {
	my ($self, $string) = @_;

	my $socket = $self->{socket};

	if (! $socket) {
		die "Unable to sendCommand(): Not connected";
	}

	$socket->send($string);
	LS30::Log::timePrint("Sent: $string");

	my $response = $self->getResponse(60);

	return $response;
}


# ---------------------------------------------------------------------------

=item setHandler($object)

Keep a reference to the object which will process all our emitted events.

=cut

sub setHandler {
	my ($self, $handler, $arg, $func) = @_;

	$self->{handler}->{$handler} = [ $arg, $func ];
}


# ---------------------------------------------------------------------------

=item eventLoop()

Loop forever reading and processing data from our socket. Only return on
Error or EOF on the server socket.

=cut

sub eventLoop {
	my ($self) = @_;

	while (1) {
		my $rc = $self->pollServer(8);

		if ($rc == -2) {
			LS30::Log::timePrint("Error on server socket");
			return undef;
		}

		if ($rc == -1) {
			LS30::Log::timePrint("EOF on server socket");
			return undef;
		}
	}
}


# ---------------------------------------------------------------------------

=item getResponse($timeout)

Wait up to $timeout seconds to receive a response to a command which has
already been issued. Return the response if possible, otherwise undef.

=cut

sub getResponse {
	my ($self, $timeout) = @_;

	$timeout ||= 60;
	my $now = time();
	my $time_limit = $now + $timeout;
	my $poll_time = ($timeout < 2) ? $timeout : 2;

	do {
		my $rc = $self->pollServer(2);
		if ($rc < 0) {
			# TODO process error conditions
			return undef;
		}

		my $response = $self->lastResponse();
		if ($response) {
			$self->clearResponse();
			return $response;
		}
	} while (time() < $time_limit);

	LS30::Log::timePrint("No response received within $timeout seconds");
	return undef;
}


# ------------------------------------------------------------------------

=item pollServer($timeout)

Receive at most one buffer of data from the server. This may consist of
multiple lines, or partial lines. All completed lines are processed
through emit functions. A trailing partial line is left in our 'pending'
string for later processing.

Return values:

  -2   Error on server socket
  -1   EOF on server socket
   0   Timeout - no data received
   1   Data received and processed.

=cut

sub pollServer {
	my ($self, $timeout) = @_;

	my $socket = $self->{socket};

	if (! $socket) {
		die "Unable to getResponse(): Not connected";
	}

	my $select = IO::Select->new();
	$select->add($socket);

	my @read = $select->can_read($timeout || 2);

	if (@read) {
		foreach my $handle (@read) {
			if ($handle == $socket) {
				my $buffer;
				my $n = $socket->recv($buffer, 256);

				if (!defined $n) {
					LS30::Log::timePrint("Error on server socket");
					return -2;
				}

				if (length($buffer) == 0) {
					LS30::Log::timePrint("EOF on server socket");
					return -1;
				}

				$self->addBuffer($buffer);
				return 1;
			}
		}
	}

	return 0;
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
			LS30::Log::timePrint("Incomplete line: ($pending)");
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
		$self->emitMINPIC($minpic);
		return;
	}

	if ($line =~ /^XINPIC=([0-9a-f]+)$/) {
		my $minpic = $1;
		$self->emitMINPIC($minpic);
		return;
	}

	if ($line =~ /^\(([0-9a-f]+)\)$/) {
		my $contact_id = $1;
		$self->emitCONTACTID($contact_id);
		return;
	}

	if ($line eq '!&') {
		# This is only a prompt
		return;
	}

	if ($line =~ /^(!.+&)$/) {
		my $response = $1;
		$self->emitResponse($response);
		return;
	}

	if ($line =~ /^(AT.+)/) {
		# Ignore AT command
		$self->emitAny($line, 'AT', "Ignoring AT");
		return;
	}

	if ($line =~ /^(GSM=.+)/) {
		# Ignore GSM command
		$self->emitAny($line, 'GSM', "Ignoring GSM");
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

=item emitMINPIC($string)

Run specified handler function for MINPIC or print it.

=cut

sub emitMINPIC {
	my ($self, $string) = @_;

	my $func_lr = $self->{handler}->{'MINPIC'};
	if ($func_lr) {
		my ($arg, $func) = @$func_lr;
		&$func($arg, $string);
	} else {
		LS30::Log::timePrint("MINPIC: $string");
	}
}


# ---------------------------------------------------------------------------

=item emitCONTACTID($string)

Run specified handler function for a Contact ID line or print it.

=cut

sub emitCONTACTID {
	my ($self, $string) = @_;

	my $func_lr = $self->{handler}->{'CONTACTID'};
	if ($func_lr) {
		my ($arg, $func) = @$func_lr;
		&$func($arg, $string);
	} else {
		LS30::Log::timePrint("Contact ID: $string");
	}
}


# ---------------------------------------------------------------------------

=item emitResponse($string)

Remember this response string.
Run specified handler function for a response or print it.

=cut

sub emitResponse {
	my ($self, $string) = @_;

	$self->{last_response} = $string;

	my $func_lr = $self->{handler}->{'Response'};
	if ($func_lr) {
		my ($arg, $func) = @$func_lr;
		&$func($arg, $string);
	} else {
		LS30::Log::timePrint("Response: $string");
	}
}


# ---------------------------------------------------------------------------

=item emitAny($string, $type, $message)

Remember this string, keyed by 'type'.

Run a handler specified by $type. If no handler is defined then print
a log message, prefixed by $message.

=cut

sub emitAny {
	my ($self, $string, $type, $message) = @_;

	$self->{'last'}->{$type} = $string;

	my $func_lr = $self->{handler}->{$type};
	if ($func_lr) {
		my ($arg, $func) = @$func_lr;
		&$func($arg, $string);
	} else {
		LS30::Log::timePrint("${message}: $string");
	}
}


# ---------------------------------------------------------------------------

=item lastResponse()

Return the last response line we received from our server.

=cut

sub lastResponse {
	my ($self) = @_;

	return $self->{last_response};
}


# ---------------------------------------------------------------------------

=item clearResponse()

Clear our record of last response. Used when returning it, to avoid
returning the same response twice.

=cut

sub clearResponse {
	my ($self) = @_;

	$self->{last_response} = undef;
}

1;
