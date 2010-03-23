#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30::Decoder - Protocol decoding filter

=head1 DESCRIPTION

The LS30Connection class only decodes the LS30 protocol to the extent
necessary to distinguish between message types and ignore incomplete
or garbled messages. Its output is a series of calls to handler functions,
the argument to each is a string with no meaning.

This class adds meaning to those strings by instantiating appropriate
Message classes which parse the raw string.

=head1 METHODS

=over

=cut

package LS30::Decoder;

use strict;

use LS30::DeviceMessage qw();
use LS30::Log qw();
use LS30::ResponseMessage qw();
use ContactID::EventMessage qw();


# ---------------------------------------------------------------------------

=item new($handler_obj)

Instantiate one LS30::Decoder.

$handler_obj is the object which will receive all messages from the connection
class.

=cut

sub new {
	my ($class, $handler_obj) = @_;

	my $self = {
		handler => $handler_obj,
	};

	bless $self, $class;

	return $self;
}


# ---------------------------------------------------------------------------

=item handleMINPIC($string)

Process 'MINPIC' strings. Turn them into an instance of LS30::DeviceMessage.

=cut

sub handleMINPIC {
	my ($self, $string) = @_;

	my $obj = LS30::DeviceMessage->new($string);

	$self->{handler}->handleDeviceMessage($obj);
}


# ---------------------------------------------------------------------------

=item handleCONTACTID($string)

Process strings in the Contact ID format.
Turn them into an instance of ContactID::EventMessage.

=cut

sub handleCONTACTID {
	my ($self, $string) = @_;

	my $obj = ContactID::EventMessage->new($string);

	$self->{handler}->handleEventMessage($obj);
}


# ---------------------------------------------------------------------------

=item handleResponse($string)

Process strings which are responses to commands sent by a client to the LS30.
Turn them into an instance of LS30::ResponseMessage.

=cut

sub handleResponse {
	my ($self, $string) = @_;

	my $obj = LS30::ResponseMessage->new($string);

	if ($obj) {
		$self->{handler}->handleResponseMessage($obj);
	}
}


# ---------------------------------------------------------------------------

=item handleAT($string)

Process the 'AT' message. Print it and ignore.

=cut

sub handleAT {
	my ($self, $string) = @_;

	LS30::Log::timePrint("Ignoring AT: $string");
}


# ---------------------------------------------------------------------------

=item handleGSM($string)

Process the 'GSM' message. Print it and ignore.

=cut

sub handleGSM {
	my ($self, $string) = @_;

	LS30::Log::timePrint("Ignoring GSM: $string");
}


# ---------------------------------------------------------------------------

=item handleDisconnect()

Handle a disconnection. Pass to above.

=cut

sub handleDisconnect {
	my ($self) = @_;

	LS30::Log::timePrint("Disconnected");
	$self->{handler}->handleDisconnect();
}

1;
