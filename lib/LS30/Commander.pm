#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30::Commander - Send commands to LS30

=head1 DESCRIPTION

This class implements a simple command/response engine for the LS30.
It can send a command and then wait several seconds for a response.

=head1 METHODS

=over

=cut

package LS30::Commander;

use strict;

use LS30::Log qw();

# ---------------------------------------------------------------------------

=item new($ls30c, $timeout)

Return a new LS30::Commander using the specified connection, which
is of class LS30Connection.

Timeout is optional, if >0 then it specifies how many seconds at most
to wait for a response. The default timeout is 5 seconds.

=cut

sub new {
	my ($class, $ls30c, $timeout) = @_;

	my $self = {
		ls30c => $ls30c,
	};

	if (defined $timeout && $timeout > 0) {
		$self->{timeout} = $timeout;
	} else {
		$self->{timeout} = 5;
	}

	bless $self, $class;

	$ls30c->setHandler($self);

	return $self;
}


# ---------------------------------------------------------------------------

=item sendCommand($string)

Send a command to the LS30 and wait up to $self->{timeout} seconds for a
response.  Return the first response received within this time.

Return undef if no response was received after a timeout.

=cut

sub sendCommand {
	my ($self, $string) = @_;

	my $ls30c = $self->{ls30c};
	my $socket = $ls30c->socket();

	if (! $socket) {
		die "Unable to sendCommand(): Not connected";
	}

	$socket->send($string);
	LS30::Log::timePrint("Sent: $string");

	# pollServer will return on the first event of any kind received.
	# We may have to retry, if a non-response is received before a
	# response. Implement retry logic to a maximum time interval of
	# $self->{timeout} seconds.

	my $how_long = $self->{timeout};
	my $end_time = time() + $how_long;

	while ($how_long > 0) {
		$ls30c->pollServer($how_long);

		my $response = $self->getResponse();

		if (defined $response) {
			return $response;
		}

		$how_long = $end_time - time();
	}

	return undef;
}


# ---------------------------------------------------------------------------

=item handleMINPIC($string)

Store any MINPIC string received by the poll.

=cut

sub handleMINPIC {
	my ($self, $string) = @_;

	$self->{last_minpic} = $string;
}


# ---------------------------------------------------------------------------

=item handleCONTACTID($string)

Store any CONTACTID string received by the poll.

=cut

sub handleCONTACTID {
	my ($self, $string) = @_;

	$self->{last_contactid} = $string;
}


# ---------------------------------------------------------------------------

=item handleResponse($string)

Store any Response string received by the poll.

=cut

sub handleResponse {
	my ($self, $string) = @_;

	$self->{last_response} = $string;
}


# ---------------------------------------------------------------------------

=item handleAT($string)

Store any AT string received by the poll.

=cut

sub handleAT {
	my ($self, $string) = @_;

	$self->{last_at} = $string;
}


# ---------------------------------------------------------------------------

=item handleGSM($string)

Store any GSM string received by the poll.

=cut

sub handleGSM {
	my ($self, $string) = @_;

	$self->{last_gsm} = $string;
}


# ---------------------------------------------------------------------------

=item handleDisconnect($string)

This function is called if our client socket is disconnected.

=cut

sub handleDisconnect {
	my ($self) = @_;

	# Nothing to do?
}


# ---------------------------------------------------------------------------

=item getMINPIC()

Return any saved MINPIC string.

=cut

sub getMINPIC {
	my ($self) = @_;

	return $self->{last_minpic};
}


# ---------------------------------------------------------------------------

=item getCONTACTID()

Return any saved CONTACTID string.

=cut

sub getCONTACTID {
	my ($self) = @_;

	return $self->{last_contactid};
}


# ---------------------------------------------------------------------------

=item getResponse()

Return any saved Response string.

=cut

sub getResponse {
	my ($self) = @_;

	return $self->{last_response};
}

1;
