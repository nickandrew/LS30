#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
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

use Date::Format qw();

use LS30::Type qw();


my $this_year;    # Used in adding year to events
my $this_month;


# ---------------------------------------------------------------------------

=item new($string)

Parse $string and return a new LS30::EventMessage.

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

	if ($string !~ m/^!ev(.)(...)(..)(..)(..)(..)(........)(...)&$/) {
		$self->{error} = "Invalid EventMessage string: $string";
		return;
	}

	my ($event_type, $event_code, $group_num, $source, $unit_num, $junk1, $datetime, $highest_event) = ($1, $2, $3, $4, $5, $6, $7, $8);


	$self->{event_type}    = $event_type;
	$self->{event_code}    = $event_code;
	$self->{code_string}   = LS30::Type::getCode('Event Log Code', $event_type . $event_code) || '';
	$self->{group_num}     = $group_num;
	$self->{source_string} = LS30::Type::getCode('Event Source Code', $source) || '';
	$self->{unit_num}      = $unit_num;
	$self->{when}          = _parseDateTime($datetime);
	$self->{highest_event} = hex($highest_event);
	$self->{junk1}         = $junk1;
	$self->{string}        = $string;

	if (!$self->{code_string} || !$self->{source_string}) {
		$self->{unknown} = 1;
	}

	$self->{display_string} = sprintf("%s %s%s-%s %s",
		$self->{when},
		$self->{source_string},
		$group_num,
		$unit_num,
		$self->{code_string},
	);
}

sub _parseDateTime {
	my ($when) = @_;

	$when =~ m/^(\d\d)(\d\d)(\d\d)(\d\d)/;
	my ($mm, $dd, $hh, $min) = ($1, $2, $3, $4);

	if (!$this_year) {
		my $now = time();
		$this_year  = Date::Format::time2str('%Y', $now);
		$this_month = Date::Format::time2str('%m', $now);
	}

	my $year;

	if ($mm > $this_month) {

		# It must have been last year
		$year = $this_year - 1;
	} else {
		$year = $this_year;
	}

	return sprintf("%04d-%02d-%02d %02d:%02d:00", $year, $mm, $dd, $hh, $min);
}


# ---------------------------------------------------------------------------

=item getHighestEvent()

Return the number of the last event written. This value is between 1 and
512; after 512 it will loop to 1.

=cut

sub getHighestEvent {
	my ($self) = @_;

	return $self->{highest_event};
}


# ---------------------------------------------------------------------------

=item getEventType()

Return the 1-character type code of the event. Values:

  1  Event starts (e.g. RF Lost)

  3  Event stops (e.g. RF Recovered)

=cut

sub getEventType {
	my ($self) = @_;

	return $self->{event_type};
}


# ---------------------------------------------------------------------------

=item getEventCode()

Return the 3-character code of this event. The codes are based on ContactID.
The type and code concatenated (4 chars) determines the message shown on
the LS-30 LCD display.

=cut

sub getEventCode {
	my ($self) = @_;

	return $self->{event_code};
}


# ---------------------------------------------------------------------------

=item getDisplayString()

Return the display string, i.e. close to the message shown on the LS-30 LCD
display.

=cut

sub getDisplayString {
	my ($self) = @_;

	return $self->{display_string};
}

=back

=cut

1;
