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

use AlarmDaemon::Utils qw(_onfunc _runonfunc _defineonfunc);
use LS30::DeviceMessage qw();
use LS30::Log qw();
use LS30::ResponseMessage qw();
use ContactID::EventMessage qw();

__PACKAGE__->_defineonfunc('DeviceMessage');
__PACKAGE__->_defineonfunc('EventMessage');
__PACKAGE__->_defineonfunc('ResponseMessage');

# ---------------------------------------------------------------------------

=item I<new()>

Instantiate one LS30::Decoder.

=cut

sub new {
	my ($class) = @_;

	my $self = {
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

	$self->_runonfunc('DeviceMessage', $obj);
}


# ---------------------------------------------------------------------------

=item I<handleXINPIC($string)>

Process 'XINPIC' strings. Turn them into an instance of LS30::DeviceMessage.

=cut

sub handleXINPIC {
	my ($self, $string) = @_;

	my $obj = LS30::DeviceMessage->new($string);

	my $err = $obj->getError();
	if ($err) {

		# Invalid string, do not pass to handler
		return;
	}

	$self->_runonfunc('DeviceMessage', $obj);
}


# ---------------------------------------------------------------------------

=item I<handleCONTACTID($string)>

Process strings in the Contact ID format.
Turn them into an instance of ContactID::EventMessage.

=cut

sub handleCONTACTID {
	my ($self, $string) = @_;

	my $obj = ContactID::EventMessage->new($string);

	$self->_runonfunc('EventMessage', $obj);
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
		$self->_runonfunc('ResponseMessage', $obj);
	}
}

=back

=cut

1;
