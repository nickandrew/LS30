#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
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
use warnings;

use LS30::DeviceMessage qw();
use LS30::Log qw();
use LS30::ResponseMessage qw();
use ContactID::EventMessage qw();


# ---------------------------------------------------------------------------

=item I<new($handler_obj)>

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

=item I<handleMINPIC($string)>

Process 'MINPIC' strings. Turn them into an instance of LS30::DeviceMessage.

=cut

sub handleMINPIC {
	my ($self, $string) = @_;

	my $obj = LS30::DeviceMessage->new($string);

	my $err = $obj->getError();
	if ($err) {

		# Invalid string, do not pass to handler
		return;
	}

	$self->{handler}->handleDeviceMessage($obj);
}


# ---------------------------------------------------------------------------

=item I<handleCONTACTID($string)>

Process strings in the Contact ID format.
Turn them into an instance of ContactID::EventMessage.

=cut

sub handleCONTACTID {
	my ($self, $string) = @_;

	my $obj = ContactID::EventMessage->new($string);

	$self->{handler}->handleEventMessage($obj);
}


# ---------------------------------------------------------------------------

=item I<handleResponse($string)>

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

=item I<handleAT($string)>

Process the 'AT' message. Print it and ignore.

=cut

sub handleAT {
	my ($self, $string) = @_;

	if ($self->{handler} && $self->{handler}->can('handleAT')) {
		$self->{handler}->handleAT($string);
	}
}


# ---------------------------------------------------------------------------

=item I<handleGSM($string)>

Process the 'GSM' message. Print it and ignore.

=cut

sub handleGSM {
	my ($self, $string) = @_;

	if ($self->{handler} && $self->{handler}->can('handleGSM')) {
		$self->{handler}->handleGSM($string);
	}
}

=back

=cut

1;
