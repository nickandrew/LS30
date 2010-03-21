#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

package LS30Command;

use strict;

my $commands = { };

my @wonky_hex_codes = ('0','1','2','3','4','5','6','7','8','9',':',';','<','=','>','?');

my $single_commands = [
	[ 'Date/Time', 'dt', ],
	[ 'Switch  1', 's6', ],
	[ 'Switch  2', 's7', ],
	[ 'Switch  3', 's4', ],
	[ 'Switch  4', 's5', ],
	[ 'Switch  5', 's8', ],
	[ 'Switch  6', 's9', ],
	[ 'Switch  7', 's:', ],
	[ 'Switch  8', 's;', ],
	[ 'Switch  9', 's>', ],
	[ 'Switch 10', 's?', ],
	[ 'Switch 11', 's<', ],
	[ 'Switch 12', 's=', ],
	[ 'Switch 13', 's0', ],
	[ 'Switch 14', 's1', ],
	[ 'Switch 15', 's2', ],
	[ 'Switch 16', 's3', ],
	[ 'Auto Answer Ring Count', 'a0' ],
	[ 'Sensor Supervise Time', 'a2' ],
	[ 'Modem Ring Count', 'a3' ],
	[ 'RF Jamming Warning', 'c0' ],
	[ 'Switch 16 Control', 'c8' ],
	[ 'RS-232 Control', 'c9' ],
	[ 'Remote Siren Type', 'd1' ],
	[ 'GSM Phone 1', 'g0' ],
	[ 'GSM Phone 2', 'g1' ],
	[ 'GSM ID', 'g2' ],
	[ 'GSM PIN No', 'g3' ],
	[ 'GSM Phone 3', 'g4' ],
	[ 'GSM Phone 4', 'g5' ],
	[ 'GSM Phone 5', 'g6' ],
	[ 'Exit Delay', 'l0' ],
	[ 'Entry Delay', 'l1' ],
	[ 'Remote Siren Time', 'l2' ],
	[ 'Relay Action Time', 'l3' ],
	# [ 'Inner Siren Time', 'l4' ],
	[ 'Door Bell', 'm0' ],
	[ 'Dial Tone Check', 'm1' ],
	[ 'Telephone Line Cut Detection', 'm2' ],
	[ 'Mode Change Chirp', 'm3' ],
	[ 'Emergency Button Assignment', 'm4' ],
	[ 'Entry delay beep', 'm5' ],
	[ 'Tamper Siren in Disarm', 'm7' ],
	[ 'Telephone Ringer', 'm8' ],
	[ 'Cease Dialing Mode', 'm9' ],
	[ 'Alarm Warning Dong', 'mj' ],
	[ 'Switch Type', 'mk' ],
	[ 'Operation Mode', 'n0', ],
	[ 'Inner Siren Enable', 'n1' ],
	[ 'Dial Mode', 'n2' ],
	[ 'X-10 House Code', 'n7' ],
	[ 'Inactivity Function', 'o0' ],
	[ 'ROM Version', 'vn' ],
	[ 'Telephone Common 1', 't0' ],
	[ 'Telephone Common 2', 't1' ],
	[ 'Telephone Common 3', 't2' ],
	[ 'Telephone Common 4', 't3' ],
	[ 'Telephone Panic', 't4' ],
	[ 'Telephone Burglar', 't5' ],
	[ 'Telephone Fire', 't6' ],
	[ 'Telephone Medical', 't7' ],
	[ 'Telephone Special', 't8' ],
	[ 'Telephone Latchkey/Power', 't9' ],
	[ 'Telephone Pager', 't:' ],
	[ 'Telephone Data', 't;' ],
	# CMS1
	[ 'CMS 1 Telephone No', 't<' ],
	[ 'CMS 1 User Account No', 't=' ],
	[ 'CMS 1 Mode Change Report', 'n3' ],
	[ 'CMS 1 Auto Link Check Period', 'n5' ],
	[ 'CMS 1 Two-way Audio', 'c3' ],
	[ 'CMS 1 DTMF Data Length', 'c5' ],
	[ 'CMS Report', 'c7' ],
	[ 'CMS 1 GSM No', 'tp' ],
	[ 'Ethernet (IP) Report', 'c1' ],
	[ 'GPRS Report', 'c:' ],
	[ 'IP Report Format', 'ml' ],
	# CMS2
	[ 'CMS 2 Telephone No', 't>' ],
	[ 'CMS 2 User Account No', 't?' ],
	[ 'CMS 2 Mode Change Report', 'n4' ],
	[ 'CMS 2 Auto Link Check Period', 'n6' ],
	[ 'CMS 2 Two-way Audio', 'c4' ],
	[ 'CMS 2 DTMF Data Length', 'c6' ],
	[ 'CMS 2 GSM No', 'tq' ],
];

