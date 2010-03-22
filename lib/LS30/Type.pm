#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30::Type - Enumerated types used by LS30 Alarm system

=head1 METHODS

=over

=cut

package LS30::Type;

use strict;

use Carp qw(confess);

my $type_table = {

	# Appears in MINPIC messages
	'Device Specific Type' => {
		'Remote Control' => '10',
		'Keypad' => '19',
		'Smoke Detector' => '20',
		'Door Switch' => '40',
		'PIR' => '50',
		'Siren' => '70',
	},

	# Appears in MINPIC messages
	'Event Code' => {
		'Away mode' => '0a10',
		'Check Status' => '0a13',
		'Disarm mode' => '0a14',
		'Home mode' => '0a18',
		'Test' => '0a20',
		'Low Battery' => '0a30',
		'Open' => '0a40',
		'Close' => '0a48',
		'Tamper' => '0a50',
		'Trigger' => '0a58',
		'Panic' => '0a60',
	},

	# 'b3' command
	'Device Type' => {
		'Controller' => '0',
		'Burglar Sensor' => '1',
		'Fire Sensor' => '2',
		'Medical Button' => '3',
		'Special Sensor' => '4',
	},

	'Group' => {
		'Group 90' => '90',
		'Group 91' => '91',
		'Group 92' => '92',
		'Group 93' => '93',
		'Group 94' => '94',
		'Group 95' => '95',
		'Group 96' => '96',
		'Group 97' => '97',
		'Group 98' => '98',
		'Group 99' => '99',
	},

	# Query/Set Operation Schedule
	'Schedule Zone' => {
		'Main' => '0',
		'Zone 91' => '1',
		'Zone 92' => '2',
		'Zone 93' => '3',
		'Zone 94' => '4',
		'Zone 95' => '5',
		'Zone 96' => '6',
		'Zone 97' => '7',
		'Zone 98' => '8',
		'Zone 99' => '9',
	},

	# Used in Operation Schedule
	'Operation Code' => {
		'Disarm' => '1',
		'Home' => '2',
		'Away' => '3',
		'Monitor' => '9',
	},

	# 'n0' command
	'Arm Mode' => {
		'Disarm' => '0',
		'Home' => '1',
		'Away' => '2',
		'Monitor' => '8',
	},

	'Day of Week' => {
		'Mon' => '1',
		'Tue' => '2',
		'Wed' => '3',
		'Thu' => '4',
		'Fri' => '5',
		'Sat' => '6',
		'Sun' => '7',
	},

	'Schedule Day of Week' => {
		'Daily' => '0',
		'Mon' => '1',
		'Tue' => '2',
		'Wed' => '3',
		'Thu' => '4',
		'Fri' => '5',
		'Sat' => '6',
		'Sun' => '7',
	},

	'Password' => {
		'Master' => '0',
		'USER2' => '1',
		'USER3' => '2',
		'USER4' => '3',
		'USER5' => '4',
		'USER6' => '5',
		'USER7' => '6',
		'USER8' => '7',
		'USER9(L)' => '8',
		'USER10(L)' => '9',
		'Duress' => ':',
	},

	'Switch' => {
		'Off' => '0',
		'On' => '1',
	},

	'Enablement' => {
		'Disabled' => '0',
		'Enabled' => '1',
	},

	'Dial Mode' => {
		'Dial Tone(DTMF)' => '0',
		'Dial Pulse (33/66 B/M Ratio)' => '1',
	},

	'Switch Type' => {
		'X-10' => '0',
		'Type 2' => '1',
		'Type 3' => '2',
		'Type 4' => '3',
		'Type 5' => '4',
	},

	'Emergency Button' => {
		'Panic' => '0',
		'Medical' => '1',
	},

	# 'd1' command
	'Siren Type' => {
		'Standard' => '0',
		'HA Series' => '1',
	},

};

my $reverse_table = { };


# ---------------------------------------------------------------------------

=item getCode($table, $string)

Return the code associated with string $string in the specified table.

Die if the table does not exist. Return undef if the string does not
exist.

=cut

sub getCode {
	my ($table, $string) = @_;

	my $hr = $type_table->{$table};
	if (! $hr) {
		confess "No such LS30::Type ($table)";
	}

	return $hr->{$string};
}


# ---------------------------------------------------------------------------

=item getString($table, $code)

Return the string associated with code $code in the specified table.

Die if the table does not exist. Return undef if the code does not
exist. This function works by building reverse lookup hashes of the
main table.

=cut

sub getString {
	my ($table, $code) = @_;

	my $hr = $type_table->{$table};
	if (! $hr) {
		confess "No such LS30::Type ($table)";
	}

	if (! $reverse_table->{$table}) {
		# Build the reverse table
		foreach my $k (keys %$hr) {
			my $value = $hr->{$k};
			$reverse_table->{$table}->{$value} = $k;
		}
	}

	return $reverse_table->{$table}->{$code};
}

1;
