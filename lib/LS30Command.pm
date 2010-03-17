#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

package LS30Command;

use strict;

my $commands = { };
my $command_bykey = { };

my @wonky_hex_codes = ('0','1','2','3','4','5','6','7','8','9',':',';','<','=','>','?');

my $single_commands = [
	[ 'Date/Time', 'dt', \&resp_date ],
	[ 'Switch  1', 's6', \&resp_hex1 ],
	[ 'Switch  2', 's7', \&resp_hex1 ],
	[ 'Switch  3', 's4', \&resp_hex1 ],
	[ 'Switch  4', 's5', \&resp_hex1 ],
	[ 'Switch  5', 's8', \&resp_hex1 ],
	[ 'Switch  6', 's9', \&resp_hex1 ],
	[ 'Switch  7', 's:', \&resp_hex1 ],
	[ 'Switch  8', 's;', \&resp_hex1 ],
	[ 'Switch  9', 's>', \&resp_hex1 ],
	[ 'Switch 10', 's?', \&resp_hex1 ],
	[ 'Switch 11', 's<', \&resp_hex1 ],
	[ 'Switch 12', 's=', \&resp_hex1 ],
	[ 'Switch 13', 's0', \&resp_hex1 ],
	[ 'Switch 14', 's1', \&resp_hex1 ],
	[ 'Switch 15', 's2', \&resp_hex1 ],
	[ 'Switch 16', 's3', \&resp_hex1 ],
	[ 'Auto Answer Ring Count', 'a0' ],
	[ 'Sensor Supervise Time', 'a2', \&resp_hex2 ],
	[ 'Modem Ring Count', 'a3', \&resp_hex2 ],
	[ 'RF Jamming Warning', 'c0' ],
	[ 'Switch 16 Control', 'c8' ],
	[ 'RS-232 Control', 'c9' ],
	[ 'Remote Siren Type', 'd1' ],
	[ 'GSM Phone 1', 'g0', \&resp_telno ],
	[ 'GSM Phone 2', 'g1', \&resp_telno ],
	[ 'GSM ID', 'g2' ],
	[ 'GSM PIN No', 'g3' ],
	[ 'GSM Phone 3', 'g4', \&resp_telno ],
	[ 'GSM Phone 4', 'g5', \&resp_telno ],
	[ 'GSM Phone 5', 'g6', \&resp_telno ],
	[ 'Exit Delay', 'l0', \&resp_hex2 ],
	[ 'Entry Delay', 'l1', \&resp_hex2 ],
	[ 'Remote Siren Time', 'l2', \&resp_interval2 ],
	[ 'Relay Action Time', 'l3', \&resp_delay, ],
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
	[ 'Telephone Common 1', 't0', \&resp_telno ],
	[ 'Telephone Common 2', 't1', \&resp_telno ],
	[ 'Telephone Common 3', 't2', \&resp_telno ],
	[ 'Telephone Common 4', 't3', \&resp_telno ],
	[ 'Telephone Panic', 't4', \&resp_telno ],
	[ 'Telephone Burglar', 't5', \&resp_telno ],
	[ 'Telephone Fire', 't6', \&resp_telno ],
	[ 'Telephone Medical', 't7', \&resp_telno ],
	[ 'Telephone Special', 't8', \&resp_telno ],
	[ 'Telephone Latchkey/Power', 't9', \&resp_telno ],
	[ 'Telephone Pager', 't:', \&resp_telno ],
	[ 'Telephone Data', 't;', \&resp_telno ],
	# CMS1
	[ 'CMS 1 Telephone No', 't<', \&resp_telno ],
	[ 'CMS 1 User Account No', 't=' ],
	[ 'CMS 1 Mode Change Report', 'n3' ],
	[ 'CMS 1 Auto Link Check Period', 'n5' ],
	[ 'CMS 1 Two-way Audio', 'c3' ],
	[ 'CMS 1 DTMF Data Length', 'c5' ],
	[ 'CMS Report', 'c7' ],
	[ 'CMS 1 GSM No', 'tp', \&resp_telno ],
	[ 'Ethernet (IP) Report', 'c1' ],
	[ 'GPRS Report', 'c:' ],
	[ 'IP Report Format', 'ml' ],
	# CMS2
	[ 'CMS 2 Telephone No', 't>', \&resp_telno ],
	[ 'CMS 2 User Account No', 't?' ],
	[ 'CMS 2 Mode Change Report', 'n4' ],
	[ 'CMS 2 Auto Link Check Period', 'n6' ],
	[ 'CMS 2 Two-way Audio', 'c4' ],
	[ 'CMS 2 DTMF Data Length', 'c6' ],
	[ 'CMS 2 GSM No', 'tq', \&resp_telno ],
];

my $spec_commands = [
	{ title => 'Device Count',
		key => 'b3',
		array2 => {
			min => 0,
			max => 4
		},
	},
	{ title => 'Partial Arm',
		key => 'n8',
		array2 => {
			min => 90,
			max => 99
		},
	},
	{ title => 'Event',
		key => 'ev',
		arg1 => {
			'length' => 3,
			encoding => 'wonkyhex',
			arg_key => 'event_id',
		},
	},
	{ title => 'Inner Siren Time',
		key => 'l4',
		arg1 => {
			'length' => 2,
			encoding => 'wonkyhex',
			arg_key => 'siren_time',
		},
		resp_func => \&resp_hex2,
	},
	{ title => 'Password',
		# Note 1-char key
		key => 'p',
		array2 => {
			min => 1,
			max => 10,
			encoding => 'wonkykex',
		},
	},
];