my $spec_commands = [
	[ 'Device Status', { key => 'b3', array2 => { min => 0, max => 4 }, } ],
	[ 'Event', {
		key => 'ev',
		arg1 => {
			'length' => 3,
			encoding => 'wonkyhex',
			arg_key => 'event_id',
		},
	} ],
	[ 'Inner Siren Time', {
		key => 'l4',
		arg1 => {
			'length' => 2,
			encoding => 'wonkyhex',
			arg_key => 'siren_time',
		},
	} ],
];

my $other_commands = [
	# [ 'Partial Arm', 'n8', 90, 99 ],
	# [ 'Send message', 'f0' ],
	# [ 'RS-232 Control', 'c9' ],
	# [ 'Start Device Test', 'lt15' ],
	# [ 'Set password User2', 'ps1xxxx' ],
	# Query password 1: 'p?1' ?
	# b3?[0-4] ... get count of number of devices of specified type
	#    0 = controller
	#    1 = burglar sensor
	#    2 = fire sensor
	#    3 = medical button
	#    4 = special sensor
	# kc?00  kc?01 kc?02 ... get status of specified controller
	# kb?00  ... get status of specified burglar sensor (or ks)
	# kf?00  ... get status of specified fire sensor
	# km?00  ... get status of specified medical button
];

# Scheduling switches:
#   h?000

# Query: '!p?' . $x . '&'

my $passwords = [
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
];

sub addCommand {
	my ($title, $hr) = @_;

	if (exists $commands->{$title}) {
		warn "Command re-added: $title\n";
	}

	$commands->{$title} = $hr;
}


sub addCommands {

	# Add all the simple commands

	foreach my $lr (@$single_commands) {
		addCommand($lr->[0], { key => $lr->[1] });
	}

	foreach my $lr (@$spec_commands) {
		# These commands are specified via full hashref
		addCommand($lr->[0], $lr->[1]);
	}
}

sub listCommands {
	return (sort (keys %$commands));
}

sub getCommand {
	my ($title) = @_;

	return $commands->{$title};
}

sub queryString {
	my ($cmd_spec, $arg1, $arg2) = @_;

	if (!defined $arg1) {
		$arg1 = '';
	}

	if (!defined $arg2) {
		$arg2 = '';
	}

	my $cmd;

	if ($cmd_spec->{no_query}) {
		$cmd = '!' . $cmd_spec->{key} . $arg1 . $arg2 . '&';
	} else {
		$cmd = '!' . $cmd_spec->{key} . $arg1 . '?' . $arg2 . '&';
	}

	return $cmd;
}

sub makeCommandString {
	my ($cmd_spec, $hr) = @_;

	my $cmd = '!' . $cmd_spec->{key};

	if ($cmd_spec->{arg1}) {
		$cmd .= _append($cmd_spec->{arg1}, $hr);
	}

	if ($cmd_spec->{arg2}) {
		$cmd .= _append($cmd_spec->{arg2}, $hr);
	}

	if ($cmd_spec->{arg3}) {
		$cmd .= _append($cmd_spec->{arg3}, $hr);
	}

	$cmd .= '&';

	return $cmd;
}

sub _append {
	my ($spec, $arg) = @_;

	my $cmd = '';

	if (defined $spec->{fixed}) {
		$cmd .= $spec->{fixed};
		return $cmd;
	}

	my $arg_key = $spec->{arg_key};
	my $encoding = $spec->{encoding};
	my $length = $spec->{length};

	if ($arg_key) {
		my $value = $arg->{$arg_key};
		if (! $encoding) {
			# Do nothing to it
		}
		elsif ($encoding eq 'wonkyhex') {
			my $hex = sprintf("%0*x", $length, $value);
			$hex =~ tr/abcdef/:;<->?/;
			$value = $hex;
		}
		elsif ($encoding eq 'hex') {
			my $hex = sprintf("%*x", $length, $value);
			$value = $hex;
		}

		$cmd .= $value;
	}

	return $cmd;
}


1;
