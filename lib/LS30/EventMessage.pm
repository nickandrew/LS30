#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30::EventMessage - A message describing an event

=head1 DESCRIPTION

This class parses the contents of the LS30 Event Log.
It looks like this example:

  !ev1400000511000320150607d&

The objects of this class represent the above string decoded.

=head1 METHODS

=over

=cut

package LS30::EventMessage;

use strict;

use LS30::Type qw();


# ---------------------------------------------------------------------------

=item new($string)

Parse $string and return a new LS30::EventMessage.

If string is not supplied, return an empty object.

=cut

sub new {
	my ($class, $string) = @_;

	my $self = { };
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

	if ($string !~ m/^!ev(............)(........)(...)&$/) {
		$self->{error} = "Invalid EventMessage string: $string";
		return;
	}

	my ($junk1, $datetime, $highest_event) = ($1, $2, $3);

	my $when = parseDateTime($datetime);

	$self->{when} = $when;
	$self->{highest_event} = hex($highest_event);
	$self->{junk1} = $junk1;
	$self->{string} = $string;
}

sub parseDateTime {
	my ($when) = @_;

	$when =~ m/^(\d\d)(\d\d)(\d\d)(\d\d)/;
	my ($mm, $dd, $hh, $min) = ($1, $2, $3, $4);

	return sprintf("%02d/%02d %02d:%02d", $dd, $mm, $hh, $min);
}

1;