my $other_commands = [
	# [ 'Partial Arm', 'n8', 90, 99 ],
	{ title => 'Send Message',
		key => 'f0',
		type => 'command',
		# Arg is 1 string, various length
		# Response is same as command
	},
	{ title => 'Read Event',
		key => 'ev',
		type => 'event',
		# Arg is 3-digit event code in wonky hex
		# Response is '!ev' followed by data until '&'
	},
	{ title => 'Voice Playback',
		key => 'vp',
		type => 'command',
		# Arg is 0 .. ?
	},
	{ title => 'Get Burglar Sensor Status',
		key => 'kb',
		type => 'query',
		# Arg is 2-digit device number
		# Response is very long hex string
	},
	{ title => 'Get Controller Status',
		key => 'kc',
		type => 'query',
		# Arg is 2-digit device number
		# Response is very long hex string
	},
	{ title => 'Get Fire Sensor Status',
		key => 'kf',
		type => 'query',
		# Arg is 2-digit device number
		# Response is very long hex string
	},
	{ title => 'Get Medical Sensor Status',
		key => 'km',
		type => 'query',
		# Arg is 2-digit device number
		# Response is very long hex string
	},
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
	# h?000 ... query switches daily schedule
	# h?500 ... query switches Friday schedule
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
	my ($hr) = @_;

	my $title = $hr->{title};
	my $key = $hr->{key};

	if (exists $commands->{$title}) {
		warn "Command re-added: $title\n";
	}

	if (exists $command_bykey->{$key}) {
		warn "Command key re-added: $title, $key\n";
	}

	$commands->{$title} = $hr;
	$command_bykey->{$key} = $hr;
}


sub addCommands {

	# Add all the simple commands

	foreach my $lr (@$single_commands) {
		my $hr = {
			title => $lr->[0],
			key => $lr->[1],
		};

		if ($lr->[2]) {
			# Parsing reference
			$hr->{resp_func} = $lr->[2];
		}

		addCommand($hr);
	}

	foreach my $hr (@$spec_commands) {
		# These commands are specified via full hashref
		addCommand($hr);
	}
}

sub listCommands {
	return (sort (keys %$commands));
}

sub getCommand {
	my ($title) = @_;

	return $commands->{$title};
}

sub getCommandByKey {
	my ($key) = @_;

	if (! %$command_bykey) {
		addCommands();
	}

	return $command_bykey->{$key};
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

sub parseResponse {
	my ($response) = @_;

	if ($response !~ /^!(.+)&$/) {
		# Doesn't look like a response
		return undef;
	}

	my $meat = $1;

	my $key = substr($meat, 0, 2);

	my $hr = getCommandByKey($key);
	if (!defined $hr) {
		print "Unparseable response: $response ($meat, $key)\n";
		return undef;
	}

	my $return = {
		title => $hr->{title},
		key => $hr->{key},
	};

	if ($hr->{resp_func}) {
		my $func = $hr->{resp_func};
		my $value = &$func(substr($meat, 2));
		$return->{value} = $value;
	} else {
		$return->{value} = substr($meat, 2);
	}

	return $return;
}

# ---------------------------------------------------------------------------
# Response date: yymmddhhmm
# Turn it into yy-mm-dd hh:mm
# ---------------------------------------------------------------------------

sub resp_date {
	my ($string) = @_;

	if ($string =~ m/^(\d\d)(\d\d)(\d\d)(\d)(\d\d)(\d\d)$/) {
		my $dow = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']->[$4];
		return "$1-$2-$3 $5:$6 $dow";
	}

	return undef;
}

# ---------------------------------------------------------------------------
# Turn n hex digits into decimal
# ---------------------------------------------------------------------------

sub hexn {
	my ($string, $n) = @_;

	return hex(substr($string, 0, $n));
}

# ---------------------------------------------------------------------------
# Turn 1 hex digit into decimal
# ---------------------------------------------------------------------------

sub resp_hex1 {
	my ($string) = @_;

	return hexn($string, 1);
}

# ---------------------------------------------------------------------------
# Turn 2 hex digits into decimal
# ---------------------------------------------------------------------------

sub resp_hex2 {
	my ($string) = @_;

	return hexn($string, 2);
}

# ---------------------------------------------------------------------------
# Parse a telephone number
# ---------------------------------------------------------------------------

sub resp_telno {
	my ($string) = @_;

	if ($string eq 'no') {
		# Can mean no number, or permission denied
		return '';
	}

	return $string;
}

# ---------------------------------------------------------------------------
# Parse a delay time which may be in seconds or minutes
# ---------------------------------------------------------------------------

sub resp_delay {
	my ($string) = @_;

	my $value = hex($string);

	if ($value > 128) {
		return sprintf("%d minutes", $value - 128);
	}

	return sprintf("%d seconds", $value);
}

# ---------------------------------------------------------------------------
# Parse a 2nd type of interval
# ---------------------------------------------------------------------------

sub resp_interval2 {
	my ($string) = @_;

	my $value = hex($string);

	if ($value > 64) {
		return sprintf("%d minutes", $value - 64);
	}

	return sprintf("%d seconds", $value);
}

1;
