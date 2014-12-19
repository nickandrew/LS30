#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

package LS30Command;

use strict;
use warnings;

use Carp qw(carp confess);

use LS30::Type qw();

my $commands      = {};
my $command_bykey = {};

# Array of all commands with simple syntax: a single value which can be
# queried and set. The array structure is:
#   [ 'Command Name', 'code', length_of_response, response_parsing_formatting_function ]

my $simple_commands = [
	['Switch 1',                     's6', 1,  \&resp_hex1],
	['Switch 2',                     's7', 1,  \&resp_hex1],
	['Switch 3',                     's4', 1,  \&resp_hex1],
	['Switch 4',                     's5', 1,  \&resp_hex1],
	['Switch 5',                     's8', 1,  \&resp_hex1],
	['Switch 6',                     's9', 1,  \&resp_hex1],
	['Switch 7',                     's:', 1,  \&resp_hex1],
	['Switch 8',                     's;', 1,  \&resp_hex1],
	['Switch 9',                     's>', 1,  \&resp_hex1],
	['Switch 10',                    's?', 1,  \&resp_hex1],
	['Switch 11',                    's<', 1,  \&resp_hex1],
	['Switch 12',                    's=', 1,  \&resp_hex1],
	['Switch 13',                    's0', 1,  \&resp_hex1],
	['Switch 14',                    's1', 1,  \&resp_hex1],
	['Switch 15',                    's2', 1,  \&resp_hex1],
	['Switch 16',                    's3', 1,  \&resp_hex1],
	['Auto Answer Ring Count',       'a0'],
	['Sensor Supervise Time',        'a2', 2,  \&resp_hex2],
	['Modem Ring Count',             'a3', 2,  \&resp_hex2],
	['RF Jamming Warning',           'c0'],
	['Switch 16 Control',            'c8'],
	['RS-232 Control',               'c9'],
	['GSM Phone 1',                  'g0', 99, \&resp_telno],
	['GSM Phone 2',                  'g1', 99, \&resp_telno],
	['GSM ID',                       'g2'],
	['GSM PIN No',                   'g3'],
	['GSM Phone 3',                  'g4', 99, \&resp_telno],
	['GSM Phone 4',                  'g5', 99, \&resp_telno],
	['GSM Phone 5',                  'g6', 99, \&resp_telno],
	['Exit Delay',                   'l0', 2,  \&resp_hex2],
	['Entry Delay',                  'l1', 2,  \&resp_hex2],
	['Remote Siren Time',            'l2', 2,  \&resp_interval2],
	['Relay Action Time',            'l3', 2,  \&resp_delay,],
	['Door Bell',                    'm0'],
	['Dial Tone Check',              'm1'],
	['Telephone Line Cut Detection', 'm2'],
	['Mode Change Chirp',            'm3', 1,  \&resp_boolean],
	['Emergency Button Assignment',  'm4'],
	['Entry delay beep',             'm5', 1,  \&resp_boolean],
	['Tamper Siren in Disarm',       'm7', 1,  \&resp_boolean],
	['Telephone Ringer',             'm8'],
	['Cease Dialing Mode',           'm9'],
	['Alarm Warning Dong',           'mj'],
	['Switch Type',                  'mk'],
	['Inner Siren Enable',           'n1', 1,  \&resp_boolean],
	['Dial Mode',                    'n2'],
	['X-10 House Code',              'n7'],
	['Inactivity Function',          'o0'],
	['ROM Version',                  'vn'],  # Read-only
	['Telephone Common 1',           't0', 99, \&resp_telno],
	['Telephone Common 2',           't1', 99, \&resp_telno],
	['Telephone Common 3',           't2', 99, \&resp_telno],
	['Telephone Common 4',           't3', 99, \&resp_telno],
	['Telephone Panic',              't4', 99, \&resp_telno],
	['Telephone Burglar',            't5', 99, \&resp_telno],
	['Telephone Fire',               't6', 99, \&resp_telno],
	['Telephone Medical',            't7', 99, \&resp_telno],
	['Telephone Special',            't8', 99, \&resp_telno],
	['Telephone Latchkey/Power',     't9', 99, \&resp_telno],
	['Telephone Pager',              't:', 99, \&resp_telno],
	['Telephone Data',               't;', 99, \&resp_telno],

	# CMS1
	['CMS 1 Telephone No',           't<', 99, \&resp_telno],
	['CMS 1 User Account No',        't=', 99, \&resp_string],
	['CMS 1 Mode Change Report',     'n3',  1, 'Enablement'],
	['CMS 1 Auto Link Check Period', 'n5',  2, \&resp_hex2],
	['CMS 1 Two-way Audio',          'c3',  1, 'Enablement'],
	['CMS 1 DTMF Data Length',       'c5',  1, 'DTMF duration'],
	['CMS Report',                   'c7',  1, 'CMS Report'],
	['CMS 1 GSM No',                 'tp', 99, \&resp_telno],
	['Ethernet (IP) Report',         'c1',  1, 'Yes/No 2'],
	['GPRS Report',                  'c:',  1, 'Yes/No 1'],
	['IP Report Format',             'ml',  1, 'IP Report Format'],

	# CMS2
	['CMS 2 Telephone No',           't>', 99, \&resp_telno],
	['CMS 2 User Account No',        't?'],
	['CMS 2 Mode Change Report',     'n4'],
	['CMS 2 Auto Link Check Period', 'n6'],
	['CMS 2 Two-way Audio',          'c4'],
	['CMS 2 DTMF Data Length',       'c6'],
	['CMS 2 GSM No',                 'tq', 99, \&resp_telno],
];

