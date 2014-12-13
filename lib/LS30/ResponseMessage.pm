#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30::ResponseMessage - Parsed response message

=head1 DESCRIPTION

This class parses response messages from the LS30 (e.g. "!a0&").

=head1 METHODS

=over

=cut

package LS30::ResponseMessage;

use strict;
use warnings;

use Carp qw(confess);

use LS30Command qw();

# ---------------------------------------------------------------------------

=item new($string)

Parse $string and return a new LS30::ResponseMessage.

If string is not supplied, return an empty object.

=cut

sub new {
	my ($class, $string) = @_;

	my $self = {};
	bless $self, $class;

	if ($string) {
		$self->_parseString($string);
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

	my $return = LS30Command::parseResponse($string);
	if (!$return) {
		$self->{'error'} = "Unparseable response $string";
		return;
	}

	foreach my $k (keys %$return) {
		$self->{$k} = $return->{$k};
	}
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

1;
