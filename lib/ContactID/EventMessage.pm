#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

ContactID::EventMessage - A status update message using Contact ID

=head1 SYNOPSIS

This class parses the device's status update messages in the Contact ID
protocol. For example:

String: 1688181602005009

Meaning: Preferred New Event/Opening Periodic test report group 00 zone 500

The objects of this class represent the above strings decoded.

=head1 METHODS

=over

=cut

package ContactID::EventMessage;

use strict;

use Carp qw(confess);

use ContactID::EventCode qw();
use LS30::Type qw();


# ---------------------------------------------------------------------------

=item new($string)

Parse $string and return a new ContactID::EventMessage.

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

	if ($string !~ m/^(....)(..)(.)(...)(..)(...)(.)$/) {
		confess "Invalid ContactID string: $string";
	}

	my ($acct, $mt, $q, $xyz, $gg, $ccc, $s) = ($1, $2, $3, $4, $5, $6, $7);

	my $unknown = '';
	my $describe = '';

	if ($acct ne '1688') {
		$unknown .= " acct($acct)";
	}

	if ($mt eq '18') {
		$self->{type} = 'Preferred';
	}
	elsif ($mt eq '98') {
		$self->{type} = 'Optional';
	}
	else {
		$self->{type} = 'Unknown';
		$unknown .= " mt($mt)";
	}

	if ($q eq '1') {
		$self->{event} = "New Event/Opening";
	} elsif ($q eq '3') {
		$self->{event} = "New Restore/Closing";
	} elsif ($q eq '6') {
		$self->{event} = "Status report";
	} else {
		$self->{event} = "Unknown Event";
		$unknown .= " q($q)";
	}

	my $event_description = ContactID::EventCode::eventDescription($xyz) || "Unknown code $xyz";
	$self->{event_description} = $event_description;

	$self->{string} = $string;
	$self->{group} = "$gg";
	$self->{zone} = "$ccc";

	if ($unknown) {
		$self->{unknown} = $unknown;
	}
}


# ---------------------------------------------------------------------------

=item getString()

Return the unparsed message string.

=cut

sub getString {
	my ($self) = @_;

	return $self->{string};
}

sub getUnknown {
	my ($self) = @_;

	return $self->{unknown};
}


# ---------------------------------------------------------------------------

=item getDescription()

Return the description part of the message.

=cut

sub getDescription {
	my ($self) = @_;

	return $self->{event_description};
}


# ---------------------------------------------------------------------------

=item getGroup()

Return the group number.

=cut

sub getGroup {
	my ($self) = @_;

	return $self->{group};
}


# ---------------------------------------------------------------------------

=item getZone()

Return the zone number.

=cut

sub getZone {
	my ($self) = @_;

	return $self->{zone};
}


# ---------------------------------------------------------------------------

=item asText()

Return a text representation of this message.

=cut

sub asText {
	my ($self) = @_;

	return join(' ',
		$self->{string},
		$self->{type},
		$self->{event},
		$self->{event_description},
		"group $self->{group}",
		"zone $self->{zone}",
		$self->{unknown} ? $self->{unknown} : '',
	);
}

1;