my $spec_commands = [

	{ title => 'CMS 1 Change Password',
		key => 'ps<',
		args => [
			{ 'length' => 8, func => \&resp_password, key => 'new_password' },
		],
	},

	{ title => 'CMS 2 Change Password',
		key => 'ps=',
		args => [
			{ 'length' => 8, func => \&resp_password, key => 'new_password' },
		],
	},

	{ title => 'Relay Control',
		key => 'l6',
		no_query => 1,
		args => [
			{ 'length' => 1, func => \&resp_boolean, key => 'value' },
		],
	},

	{ title => 'Date/Time',
		key => 'dt',
		args => [
			{ 'length' => 6, func => \&resp_date1, key => 'date' },
			{ 'length' => 1, type => 'Day of Week', key => 'dow' },
			{ 'length' => 4, func => \&resp_date2, key => 'time' },
		],
	},

	{ title => 'Information',
		key => 'if',
		response => [
			{ 'length' => 1, func => \&resp_string, key => 'unk1' },
			{ 'length' => 2, func => \&resp_string, key => 'unk2' },
			{ 'length' => 2, func => \&resp_string, key => 'group' },
			{ 'length' => 2, func => \&resp_string, key => 'unit' },
			{ 'length' => 8, func => \&resp_string, key => 'device_config' },
		],
	},

	{ title => 'Operation Mode',
		key => 'n0',
		args => [
			{ 'length' => 1, type => 'Arm Mode', key => 'value' },
		],
	},

	{ title => 'Device Count',
		key => 'b3',
		query_args => [
			{ 'length' => 1, type => 'Device Type', key => 'device_type' },
		],
		response => [
			{ 'length' => 2, func => \&resp_hex2, key => 'value' },
		],
	},

	{ title => 'Remote Siren Type',
		key => 'd1',
		args => [
			{ 'length' => 1, type => 'Siren Type', key => 'value' },
			{ 'length' => 2, func => \&resp_hex2, key => 'Siren ID' },
		],
	},

	{ title => 'Burglar Sensor Status',
		key => 'kb',
		response => [
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string, key => 'device_id' },
			{ 'length' => 4, func => \&resp_string, key => 'junk2' },
			{ 'length' => 2, func => \&resp_string, key => 'junk3' },
			{ 'length' => 2, func => \&resp_string, key => 'zone' },
			{ 'length' => 2, func => \&resp_string, key => 'id' },
			{ 'length' => 8, func => \&resp_string, key => 'config' },
			{ 'length' => 4, func => \&resp_string, key => 'rest' },
		],
	},

	{ title => 'Controller Status',
		key => 'kc',
		response => [
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string, key => 'device_id' },
			{ 'length' => 4, func => \&resp_string, key => 'junk2' },
			{ 'length' => 2, func => \&resp_string, key => 'junk3' },
			{ 'length' => 2, func => \&resp_string, key => 'zone' },
			{ 'length' => 2, func => \&resp_string, key => 'id' },
			{ 'length' => 8, func => \&resp_string, key => 'config' },
			{ 'length' => 4, func => \&resp_string, key => 'rest' },
		],
	},

	{ title => 'Fire Status',
		key => 'kf',
		response => [
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string, key => 'device_id' },
			{ 'length' => 4, func => \&resp_string, key => 'junk2' },
			{ 'length' => 2, func => \&resp_string, key => 'junk3' },
			{ 'length' => 2, func => \&resp_string, key => 'zone' },
			{ 'length' => 2, func => \&resp_string, key => 'id' },
			{ 'length' => 8, func => \&resp_string, key => 'config' },
			{ 'length' => 4, func => \&resp_string, key => 'rest' },
		],
	},

	{ title => 'Medical Sensor Status',
		key => 'km',
		response => [
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string, key => 'device_id' },
			{ 'length' => 4, func => \&resp_string, key => 'junk2' },
			{ 'length' => 2, func => \&resp_string, key => 'junk3' },
			{ 'length' => 2, func => \&resp_string, key => 'zone' },
			{ 'length' => 2, func => \&resp_string, key => 'id' },
			{ 'length' => 8, func => \&resp_string, key => 'config' },
			{ 'length' => 4, func => \&resp_string, key => 'rest' },
		],
	},

	{ title => 'Special Sensor Status',
		key => 'ke',
		response => [
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string, key => 'device_id' },
			{ 'length' => 4, func => \&resp_string, key => 'junk2' },
			{ 'length' => 2, func => \&resp_string, key => 'junk3' },
			{ 'length' => 2, func => \&resp_string, key => 'zone' },
			{ 'length' => 2, func => \&resp_string, key => 'id' },
			{ 'length' => 8, func => \&resp_string, key => 'config' },
			{ 'length' => 4, func => \&resp_string, key => 'rest' },
		],
	},

	{ title => 'Query Operation Schedule',
		key => 'hq',
		no_query => 1,
		query_args => [
			{ 'length' => 1, type => 'Schedule Day of Week', key => 'day_of_week' },
			{ 'length' => 2, func => \&resp_hex2, key => 'id' },
		],
	},

	{ title => 'Set Operation Schedule',
		key => 'hr',
		no_query => 1,
		no_set => 1,
		args => [
			{ 'length' => 1, type => 'Schedule Day of Week', key => 'day_of_week' },
			{ 'length' => 2, func => \&resp_hex2, key => 'id' },
			{ 'length' => 4, func => \&resp_decimal_time, key => 'start_time' },
			{ 'length' => 1, type => 'Schedule Zone', key => 'zone' },
			{ 'length' => 1, type => 'Operation Code', key => 'op_code' },
		],
	},

	{ title => 'Partial Arm',
		key => 'n8',
		query_args => [
			{ 'length' => 2, type => 'Group 91-99', key => 'group_number' },
		],
		response => [
			{ 'length' => 2, type => 'Group 91-99', key => 'group_number' },
			{ 'length' => 1, func => \&resp_boolean, key => 'value' },
		],
	},

	{ title => 'Event',
		key => 'ev',
		no_query => 1,
		query_args => [
			{ 'length' => 3, func => \&resp_hex3, key => 'value' },
		],
	},

	{ title => 'Inner Siren Time',
		key => 'l4',
		args => [
			{ 'length' => 2, func => \&resp_hex2, key => 'value' },
		],
	},

	{ title => 'Password',
		# Note 1-char key
		key => 'p',
		query_args => [
			{ 'length' => 1, type => 'Password', key => 'password_no' },
		],
		args => [
			{ 'length' => 1, type => 'Password', key => 'password_no' },
			{ 'length' => 8, func => \&resp_password, key => 'new_password' },
		],
	},

	{ title => 'Switch/Operation Scene',
		# Note 1-char key
		key => 'u',
		query_args => [
			# Low values are the switch scenes 1-8; high values are operation scenes 1-8
			{ 'length' => 1, type => 'Switch/Operation Scene', key => 'value' },
		],
	},

];

