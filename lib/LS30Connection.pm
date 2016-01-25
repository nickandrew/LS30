#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30Connection - Maintain a connection to LS30 device

=head1 DESCRIPTION

This class keeps a TCP connection to an LS30 device and performs some of
the protocol decoding.

It is a subclass of AlarmDaemon::ServerSocket.

=head1 METHODS

=over

=cut

package LS30Connection;

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Date::Format qw(time2str);
use AnyEvent qw();

use base qw(AlarmDaemon::ServerSocket);

__PACKAGE__->_defineonfunc('AddedDevice');
__PACKAGE__->_defineonfunc('AT');
__PACKAGE__->_defineonfunc('CONTACTID');
__PACKAGE__->_defineonfunc('GSM');
__PACKAGE__->_defineonfunc('MINPIC');
__PACKAGE__->_defineonfunc('Response');
__PACKAGE__->_defineonfunc('XINPIC');

# ---------------------------------------------------------------------------

=item I<new($server_address, %args)>

Return a new LS30Connection. The server address defaults to env LS30_SERVER.

Optional args hashref:  See perldoc for AlarmDaemon::ServerSocket

  reconnect                  Set default reconnection functions (boolean)

=cut

sub new {
	my ($class, $server_address, %args) = @_;

	if (!defined $server_address) {
		$server_address = $ENV{'LS30_SERVER'};

		if (!$server_address) {
			die "Environment LS30_SERVER must be set to host:port of LS30 server";
		}
	}

	my $self = $class->SUPER::new($server_address, %args);
	bless $self, $class;

	if ($args{reconnect}) {

		$self->onConnectFail(sub {
			LS30::Log::error("LS30Connection: Connection to $server_address failed, retrying");
			$self->retryConnect();
		});

		$self->onDisconnect(sub {
			LS30::Log::error("LS30Connection: Disconnected from $server_address, retrying");
			$self->retryConnect();
		});
	}

	$self->onRead(sub { $self->_addBuffer(shift); });

	return $self;
}


# ---------------------------------------------------------------------------

=item I<sendCommand($string)>

Send a command to the connected socket.

Dies if not presently connected.

=cut

sub sendCommand {
	my ($self, $string) = @_;

	$self->send($string);
	LS30::Log::debug("Sent: $string");
}


# ---------------------------------------------------------------------------

=item I<_addBuffer($buffer)>

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

sub _addBuffer {
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

Process one full line of received data. Call an on* function.

Since the LS30 can garble its output, also use some heuristics to
determine if a line which makes no sense in total can be processed
in part.

=cut

sub processLine {
	my ($self, $line) = @_;

	if ($line =~ /^MINPIC=([0-9a-f]+)$/) {
		my $minpic = $1;
		$self->_runonfunc('MINPIC', $minpic);
		return;
	}

	if ($line =~ /^XINPIC=([0-9a-f]+)$/) {
		my $minpic = $1;
		$self->_runonfunc('XINPIC', $minpic);
		return;
	}

	if ($line =~ /^\(([0-9a-f]+)\)$/) {
		my $contact_id = $1;
		$self->_runonfunc('CONTACTID', $contact_id);
		return;
	}

	if ($line eq '!&') {

		# This is only a prompt
		return;
	}

	if ($line =~ /^(!.+&)$/) {
		my $response = $1;

		# Special handling for 'new device enrolled' messages which are not
		# a response to a command, but are sent at the time the device is
		# enrolled.
		if ($response =~ /^!i[bcefm]l[0-9a-f]{14}&$/) {
			$self->_runonfunc('AddedDevice', $response);
			return;
		}

		if ($response =~ /^!i[bcefm]lno&$/) {
			# Time limit expired; no device added
			# The time delay is a *maximum* of 60 seconds; may be less.
			$self->_runonfunc('AddedDevice', $response);
			return;
		}

		$self->_runonfunc('Response', $response);
		return;
	}

	if ($line =~ /^(AT.+)/) {

		# Ignore AT command
		$self->_runonfunc('AT', $line);
		return;
	}

	if ($line =~ /^(GSM=.+)/) {

		# Ignore GSM command
		$self->_runonfunc('GSM', $line);
		return;
	}

	LS30::Log::timePrint("Unrecognised: $line");

	# Try munged I/O
	if ($line =~ /^(.+)(MINPIC=.+)/) {
		my ($junk, $minpic) = ($1, $2);
		LS30::Log::timePrint("Skipping junk $junk");
		$self->processLine($minpic);
		return;
	}

	if ($line =~ /^(.+)(XINPIC=.+)/) {
		my ($junk, $xinpic) = ($1, $2);
		LS30::Log::timePrint("Skipping junk $junk");
		$self->processLine($xinpic);
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
# Set/Get and/or run a function
# ---------------------------------------------------------------------------

sub _onfunc {
	my $self = shift;
	my $name = shift;

	if (scalar @_) {
		$self->{on_func}->{$name} = shift;
		return $self;
	}

	return $self->{on_func}->{$name};
}

sub _runonfunc {
	my $self = shift;
	my $name = shift;

	my $sub = $self->{on_func}->{$name};
	if (defined $sub) {
		$sub->(@_);
	}
}

# _defineonfunc('Fred') creates a method $self->onFred(...)

sub _defineonfunc {
	my ($self, $name) = @_;

	no strict 'refs';
	my $package = ref($self) || $self;
	*{"${package}::on${name}"} = sub { return shift->_onfunc($name, @_); };
}

=back

=cut

1;
