#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30::Message - A response message from the LS30

=head1 DESCRIPTION

This class parses response messages from the LS30 (e.g. "!a0&").

=head1 METHODS

=over

=cut

package LS30::Message;

use strict;
use warnings;

use Carp qw(confess);

use LS30Command qw();

# ---------------------------------------------------------------------------

=item I<parse($string)>

Parse $string and return a new LS30::ResponseMessage or LS30::EventMessage.

If string is not supplied, return an empty object.

=cut

sub parse {
	my ($class, $string) = @_;

	my $self = {};
	bless $self, $class;

	if ($string) {
		return $self->_parseString($string);
	}

	return $self;
}


# ---------------------------------------------------------------------------

=item _parseString($string)

Parse the string and update $self.

=cut

sub _parseString {
	my ($self, $string) = @_;

	if ($string !~ /^!(.+)&$/) {

		# Doesn't look like a response
		confess "Invalid ResponseMessage string: $string";
	}

	if ($string =~ /^!ev/) {
		require LS30::EventMessage;
		return LS30::EventMessage->new($string);
	}

	my $return = LS30Command::parseResponse($string);
	if (!$return) {
		$self->{'error'} = "Unparseable response $string";
		return $self;
	}

	foreach my $k (keys %$return) {
		$self->{$k} = $return->{$k};
	}

	require LS30::ResponseMessage;
	bless $self, 'LS30::ResponseMessage';
	return $self;
}

sub to_hash {
	my ($self) = @_;

	my %return = map { $_ => $self->{$_} } (keys %$self);

	return \%return;
}

sub value {
	my ($self) = @_;

	return $self->{value};
}

sub get {
	my ($self, $key) = @_;

	return $self->{$key};
}

=back

=cut

1;