my $learn_commands = [

	{ title => 'Learn Burglar Sensor',
		key => 'ibl',
	},

	{ title => 'Learn Fire Sensor',
		key => 'ifl',
	},

	{ title => 'Learn Controller',
		key => 'icl',
	},

	{ title => 'Learn Medical Button',
		key => 'iml',
	},

	{ title => 'Learn Special Sensor',
		key => 'iel',
	},

];

my $delete_commands = [

	{ title => 'Delete Burglar Sensor',
		key => 'ibk',
		no_query => 1,
		no_set => 1,
		args => [
			{ 'length' => 2, func => \&resp_hex2, key => 'device_id' },
		],
	},

];

my $other_commands = [
	{ title => 'Send Message',
		key => 'f0',
		type => 'command',
		# Arg is 1 string, various length
		# Response is same as command
	},
	{ title => 'Voice Playback',
		key => 'vp',
		type => 'command',
		# Arg is 0 .. ?
	},
];

my $single_char_responses = {
	'h' => {
		title => 'Switch Schedule',
		args => [
			{ 'length' => 4, func => \&resp_decimal_time, key => 'start_time' },
			{ 'length' => 1, type => 'Schedule Zone', key => 'zone' },
			{ 'length' => 1, type => 'Operation Code', key => 'op_code' },
		],
	},

	'p' => {
		title => 'Password',
		args => [
			{ 'length' => 8, func => \&resp_password, key => 'current_password' },
		],
	},
};


sub addCommand {
	my ($hr) = @_;

	my $title = $hr->{title};
	my $key   = $hr->{key};

	if (exists $commands->{$title}) {
		warn "Command re-added: $title\n";
	}

	if (exists $command_bykey->{$key}) {
		warn "Command key re-added: $title, $key\n";
	}

	$commands->{$title}    = $hr;
	$command_bykey->{$key} = $hr;
}


sub addCommands {

	# Add all the simple commands

	foreach my $lr (@$simple_commands) {
		my $hr = {
			title => $lr->[0],
			key   => $lr->[1],
		};

		if ($lr->[2] && $lr->[3]) {
			my $type = (ref $lr->[3]) ? 'func' : 'type';
			$hr->{args} = [
				{ 'length' => $lr->[2], $type => $lr->[3], key => 'value' },
			];
		}

		addCommand($hr);
	}

	foreach my $hr (@$spec_commands) {

		# These commands are specified via full hashref
		addCommand($hr);
	}

	foreach my $hr (@$learn_commands) {

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

	if (!%$command_bykey) {
		addCommands();
	}

	return $command_bykey->{$key};
}

sub _password {
	my ($cmd_spec, $args) = @_;

	# Add an optional password if supplied in the arguments or if
	# supplied in an environment variable.
	my $password = $args->{password};
	if (!defined $password) {
		$password = $ENV{LS30_PASSWORD};
	}

	# Only append a password if the command spec allows it.
	# Some commands presumably cannot take a password, e.g.
	# those which take variable length strings as arguments.

	if (defined $password && !$cmd_spec->{no_password}) {
		$password = sprintf("%-8.8s", $password . '????????');
	}

	if (!defined $password) {
		$password = '';
	}

	return $password;
}

sub queryCommand {
	my ($args) = @_;

	if (!defined $args || ref($args) ne 'HASH') {
		die "queryCommand: args must be a hashref";
	}

	my $title = $args->{title};

	if (!$title) {
		die "queryCommand: args requires a title";
	}

	my $cmd_spec = getCommand($title);
	if (!$cmd_spec) {

		# Unknown title
		return undef;
	}

	my $cmd = '!';

	$cmd .= $cmd_spec->{key};

	if (!$cmd_spec->{no_query}) {
		$cmd .= '?';
	}

	if ($cmd_spec->{query_args}) {
		my $lr = $cmd_spec->{query_args};

		foreach my $hr2 (@$lr) {
			my $key  = $hr2->{key};
			my $type = $hr2->{type};
			if ($key) {
				if (!exists $args->{$key}) {
					my $s = sprintf("Args for %s is missing key %s (%s)",
						$title,
						$key,
						($type ? "code table $type" : "function"),
					);
					warn $s;
				}

				my $input = $args->{$key};
				my $value;
				if ($hr2->{func}) {
					my $func = $hr2->{func};
					$value = &$func($input, 'encode');
				} elsif ($type) {
					$value = LS30::Type::getCode($type, $input);
				}

				if (defined $value) {
					$cmd .= $value;
				}
			}
		}
	}

	# Add an optional password
	$cmd .= _password($cmd_spec, $args);

	$cmd .= '&';

	return $cmd;
}

sub setCommand {
	my ($args) = @_;

	if (!defined $args || ref($args) ne 'HASH') {
		die "setCommand: args must be a hashref";
	}

	my $title = $args->{title};

	if (!$title) {
		die "setCommand: args requires a title";
	}

	my $cmd_spec = getCommand($title);
	if (!$cmd_spec) {

		# Unknown title
		return undef;
	}

	my $cmd = '!';

	$cmd .= $cmd_spec->{key};

	if (!$cmd_spec->{no_set}) {
		$cmd .= 's';
	}

	if ($cmd_spec->{args}) {
		my $lr = $cmd_spec->{args};

		foreach my $hr2 (@$lr) {
			my $key = $hr2->{key};

			if ($key) {
				my $input = $args->{$key};

				my $value;
				if ($hr2->{func}) {
					my $func = $hr2->{func};
					$value = &$func($input, 'encode');
				} elsif ($hr2->{type}) {
					if (!defined $input) {
						warn "Needed set command key $key is missing";
					} else {
						my $type = $hr2->{type};
						$value = LS30::Type::getCode($type, $input);
						if (!defined $value) {
							warn "Incorrect value $input for Table $type, string $input";
						}
					}
				}

				if (defined $value) {
					$cmd .= $value;
				}
			}
		}
	}

	# Add an optional password
	$cmd .= _password($cmd_spec, $args);

	$cmd .= '&';

	return $cmd;
}

sub getLearnCommandSpec {
	my ($title) = @_;

	foreach my $hr (@$learn_commands) {
		if ($hr->{title} eq $title) {
			return $hr;
		}
	}

	return undef;
}

sub formatLearnCommand {
	my ($args) = @_;

	my $cmd_spec = getLearnCommandSpec($args->{title});
	my $cmd      = '!';
	$cmd .= $cmd_spec->{key};

	$cmd .= _password($cmd_spec, $args);

	$cmd .= '&';

	return $cmd;
}

sub parseResponse {
	my ($response) = @_;

	if ($response !~ /^!(.+)&$/) {

		# Doesn't look like a response
		return undef;
	}

	my $meat = $1;

	my $return = {
		string => $response,
	};

	my $skey = substr($meat, 0, 1);

	# Test if it's a single character response
	my $hr = $single_char_responses->{$skey};
	if ($hr) {
		return _parseFormat(substr($meat, 1), $hr, $return);
	}

	my $key = substr($meat, 0, 2);

	$hr = getCommandByKey($key);
	if ($hr) {
		if (substr($meat, 2, 1) eq 's') {

			# It's a response to a set command
			$return->{action} = 'set';
			$meat = substr($meat, 3);
		} else {

			# It's a response to a query command
			$return->{action} = 'query';
			$meat = substr($meat, 2);
		}

		return _parseFormat($meat, $hr, $return);
	}

	$return->{error} = "Unparseable response";
	$return->{key}   = $key;

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

	my $hex = substr($string, 0, $n);
	$hex =~ tr/:;<=>?/abcdef/;
	return hex($hex);
}

# ---------------------------------------------------------------------------
# Turn 1 hex digit into decimal
# ---------------------------------------------------------------------------

sub resp_hex1 {
	my ($string) = @_;

	return hexn($string, 1);
}

# ---------------------------------------------------------------------------
# Translate a boolean value
# ---------------------------------------------------------------------------

sub resp_boolean {
	my ($string, $op) = @_;

	if ($op && $op eq 'encode') {
		if ($string =~ /^(on|true|yes)$/i) {
			return 1;
		} elsif ($string =~ /^(off|false|no)$/i) {
			return 0;
		} elsif ($string =~ /^\d+$/) {
			if ($string > 0) {
				return 1;
			} else {
				return 0;
			}
		} else {
			warn "Invalid boolean string: $string\n";
			return 0;
		}
	}

	return ($string eq '0' ? 0 : 1);
}

# ---------------------------------------------------------------------------
# Turn 2 hex digits into decimal, or vice-versa
# ---------------------------------------------------------------------------

sub resp_hex2 {
	my ($string, $op) = @_;

	if ($op && $op eq 'encode') {
		if (!defined $string) {
			carp "Missing string in resp_hex2";
			return undef;
		}

		my $hex = sprintf("%02x", $string);
		$hex =~ tr/abcdef/:;<=>?/;
		return $hex;
	}

	return hexn($string, 2);
}

# ---------------------------------------------------------------------------
# Turn 3 hex digits into decimal, or vice-versa
# ---------------------------------------------------------------------------

sub resp_hex3 {
	my ($string, $op) = @_;

	if ($op && $op eq 'encode') {
		my $hex = sprintf("%03x", $string);
		$hex =~ tr/abcdef/:;<=>?/;
		return $hex;
	}

	return hexn($string, 3);
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
	my ($string, $op) = @_;

	if ($op && $op eq 'encode') {
		my $duration;

		if ($string =~ /^(\d+) minutes/) {
			$duration = $1 * 60;
		} elsif ($string =~ /^(\d+) seconds/) {
			$duration = $1;
		} elsif ($string =~ /^(\d+)$/) {
			$duration = $1;
		}

		my $value;

		if ($duration < 60) {
			$value = $duration;
		} else {
			$value = 64 + int($duration / 60);
		}

		my $hex = sprintf("%02x", $value);
		$hex =~ tr/abcdef/:;<=>?/;
		return $hex;
	}

	my $value = hex($string);

	if ($value > 64) {
		return sprintf("%d minutes", $value - 64);
	}

	return sprintf("%d seconds", $value);
}

# ---------------------------------------------------------------------------
# Turn dddd into dd:dd
# ---------------------------------------------------------------------------

sub resp_decimal_time {
	my ($string, $op) = @_;

	if ($op && $op eq 'encode') {
		if (!$string) {
			return '????';
		} elsif ($string =~ /^(\d\d):(\d\d)$/) {
			return "$1$2";
		} else {
			warn "Incorrect decimal_time $string";
			return '????';
		}
	}

	if ($string !~ /^(\d\d)(\d\d)$/) {
		return undef;
	}

	return "$1:$2";
}

# ---------------------------------------------------------------------------
# Return a string unchanged
# ---------------------------------------------------------------------------

sub resp_string {
	my ($string) = @_;

	return $string;
}

# ---------------------------------------------------------------------------
# Password parsing
# ---------------------------------------------------------------------------

sub resp_password {
	my ($string, $op) = @_;

	if ($op && $op eq 'encode') {

		# No change or padding required
		return $string;
	}

	if ($string eq 'no') {
		return '';
	}

	# Remove padding
	$string =~ s/\?+$//;

	return $string;
}

# ---------------------------------------------------------------------------
# Parse device config hex string: Returned from k[bcmfe] and ib commands
# Return a hashref.
# ---------------------------------------------------------------------------

sub parseDeviceConfig {
	my ($string) = @_;

	# e.g. "<4100000"
	$string =~ tr/:;<=>?/abcdef/;
	my $hr = {};

	if ($string !~ /^(..)(..)(....)$/) {
		die "Looking for an 8-char string, not $string";
	}

	my ($xes1, $xes2, $xsw) = ($1, $2, $3);
	my $es1 = hex($xes1);
	my $es2 = hex($xes2);
	my $sw  = hex($xsw);

	$hr->{string} = $string;

	$hr->{bypass}                 = ($es1 & 0x80) ? 1 : 0;
	$hr->{delay}                  = ($es1 & 0x40) ? 1 : 0;
	$hr->{hrs_24}                 = ($es1 & 0x20) ? 1 : 0;
	$hr->{home_guard}             = ($es1 & 0x10) ? 1 : 0;
	$hr->{pre_warning}            = ($es1 & 0x08) ? 1 : 0;
	$hr->{siren_alarm}            = ($es1 & 0x04) ? 1 : 0;
	$hr->{bell}                   = ($es1 & 0x02) ? 1 : 0;
	$hr->{latchkey_or_inactivity} = ($es1 & 0x01) ? 1 : 0;

	$hr->{es2_reserved_1}  = ($es2 & 0x80) ? 1 : 0;
	$hr->{es2_reserved_2}  = ($es2 & 0x40) ? 1 : 0;
	$hr->{es2_two_way}     = ($es2 & 0x20) ? 1 : 0;
	$hr->{es2_supervisory} = ($es2 & 0x10) ? 1 : 0;
	$hr->{es2_rf_voice}    = ($es2 & 0x08) ? 1 : 0;
	$hr->{es2_reserved_3}  = $es2 & 0x07;

	foreach my $switch (1 .. 15) {
		my $test = 1 << (16 - $switch);
		if ($sw & $test) {
			$hr->{"switch_$switch"} = 1;
		}
	}

	return $hr;
}

# ---------------------------------------------------------------------------
# Parse a response according to specified format
# ---------------------------------------------------------------------------

sub _parseFormat {
	my ($string, $hr, $return) = @_;

	$return->{title} = $hr->{title};

	# Use responses if defined, otherwise use argument definition
	my $response_hr = $hr->{response} || $hr->{args};

	if ($response_hr) {
		foreach my $hr2 (@$response_hr) {
			$string = _parseArg($string, $return, $hr2);
		}
	}

	return $return;
}

# ---------------------------------------------------------------------------
# Parse a single argument from an input string.
# Return the modified input string.
# ---------------------------------------------------------------------------

sub _parseArg {
	my ($string, $return, $arg_hr) = @_;

	if (!defined $string) {
		confess "_parseArg: string is not defined\n";
		return undef;
	}

	my $length = $arg_hr->{'length'};

	if (!$length) {
		die "Need to specify length";
	}

	my $input = substr($string, 0, $length);
	my $rest;
	if (length($string) >= $length) {
		$rest = substr($string, $length);
	}
	my $key = $arg_hr->{key};

	if ($arg_hr->{func}) {
		my $func_ref = $arg_hr->{func};
		$return->{$key} = &$func_ref($input, 'decode');
	} elsif ($arg_hr->{type}) {
		my $type = $arg_hr->{type};
		my $value = LS30::Type::getString($type, $input);
		$return->{$key} = $value;
	}

	return $rest;
}

# ---------------------------------------------------------------------------
# Parse/encode a date: yyyy-mm-dd <-> yymmdd
# ---------------------------------------------------------------------------

sub resp_date1 {
	my ($string, $op) = @_;

	if ($op && $op eq 'encode') {
		if ($string =~ /^(\d\d)(\d\d)-(\d\d)-(\d\d)$/) {
			return "$2$3$4";
		}

		die "Invalid format date string: $string";
	}

	if ($string =~ /^(\d\d)(\d\d)(\d\d)$/) {
		my $now = time();
		my $year = Date::Format::time2str('%Y', $now);

		if ($1 > ($year % 100)) {

			# It's a date from last century
			$year = $1 + $year - $year % 100 - 100;
		} else {
			$year = $1 + $year - $year % 100;
		}

		return sprintf("%04d-%02d-%02d", $year, $2, $3);
	}

	die "Invalid format date string: $string";
}

# ---------------------------------------------------------------------------
# Parse/create a time string: hh:mm:ss <-> hhm
# ---------------------------------------------------------------------------

sub resp_date2 {
	my ($string, $op) = @_;

	if ($op && $op eq 'encode') {
		if ($string =~ /^(\d\d):(\d\d)/) {
			return "$1$2";
		}

		die "Invalid format time string: $string";
	}

	if ($string =~ /^(\d\d)(\d\d)$/) {
		return "$1:$2:00";
	}

	die "Invalid format time string: $string";
}

1;
