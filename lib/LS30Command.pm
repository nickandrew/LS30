#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30Command - Definition of the LS-30 command set

=head1 DESCRIPTION

All known LS-30 commands are defined here.

There are 'simple' commands, which more or less correspond to the named
settings, which read or write a single value.

There are more complicated commands which take more than one parameter,
and may return complex data structures.

There are also learn-type commands which put the LS-30 into a device
learning state.

=head1 METHODS

=over

=cut

package LS30Command;

use strict;
use warnings;

use Carp qw(carp confess);

use LS30::Log qw();
use LS30::Type qw();

my $commands      = {};
my $command_bykey = {};

# Array of all commands with simple syntax: a single value which can be
# queried and set. The array structure is:
#   [ 'Command Name', 'code', length_of_response, response_parsing_formatting_function OR type string ]

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
	['Auto Answer Ring Count',       'a0', 2,  \&resp_hex2],
	['Sensor Supervise Time',        'a2', 2,  \&resp_hex2],
	['Modem Ring Count',             'a3', 2,  \&resp_hex2],
	['RF Jamming Warning',           'c0', 1,  'Enablement'],
	['Switch 16 Control',            'c8', 1,  'Switch 16'],
	['RS-232 Control',               'c9', 1,  'Reverse Enablement'],
	['Exit Delay',                   'l0', 2,  \&resp_hex2],
	['Entry Delay',                  'l1', 2,  \&resp_hex2],
	['Remote Siren Time',            'l2', 2,  \&resp_interval2],
	['Relay Action Time',            'l3', 2,  \&resp_delay],
	['Door Bell',                    'm0', 1,  'Switch'],
	['Dial Tone Check',              'm1', 1,  'Enablement'],
	['Telephone Line Cut Detection', 'm2', 1,  'Telephone Line Cut'],
	['Mode Change Chirp',            'm3', 1,  \&resp_boolean],
	['Emergency Button Assignment',  'm4', 1,  'Emergency Button'],
	['Entry delay beep',             'm5', 1,  \&resp_boolean],
	['Tamper Siren in Disarm',       'm7', 1,  \&resp_boolean],
	['Telephone Ringer',             'm8', 1,  'Enablement'],
	['Cease Dialing Mode',           'm9', 1,  'Cease Dialing'],
	['Alarm Warning Dong',           'mj', 1,  \&resp_boolean],
	['Switch Type',                  'mk', 1,  'Switch Type'],
	['Inner Siren Enable',           'n1', 1,  \&resp_boolean],
	['Dial Mode',                    'n2', 1,  'Dial Mode'],
	['X-10 House Code',              'n7', 1,  \&resp_hex1],  # A-P is 0x0-0xf
	['Inactivity Function',          'o0', 2,  \&resp_hex2],
	['ROM Version',                  'vn', 99, \&resp_string],          # Read-only
	['Telephone Common 1',           't0', 99, \&resp_telno],
	['Telephone Common 2',           't1', 99, \&resp_telno],
	['Telephone Common 3',           't2', 99, \&resp_telno],
	['Telephone Common 4',           't3', 99, \&resp_telno],
	['Telephone Panic',              't4', 99, \&resp_telno],
	['Telephone Burglar',            't5', 99, \&resp_telno],
	['Telephone Fire',               't6', 99, \&resp_telno],
	['Telephone Medical',        't7', 99, \&resp_telno],    # Suffix 'v' (Voice) or 't' (DTMF)
	['Telephone Special',        't8', 99, \&resp_telno],
	['Telephone Latchkey/Power', 't9', 99, \&resp_telno],
	['Telephone Pager',          't:', 99, \&resp_telno],
	['Telephone Data',           't;', 99, \&resp_telno],

	# CMS1
	['CMS 1 Telephone No',           't<', 99, \&resp_telno],
	['CMS 1 User Account No',        't=', 99, \&resp_string],
	['CMS 1 Mode Change Report',     'n3', 1,  'Enablement'],
	['CMS 1 Auto Link Check Period', 'n5', 2,  \&resp_hex2],
	['CMS 1 Two-way Audio',          'c3', 1,  'Enablement'],
	['CMS 1 DTMF Data Length',       'c5', 1,  'DTMF duration'],
	['CMS Report',                   'c7', 1,  'CMS Report'],
	['CMS 1 GSM No',                 'tp', 99, \&resp_telno],
	['Ethernet (IP) Report',         'c1', 1,  'Yes/No 2'],
	['GPRS Report',                  'c:', 1,  'Yes/No 1'],
	['IP Report Format',             'ml', 1,  'IP Report Format'],

	# CMS2
	['CMS 2 Telephone No',           't>', 99, \&resp_telno],
	['CMS 2 User Account No',        't?', 99, \&resp_string],
	['CMS 2 Mode Change Report',     'n4', 1,  'Enablement'],
	['CMS 2 Auto Link Check Period', 'n6', 2,  \&resp_hex2],
	['CMS 2 Two-way Audio',          'c4', 1,  'Enablement'],
	['CMS 2 DTMF Data Length',       'c6', 1,  'DTMF duration'],
	['CMS 2 GSM No',                 'tq', 99, \&resp_telno],

	# Unknown
	['Undocumented 1',               'le', 99, \&resp_string],
];

my $gsm_commands = [
	{
		title      => 'GSM Phone 1',
		can_clear  => 1,
		is_setting => 1,
		key        => 'g0',
		args       => [{ 'length' => 23, func => \&resp_telno, key => 'value' }],
	},
	{
		title      => 'GSM Phone 2',
		can_clear  => 1,
		is_setting => 1,
		key        => 'g1',
		args       => [{ 'length' => 23, func => \&resp_telno, key => 'value' }],
	},
	{
		title      => 'GSM ID',
		can_clear  => 1,
		is_setting => 1,
		key        => 'g2',
		args       => [{ 'length' => 23, func => \&resp_string, key => 'value' }],
	},
	{
		title      => 'GSM PIN No',
		can_clear  => 1,
		is_setting => 1,
		key        => 'g3',
		args       => [{ 'length' => 23, func => \&resp_string, key => 'value' }],
	},
	{
		title      => 'GSM Phone 3',
		can_clear  => 1,
		is_setting => 1,
		key        => 'g4',
		args       => [{ 'length' => 23, func => \&resp_telno, key => 'value' }],
	},
	{
		title      => 'GSM Phone 4',
		can_clear  => 1,
		is_setting => 1,
		key        => 'g5',
		args       => [{ 'length' => 23, func => \&resp_telno, key => 'value' }],
	},
	{
		title      => 'GSM Phone 5',
		can_clear  => 1,
		is_setting => 1,
		key        => 'g6',
		args       => [{ 'length' => 23, func => \&resp_telno, key => 'value' }],
	},
];

my $spec_commands = [

	{
		title => 'CMS 1 Change Password',
		key   => 'ps<',
		args  => [{ 'length' => 8, func => \&resp_password, key => 'new_password' },],
	},

	{
		title => 'CMS 2 Change Password',
		key   => 'ps=',
		args  => [{ 'length' => 8, func => \&resp_password, key => 'new_password' },],
	},

	{
		title    => 'Relay Control',
		key      => 'l6',
		no_query => 1,
		args     => [{ 'length' => 1, func => \&resp_boolean, key => 'value' },],
	},

	{
		title  => 'Date/Time',
		key    => 'dt',
		subsys => 'datetime',
		args   => [
			{ 'length' => 6, func => \&resp_date1,  key => 'date' },
			{ 'length' => 1, type => 'Day of Week', key => 'dow' },
			{ 'length' => 4, func => \&resp_date2,  key => 'time' },
		],
	},

	{
		title    => 'Information Burglar Sensor',
		key      => 'ib',
		# On a 'set' command, 'query_args' are not used, only 'args'
		args => [
			{ 'length' => 2, func => \&resp_hex2,            key => 'index' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
		],
		query_args => [
			{ 'length' => 2, func => \&resp_hex2,   key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,   key => 'id' },
		],
		response => [
			{ 'length' => 2, func => \&resp_hex2,            key => 'index' },
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string,          key => 'device_id' },
			{ 'length' => 2, func => \&resp_string,          key => 'module_address' },
			{ 'length' => 2, func => \&resp_string,          key => 'dc' },
			{ 'length' => 2, func => \&resp_string,          key => 'checksum' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
			{ 'length' => 2, func => \&resp_string,          key => 'cs' },
			{ 'length' => 2, func => \&resp_string,          key => 'dt' },
		],
	},

	{
		title    => 'Information Controller',
		key      => 'ic',
		# On a 'set' command, 'query_args' are not used, only 'args'
		args => [
			{ 'length' => 2, func => \&resp_hex2,            key => 'index' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
		],
		query_args => [
			{ 'length' => 2, func => \&resp_hex2,   key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,   key => 'id' },
		],
		response => [
			{ 'length' => 2, func => \&resp_hex2,            key => 'index' },
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string,          key => 'device_id' },
			{ 'length' => 2, func => \&resp_string,          key => 'module_address' },
			{ 'length' => 2, func => \&resp_string,          key => 'dc' },
			{ 'length' => 2, func => \&resp_string,          key => 'checksum' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
			{ 'length' => 2, func => \&resp_string,          key => 'cs' },
			{ 'length' => 2, func => \&resp_string,          key => 'dt' },
		],
	},

	{
		title    => 'Information Special Sensor',
		key      => 'ie',
		# On a 'set' command, 'query_args' are not used, only 'args'
		args => [
			{ 'length' => 2, func => \&resp_hex2,            key => 'index' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
		],
		query_args => [
			{ 'length' => 2, func => \&resp_hex2,   key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,   key => 'id' },
		],
		response => [
			{ 'length' => 2, func => \&resp_hex2,            key => 'index' },
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string,          key => 'device_id' },
			{ 'length' => 2, func => \&resp_string,          key => 'module_address' },
			{ 'length' => 2, func => \&resp_string,          key => 'dc' },
			{ 'length' => 2, func => \&resp_string,          key => 'checksum' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
			{ 'length' => 2, func => \&resp_string,          key => 'cs' },
			{ 'length' => 2, func => \&resp_string,          key => 'dt' },
			{ 'length' => 2, func => \&resp_string,          key => 'cd' }, # current data
			{ 'length' => 2, func => \&resp_string,          key => 'hl' }, # high limit
			{ 'length' => 2, func => \&resp_string,          key => 'll' }, # low limit
			{ 'length' => 2, func => \&resp_string,          key => 'ss' }, # special sensor status
		],
	},

	{
		title    => 'Information Fire Sensor',
		key      => 'if',
		# On a 'set' command, 'query_args' are not used, only 'args'
		args => [
			{ 'length' => 2, func => \&resp_hex2,            key => 'index' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
		],
		query_args => [
			{ 'length' => 2, func => \&resp_hex2,   key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,   key => 'id' },
		],
		response => [
			{ 'length' => 2, func => \&resp_hex2,            key => 'index' },
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string,          key => 'device_id' },
			{ 'length' => 2, func => \&resp_string,          key => 'module_address' },
			{ 'length' => 2, func => \&resp_string,          key => 'dc' },
			{ 'length' => 2, func => \&resp_string,          key => 'checksum' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
			{ 'length' => 2, func => \&resp_string,          key => 'cs' },
			{ 'length' => 2, func => \&resp_string,          key => 'dt' },
		],
	},

	{
		title    => 'Information Medical Button',
		key      => 'im',
		# On a 'set' command, 'query_args' are not used, only 'args'
		args => [
			{ 'length' => 2, func => \&resp_hex2,            key => 'index' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
		],
		query_args => [
			{ 'length' => 2, func => \&resp_hex2,   key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,   key => 'id' },
		],
		response => [
			{ 'length' => 2, func => \&resp_hex2,            key => 'index' },
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string,          key => 'device_id' },
			{ 'length' => 2, func => \&resp_string,          key => 'module_address' },
			{ 'length' => 2, func => \&resp_string,          key => 'dc' },
			{ 'length' => 2, func => \&resp_string,          key => 'checksum' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
			{ 'length' => 2, func => \&resp_string,          key => 'cs' },
			{ 'length' => 2, func => \&resp_string,          key => 'dt' },
		],
	},

	{
		is_setting => 1,
		title => 'Operation Mode',
		key   => 'n0',
		args  => [{ 'length' => 1, type => 'Arm Mode', key => 'value' },],
	},

	{
		title      => 'Device Count',
		key        => 'b3',
		query_args => [{ 'length' => 1, type => 'Device Type', key => 'device_type' },],
		response   => [{ 'length' => 2, func => \&resp_hex2, key => 'value' },],
	},

	{
		title => 'Remote Siren Type',
		key   => 'd1',
		args  => [
			{ 'length' => 1, type => 'Siren Type', key => 'value' },
			{ 'length' => 2, func => \&resp_hex2,  key => 'Siren ID' },
		],
	},

	{
		title      => 'Burglar Sensor Status',
		key        => 'kb',
		query_args => [
			# devices array index starts at 00
			{ 'length' => 2, func => \&resp_hex2, key => 'index' },
		],
		response   => [
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string,          key => 'device_id' },
			{ 'length' => 2, func => \&resp_string,          key => 'module_address' },
			{ 'length' => 2, func => \&resp_string,          key => 'dc' },
			{ 'length' => 2, func => \&resp_string,          key => 'checksum' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
			{ 'length' => 2, func => \&resp_string,          key => 'cs' },
			{ 'length' => 2, func => \&resp_string,          key => 'dt' },
			{ 'length' => 2, func => \&resp_string,          key => 'cd' }, # current data
			{ 'length' => 2, func => \&resp_string,          key => 'hl' }, # high limit
			{ 'length' => 2, func => \&resp_string,          key => 'll' }, # low limit
			{ 'length' => 2, func => \&resp_string,          key => 'ss' }, # special sensor status
		],
	},

	{
		title      => 'Controller Status',
		key        => 'kc',
		query_args => [
			# devices array index starts at 00
			{ 'length' => 2, func => \&resp_hex2, key => 'index' },
		],
		response   => [
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string,          key => 'device_id' },
			{ 'length' => 2, func => \&resp_string,          key => 'module_address' },
			{ 'length' => 2, func => \&resp_string,          key => 'dc' },
			{ 'length' => 2, func => \&resp_string,          key => 'checksum' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
			{ 'length' => 2, func => \&resp_string,          key => 'cs' },
			{ 'length' => 2, func => \&resp_string,          key => 'dt' },
		],
	},

	{
		title      => 'Fire Sensor Status',
		key        => 'kf',
		query_args => [
			# devices array index starts at 00
			{ 'length' => 2, func => \&resp_hex2, key => 'index' },
		],
		response   => [
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string,          key => 'device_id' },
			{ 'length' => 2, func => \&resp_string,          key => 'module_address' },
			{ 'length' => 2, func => \&resp_string,          key => 'dc' },
			{ 'length' => 2, func => \&resp_string,          key => 'checksum' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
			{ 'length' => 2, func => \&resp_string,          key => 'cs' },
			{ 'length' => 2, func => \&resp_string,          key => 'dt' },
		],
	},

	{
		title      => 'Medical Button Status',
		key        => 'km',
		query_args => [
			# devices array index starts at 00
			{ 'length' => 2, func => \&resp_hex2, key => 'index' },
		],
		response   => [
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string,          key => 'device_id' },
			{ 'length' => 2, func => \&resp_string,          key => 'module_address' },
			{ 'length' => 2, func => \&resp_string,          key => 'dc' },
			{ 'length' => 2, func => \&resp_string,          key => 'checksum' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
			{ 'length' => 2, func => \&resp_string,          key => 'cs' },
			{ 'length' => 2, func => \&resp_string,          key => 'dt' },
		],
	},

	{
		title      => 'Special Sensor Status',
		key        => 'ke',
		query_args => [
			# devices array index starts at 00
			{ 'length' => 2, func => \&resp_hex2, key => 'index' },
		],
		response   => [
			{ 'length' => 2, type => 'Device Specific Type', key => 'type' },
			{ 'length' => 6, func => \&resp_string,          key => 'device_id' },
			{ 'length' => 2, func => \&resp_string,          key => 'module_address' },
			{ 'length' => 2, func => \&resp_string,          key => 'dc' },
			{ 'length' => 2, func => \&resp_string,          key => 'checksum' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'zone' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 8, func => \&resp_string,          key => 'config' },
			{ 'length' => 2, func => \&resp_string,          key => 'cs' },
			{ 'length' => 2, func => \&resp_string,          key => 'dt' },
		],
	},

	{
		title      => 'Query Operation Schedule',
		key        => 'hq',
		no_query   => 1,
		query_args => [
			{ 'length' => 1, type => 'Schedule Day of Week', key => 'day_of_week' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
		],
	},

	{
		title    => 'Set Operation Schedule',
		key      => 'hr',
		no_query => 1,
		no_set   => 1,
		args     => [
			{ 'length' => 1, type => 'Schedule Day of Week', key => 'day_of_week' },
			{ 'length' => 2, func => \&resp_hex2,            key => 'id' },
			{ 'length' => 4, func => \&resp_decimal_time,    key => 'start_time' },
			{ 'length' => 1, type => 'Schedule Zone',        key => 'zone' },
			{ 'length' => 1, type => 'Operation Code',       key => 'op_code' },
		],
	},

	{
		title      => 'Partial Arm',
		is_setting => 1,
		key        => 'n8',
		query_args => [{ 'length' => 2, type => 'Group 91-99', key => 'group_number' },],
		args      => [
			{ 'length' => 1, func => \&resp_boolean, key => 'value' },
		],
	},

	{
		title      => 'Event',
		key        => 'ev',
		subsys     => 'eventlog',
		no_query   => 1,
		query_args => [{ 'length' => 3, func => \&resp_hex3, key => 'index' },],
		response   => [
			{ 'length' => 4, func => \&resp_string, key => 'event_type_code' },
			{ 'length' => 2, func => \&resp_string, key => 'group_number' },
			{ 'length' => 2, func => \&resp_string, key => 'source' },
			{ 'length' => 2, func => \&resp_string, key => 'unit_number' },
			{ 'length' => 2, func => \&resp_string, key => 'junk1' },
			{ 'length' => 8, func => \&resp_string, key => 'datetime' },
			{ 'length' => 3, func => \&resp_string, key => 'highest_event' },
		],
	},

	{
		title      => 'Inner Siren Time',
		is_setting => 1,
		key        => 'l4',
		args       => [{ 'length' => 2, func => \&resp_hex2, key => 'value' },],
	},

	{
		title => 'Switch/Operation Scene',
		is_setting => 1,
		key        => 'u',
		query_args => [

			# Low values are the switch scenes 1-8; high values are operation scenes 1-8
			{ 'length' => 1, type => 'Switch/Operation Scene', key => 'value' },
		],
	},

	{
		title => 'Undocumented 2',
		key   => 'l5',
		subsys => 'cms',
	},

];

my $learn_commands = [

	{
		title => 'Learn Burglar Sensor',
		key   => 'ibl',
		async_response => {
			title    => 'Added Burglar Sensor',
			length   => 14,
			response => [
				{ length => 2, func => \&resp_hex2, key => 'index' },
				{ length => 2, func => \&resp_hex2,   key => 'zone' },
				{ length => 2, func => \&resp_hex2,   key => 'id' },
				{ length => 8, func => \&resp_string, key => 'config' },
			],
		},
	},

	{
		title => 'Learn Fire Sensor',
		key   => 'ifl',
		async_response => {
			title    => 'Added Fire Sensor',
			length   => 14,
			response => [
				{ length => 2, func => \&resp_hex2, key => 'index' },
				{ length => 2, func => \&resp_hex2,   key => 'zone' },
				{ length => 2, func => \&resp_hex2,   key => 'id' },
				{ length => 8, func => \&resp_string, key => 'config' },
			],
		},
	},

	{
		title => 'Learn Controller',
		key   => 'icl',
		async_response => {
			title    => 'Added Controller',
			length   => 14,
			response => [
				{ length => 2, func => \&resp_hex2, key => 'index' },
				{ length => 2, func => \&resp_hex2,   key => 'zone' },
				{ length => 2, func => \&resp_hex2,   key => 'id' },
				{ length => 8, func => \&resp_string, key => 'config' },
			],
		},
	},

	{
		title => 'Learn Medical Button',
		key   => 'iml',
		async_response => {
			title    => 'Added Medical Button',
			length   => 14,
			response => [
				{ length => 2, func => \&resp_hex2, key => 'index' },
				{ length => 2, func => \&resp_hex2,   key => 'zone' },
				{ length => 2, func => \&resp_hex2,   key => 'id' },
				{ length => 8, func => \&resp_string, key => 'config' },
			],
		},
	},

	{
		title => 'Learn Special Sensor',
		key   => 'iel',
		async_response => {
			title    => 'Added Special Sensor',
			length   => 14,
			response => [
				{ length => 2, func => \&resp_hex2, key => 'index' },
				{ length => 2, func => \&resp_hex2,   key => 'zone' },
				{ length => 2, func => \&resp_hex2,   key => 'id' },
				{ length => 8, func => \&resp_string, key => 'config' },
			],
		},
	},

];

my $delete_commands = [

	{
		title      => 'Delete Burglar Sensor',
		key        => 'ibk',
		no_query   => 1,
		no_set     => 1,
		query_args => [{ 'length' => 2, func => \&resp_hex2, key => 'device_id' },],
	},

	{
		title      => 'Delete Controller',
		key        => 'ick',
		no_query   => 1,
		no_set     => 1,
		query_args => [{ 'length' => 2, func => \&resp_hex2, key => 'device_id' },],
	},

	{
		title      => 'Delete Fire Sensor',
		key        => 'ifk',
		no_query   => 1,
		no_set     => 1,
		query_args => [{ 'length' => 2, func => \&resp_hex2, key => 'device_id' },],
	},

	{
		title      => 'Delete Medical Button',
		key        => 'imk',
		no_query   => 1,
		no_set     => 1,
		query_args => [{ 'length' => 2, func => \&resp_hex2, key => 'device_id' },],
	},

	{
		title      => 'Delete Special Sensor',
		key        => 'iek',
		no_query   => 1,
		no_set     => 1,
		query_args => [{ 'length' => 2, func => \&resp_hex2, key => 'device_id' },],
	},

];

my $other_commands = [{
		title => 'Send Message',
		key   => 'f0',
		type  => 'command',

		# Arg is 1 string, various length
		# Response is same as command
	},
	{
		title => 'Voice Playback',
		key   => 'vp',
		type  => 'command',

		# Arg is 0 .. ?
	},

	{
		title => 'Voice Record',
		key   => 'vr',
		type  => 'command',

		# Arg is 0 .. ?
	},

];

my $single_char_responses = {
	'h' => {
		title => 'Switch Schedule',
		args  => [
			{ 'length' => 4, func => \&resp_decimal_time, key => 'start_time' },
			{ 'length' => 1, type => 'Schedule Zone',     key => 'zone' },
			{ 'length' => 1, type => 'Operation Code',    key => 'op_code' },
		],
	},

	'p' => {
		title => 'Password',
		args  => [{ 'length' => 8, func => \&resp_password, key => 'current_password' },],
	},
};

# Map device type to the title of a command (specified above) to retrieve
# the current device status.
my $get_device_status_commands = {
	'Burglar Sensor' => 'Burglar Sensor Status',
	'Controller'     => 'Controller Status',
	'Fire Sensor'    => 'Fire Sensor Status',
	'Medical Button' => 'Medical Button Status',
	'Special Sensor' => 'Special Sensor Status',
};

# ---------------------------------------------------------------------------

=item I<addCommand($hr)>

Add the command specification to the class list of commands. Used internally.

=cut

sub addCommand {
	my ($hr) = @_;

	my $title = $hr->{title};
	my $key   = $hr->{key};

	if (exists $commands->{$title}) {
		LS30::Log::error("Command re-added: $title");
	}

	if (exists $command_bykey->{$key}) {
		LS30::Log::error("Command key re-added: $title, $key");
	}

	$commands->{$title}    = $hr;
	$command_bykey->{$key} = $hr;
}

# ---------------------------------------------------------------------------

=item I<addCommands()>

Add all known commands to the class list of commands.

Must be called once in client code.

=cut

sub addCommands {

	# Add all the simple commands

	foreach my $lr (@$simple_commands) {
		my $hr = {
			is_setting => 1,
			title => $lr->[0],
			key   => $lr->[1],
		};

		if ($lr->[2] && $lr->[3]) {
			my $type = (ref $lr->[3]) ? 'func' : 'type';
			$hr->{args} = [{ 'length' => $lr->[2], $type => $lr->[3], key => 'value' },];
		}

		addCommand($hr);
	}

	# These commands are specified via full hashref
	foreach my $hr (@$gsm_commands) {
		addCommand($hr);
	}

	# These commands are specified via full hashref
	foreach my $hr (@$spec_commands) {
		addCommand($hr);
	}

	# These commands are specified via full hashref
	foreach my $hr (@$learn_commands) {
		addCommand($hr);
	}

	# These commands are specified via full hashref
	foreach my $hr (@$delete_commands) {
		addCommand($hr);
	}
}

# ---------------------------------------------------------------------------

=item I<listCommands()>

Return a list of the titles of all known commands.

=cut

sub listCommands {
	return (sort (keys %$commands));
}

# ---------------------------------------------------------------------------

=item I<getCommand($title)>

Return the hashref describing the command with the given title.

=cut

sub getCommand {
	my ($title) = @_;

	return $commands->{$title};
}

# ---------------------------------------------------------------------------

=item I<isSetting($title)>

Return 1 if the given title is a setting, else zero.

=cut

sub isSetting {
	my ($title) = @_;

	return 1 if ($commands->{$title} && $commands->{$title}->{is_setting});
	return 0;
}

# ---------------------------------------------------------------------------

=item I<canClear($title)>

Return 1 if the given title is a clearable setting, else zero.

=cut

sub canClear {
	my ($title) = @_;

	return 1 if ($commands->{$title} && $commands->{$title}->{can_clear});
	return 0;
}

# ---------------------------------------------------------------------------

=item I<getCommandByKey($key)>

Return the title of the command which has the given (1 or 2 char) key.

Used to decode the protocol.

=cut

sub getCommandByKey {
	my ($key) = @_;

	if (!%$command_bykey) {
		addCommands();
	}

	return $command_bykey->{$key};
}

# ---------------------------------------------------------------------------
# Return a password string for appending to a command
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Iterate through 'query_args' array to build strings to append to a command.
# 'query_args' is for mandatory arguments to provide to a parameterised command.
# 'args' is for providing values to a 'set' command, and for interpreting responses.
# Return undef if there's an error, else appended string.
# ---------------------------------------------------------------------------

sub _addArguments {
	my ($cmd, $args, $lr, $title, $encoding) = @_;

	foreach my $hr2 (@$lr) {
		my $key  = $hr2->{key};
		my $type = $hr2->{type};

		if ($key) {
			if (!exists $args->{$key}) {
				my $s = sprintf(
					"Args for %s is missing key %s (%s)",
					$title, $key, ($type ? "code table $type" : "function"),
				);
				LS30::Log::error($s);
				return undef;
			}

			my $input = $args->{$key};
			my $value;
			if ($hr2->{func}) {
				my $func = $hr2->{func};
				$value = &$func($input, $encoding);
			} elsif (!$type) {
				LS30::Log::error("No type defined in $title for <$key>");
				return undef;
			} elsif ($encoding eq 'decode') {
				$value = LS30::Type::getString($type, $input);
			} else {
				$value = LS30::Type::getCode($type, $input);
			}

			if (!defined $value) {
				LS30::Log::error("Illegal value <$input> for <$key>");
				return undef;
			}

			$cmd .= $value;
		}
	}

	return $cmd;
}

# ---------------------------------------------------------------------------

=item I<queryCommand($args)>

Construct and return a query command string.

$args is a hashref containing 'title' and possibly other command-specific
arguments.

=cut

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
		$cmd = _addArguments($cmd, $args, $lr, $title, 'client_encode');
		return undef if (!defined $cmd);
	}

	# Add an optional password
	$cmd .= _password($cmd_spec, $args);

	$cmd .= '&';

	return $cmd;
}

# ---------------------------------------------------------------------------

=item I<setCommand($args)>

Construct and return a set command string.

$args is a hashref containing 'title' and possibly other command-specific
arguments.

If the command to be issued takes a single variable (e.g. is a setting),
that variable will be called 'value'. Otherwise, it depends on the command
specification.

=cut

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

				if (!defined $input) {
					LS30::Log::error("Needed set command key <$key> is missing");
					return undef;
				} else {
					$value = _testValue($hr2, $input);
				}

				if (!defined $value) {
					LS30::Log::error("Illegal value <$input> for <$key>");
					return undef;
				}

				$cmd .= $value;
			}
		}
	}

	# Add an optional password
	$cmd .= _password($cmd_spec, $args);

	$cmd .= '&';

	return $cmd;
}

# ---------------------------------------------------------------------------

=item I<clearCommand($args)>

Construct and return a clear command string.

$args is a hashref containing 'title'.

=cut

sub clearCommand {
	my ($args) = @_;

	if (!defined $args || ref($args) ne 'HASH') {
		die "setCommand: args must be a hashref";
	}

	my $title = $args->{title};

	if (!$title) {
		die "clearCommand: args requires a title";
	}

	my $cmd_spec = getCommand($title);
	if (!$cmd_spec) {

		# Unknown title
		return undef;
	}

	if (!$cmd_spec->{can_clear}) {
		die "clearCommand: <$title> is not clearable";
	}

	my $cmd = '!';

	$cmd .= $cmd_spec->{key};

	$cmd .= 'k';

	# Add an optional password
	$cmd .= _password($cmd_spec, $args);

	$cmd .= '&';

	return $cmd;
}

# ---------------------------------------------------------------------------

=item I<getLearnCommandSpec($title)>

Return the hashref specifying a specific learning command.

=cut

sub getLearnCommandSpec {
	my ($title) = @_;

	foreach my $hr (@$learn_commands) {
		if ($hr->{title} eq $title) {
			return $hr;
		}
	}

	return undef;
}

# ---------------------------------------------------------------------------

=item I<formatLearnCommand($args)>

Create a learn command string, specified by the supplied $args hashref.

=cut

sub formatLearnCommand {
	my ($args) = @_;

	my $cmd_spec = getLearnCommandSpec($args->{title});
	my $cmd      = '!';
	$cmd .= $cmd_spec->{key};

	$cmd .= _password($cmd_spec, $args);

	$cmd .= '&';

	return $cmd;
}

# ---------------------------------------------------------------------------

=item I<getDeleteCommandSpec($title)>

Return the hashref specifying a specific device deletion command.

=cut

sub getDeleteCommandSpec {
	my ($title) = @_;

	foreach my $hr (@$delete_commands) {
		if ($hr->{title} eq $title) {
			return $hr;
		}
	}

	return undef;
}

# ---------------------------------------------------------------------------

=item I<formatDeleteCommand($args)>

Create a delete command string, specified by the supplied $args hashref.

=cut

sub formatDeleteCommand {
	my ($args) = @_;

	my $cmd_spec = getDeleteCommandSpec($args->{title});
	my $cmd      = '!';
	$cmd .= $cmd_spec->{key};

	if ($cmd_spec->{query_args}) {
		$cmd = _addArguments($cmd, $args, $cmd_spec->{query_args}, $args->{title}, 'client_encode');
		return undef if (!defined $cmd);
	}

	$cmd .= _password($cmd_spec, $args);

	$cmd .= '&';

	return $cmd;
}

# ---------------------------------------------------------------------------

=item I<setPassword($password_id, $new_password, $master_password)>

Return a command string to set the specified password.

    password_id is a string of type 'Password' (See LS30::Type)

    new_password is 0-8 characters long

    master_password is 1-8 characters long (if shorter than 8, it will be padded with ?).

Any errors cause a return value of undef and a message in $@

=cut

sub setPassword {
	my ($password_id, $new_password, $master_password) = @_;

	my $string = '!ps';

	my $id = LS30::Type::getCode('Password', $password_id);
	if (!defined $id) {
		$@ = "Invalid password id $password_id";
		return undef;
	}

	$string .= $id;

	if (length($new_password) > 8) {
		$@ = "New password too long";
		return undef;
	}

	# Acceptable chars for new_password: hex digits
	if ($new_password !~ /^[0-9a-f]{0,8}$/) {
		$@ = "New password contains unacceptable characters";
		return undef;
	}

	# Acceptable chars for master_password: hex digits
	if ($master_password !~ /^[0-9a-f]{0,8}$/) {
		$@ = "Master password contains unacceptable characters";
		return undef;
	}

	$new_password =~ tr/abcdef/:;<=>?/;
	$master_password =~ tr/abcdef/:;<=>?/;

	$string .= $new_password;

	my $l = length($master_password);
	if ($l == 0) {
		# Not supplied
	}
	elsif ($l < 8) {
		$string .= $master_password;
		# Pad to 8 chars
		$string .= '?' x (8 - $l);
	}
	elsif ($l > 8) {
		$@ = "Master password too long";
		return undef;
	}

	$string .= '&';

	return $string;
}

# ---------------------------------------------------------------------------

=item I<parseResponse($string)>

Parse the response string received from an LS-30 server.

Response strings start with '!' and end with '&'.

Return a detailed hashref.

=cut

sub parseResponse {
	my ($response) = @_;

	my $return = { string => $response, };

	if ($response !~ /^!(.+)&$/) {

		# Doesn't look like a response
		$return->{error} = "Not in response format";
		return $return;
	}

	my $meat = $1;

	my $key = substr($meat, 0, 3);
	my $hr = getCommandByKey($key);

	if (!$hr) {
		# Try 2-char key
		$key = substr($meat, 0, 2);
		$hr = getCommandByKey($key);
	}

	if (!$hr) {
		$key = substr($meat, 0, 1);
		# Test if it's a single character response
		my $hr = $single_char_responses->{$key};
		if ($hr) {
			$meat = _parseFormat(substr($meat, 1), $return, $hr->{args});
		}
		return $return;
	}

	if ($hr) {
		$return->{title} = $hr->{title};

		$meat = substr($meat, length($key));
		if (substr($meat, 0, 1) eq 's') {

			# It's a response to a set command
			$return->{action} = 'set';
			$meat = substr($meat, 1);
		} elsif (substr($meat, 0, 1) eq 'k') {

			# It's a response to a clear command
			$return->{action} = 'clear';
			$meat = substr($meat, 1);
			# Command should finish here
			if ($meat ne '&') {
				LS30::Log::debug("Extra chars after clear command: <$meat>");
			}
		} elsif (substr($meat, 0, 1) eq '?') {
			# It's a query command
			$return->{action} = 'query';
			$meat = substr($meat, 1);
		} else {

			# It's a response to a query command
			$return->{action} = 'value';
		}

		if ($return->{action} eq 'clear') {
			# Nothing further
			return $return;
		}

		if ($return->{action} eq 'query') {
			if ($hr->{query_args}) {
				# Parse further arguments
				$meat = _parseFormat($meat, $return, $hr->{query_args});
			}
			# Nothing further
			return $return;
		}

		my $p_hr = $hr;

		# Test if this is an asynchronous response to a learn command
		if ($hr->{async_response} && length($meat) == $hr->{async_response}->{length}) {
			$p_hr = $hr->{async_response};
			$return->{title} = $p_hr->{title};
			# Fall through to parse it according to async_response
		}

		# Use responses if defined, otherwise use argument definition
		$meat = _parseFormat($meat, $return, $p_hr->{response} || $p_hr->{args});

		# Check for NAK on a set command
		if (defined $meat && $meat eq 'no') {
			$return->{error} = "Command failed";
		}

		return $return;
	}

	$return->{error} = "Unparseable response";

	return $return;
}

# ---------------------------------------------------------------------------
# Special parsing for 'p' password request
# Formats:
#   Set:   'p' 's' <id> <new-password> <master-password>
#   Query: 'p' '?' <id> <master-password>
# ---------------------------------------------------------------------------

sub _parsePasswordRequest {
	my ($string, $return) = @_;

	if ($string !~ /^p([s?])(.)/) {
		$return->{error} = "Password not a set or query action";
		return $return;
	}

	my($a, $id) = ($1, $2);
	$string = substr($string, 3);

	if ($a eq 's') {
		$return->{action} = 'set-password';
		$return->{password_id} = LS30::Type::getString('Password', $id);

		my $l = length($string);
		if ($l < 8) {
			# Set command with no master password
			$return->{new_password} = $string;
		}
		elsif ($l == 8) {
			# Clear command
			$return->{new_password} = '';
			$return->{password} = $string;
		}
		else {
			# Variable length new_password; fixed-length password.
			$return->{new_password} = substr($string, 0, $l - 8);
			$return->{password} = substr($string, -8, 8);
		}
	}
	else {
		$return->{action} = 'query-password';
		$return->{password_id} = LS30::Type::getString('Password', $id);

		if ($string eq '') {
			return $return;
		}

		if (length($string) != 8) {
			# This can't be a password
			$return->{error} = "Password query isn't suffixed with valid password <$string>";
		} else {
			$return->{password} = $string;
		}
	}

	return $return;
}

=item I<parseRequest($string)>

Parse the request string received from a client. Requests are very similar
to responses, but knowing a string is a request may help with the parsing.

Also requests may have a trailing password, whereas responses do not.

Request strings start with '!' and end with '&'.

Return a detailed hashref.

=cut

sub parseRequest {
	my ($request) = @_;

	my $return = { string => $request, };

	if ($request !~ /^!(.+)&$/) {

		# Doesn't look like a request
		$return->{error} = "Not in request format";
		return $return;
	}

	my $meat = $1;

	# Special parser handling
	if (substr($meat, 0, 1) eq 'p') {
		# Password set/retrieval
		return _parsePasswordRequest($meat, $return);
	}

	my $key = substr($meat, 0, 3);
	my $hr = getCommandByKey($key);

	if (!$hr) {
		# Try 2-char key
		$key = substr($meat, 0, 2);
		$hr = getCommandByKey($key);
	}

	if (!$hr) {
		# Try 1-char key
		$key = substr($meat, 0, 1);
		$hr = getCommandByKey($key);
	}

	if (!$hr) {
		$return->{error} = sprintf("Unparseable request <%s>", substr($meat, 0, 3));
		return $return;
	}

	# Which subsystem does this command belong to?
	my $subsys = $return->{subsys} = $hr->{subsys} || 'settings';

	$return->{title} = $hr->{title};

	$meat = substr($meat, length($key));

	if ($hr->{is_setting}) {
		if (substr($meat, 0, 1) eq 's') {

			# It's a set request
			$return->{action} = 'set';
			$meat = substr($meat, 1);
		} elsif (substr($meat, 0, 1) eq 'k') {

			# It's a clear request
			$return->{action} = 'clear';
			$meat = substr($meat, 1);
			# Command should finish here
			if ($meat ne '&') {
				LS30::Log::debug("Extra chars after clear command: <$meat>");
			}
		} elsif (substr($meat, 0, 1) eq '?') {
			# It's a query request
			$return->{action} = 'query';
			$meat = substr($meat, 1);
		} else {

			# It's something else
			$return->{error} = "Expected s/k/? after setting name <$key>";
			return $return;
		}
	} else {
		if (substr($meat, 0, 1) eq '?') {
			# It's a read-only query
			$return->{action} = 'query';
			$meat = substr($meat, 1);
		}
	}

	if ($subsys eq 'datetime') {
		# Date/Time has set and query but is not a setting
		if (substr($meat, 0, 1) eq 's') {
			# It's a set request
			$return->{action} = 'set';
			$meat = substr($meat, 1);
		} elsif (substr($meat, 0, 1) eq '?') {
			# It's a query request
			$return->{action} = 'query';
			$meat = substr($meat, 1);
		}
	}
	elsif ($subsys eq 'eventlog') {
		$return->{action} = 'query';
	}
	elsif ($subsys eq 'cms') {
		$return->{action} = 'unknown';
	}

	if ($return->{error}) {
		return $return;
	}

	if (!$return->{action}) {
		$return->{error} = "No action has been found";
		return $return;
	}

	if ($return->{action} eq 'clear') {
		# Nothing further
	}

	if ($return->{action} eq 'query' or $hr->{no_query}) {
		# no_query means no '?' appears in the input string. query_args may still follow.
		# Parse query_args if specified
		$meat = _parseFormat($meat, $return, $hr->{query_args});
	}

	if ($return->{action} eq 'set') {
		# Parse query_args if specified
		$meat = _parseFormat($meat, $return, $hr->{query_args});

		# Parse args if specified
		$meat = _parseFormat($meat, $return, $hr->{args});
	}

	my $p_hr = $hr;

	# Finally, parse the optional password
	_parsePassword($meat, $return);

	return $return;
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
# Response date: yymmddWhhmm
# Turn it into yy-mm-dd hh:mm
# ---------------------------------------------------------------------------

sub resp_date {
	my ($string, $op) = @_;

	if ($op eq 'decode') {
		if ($string =~ m/^(\d\d)(\d\d)(\d\d)(\d)(\d\d)(\d\d)$/) {
			my $dow = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']->[$4];
			return "$1-$2-$3 $5:$6 $dow";
		}

		return undef;
	}

	# Client and server encoding are the same
	if (defined $string && $string =~ /^(\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d) (\S+)$/) {
		my $dows = {
			'Sun' => 0,
			'Mon' => 1,
			'Tue' => 2,
			'Wed' => 3,
			'Thu' => 4,
			'Fri' => 5,
			'Sat' => 6,
		};
		my $dow_int = $dows->{$6} || 0;
		return "$1$2$3$dow_int$4$5";
	}

	# Fallthrough; return the current date/time
	my $now = time();
	return Date::Format::time2str('%y%m%d%w%H%M', $now);
}

# ---------------------------------------------------------------------------
# Turn 1 hex digit into decimal
# ---------------------------------------------------------------------------

sub resp_hex1 {
	my ($string, $op) = @_;

	if ($op eq 'decode') {
		return hexn($string, 1);
	}

	if (!defined $string) {
		carp "Missing string in resp_hex1";
		return undef;
	}

	my $hex = sprintf("%1x", $string);

	if ($op eq 'client_encode') {
		$hex =~ tr/abcdef/:;<=>?/;
	}

	return $hex;
}

# ---------------------------------------------------------------------------
# Translate a boolean value
# ---------------------------------------------------------------------------

sub resp_boolean {
	my ($string, $op) = @_;

	if ($op eq 'decode') {
		return ($string eq '0' ? 0 : 1);
	}

	if ($op eq 'client_encode') {
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
			LS30::Log::error("Invalid boolean string: $string");
			return 0;
		}
	}

	# This doesn't seem exactly the opposite of client_encode due to
	# all the synonyms
	return ($string ? 1 : 0);
}

# ---------------------------------------------------------------------------
# Turn 2 hex digits into decimal, or vice-versa
# ---------------------------------------------------------------------------

sub resp_hex2 {
	my ($string, $op) = @_;

	if ($op eq 'decode') {
		return hexn($string, 2);
	}

	if ($op eq 'client_encode') {
		if (!defined $string) {
			carp "Missing string in resp_hex2";
			return undef;
		}

		my $hex = sprintf("%02x", $string);
		$hex =~ tr/abcdef/:;<=>?/;
		return $hex;
	}

	return sprintf("%02x", $string);
}

# ---------------------------------------------------------------------------
# Turn 3 hex digits into decimal, or vice-versa
# ---------------------------------------------------------------------------

sub resp_hex3 {
	my ($string, $op) = @_;

	if ($op eq 'decode') {
		return hexn($string, 3);
	}

	if ($op eq 'client_encode') {
		my $hex = sprintf("%03x", $string);
		$hex =~ tr/abcdef/:;<=>?/;
		return $hex;
	}

	return sprintf("%03x", $string);
}

# ---------------------------------------------------------------------------
# Parse a telephone number
# ---------------------------------------------------------------------------

sub resp_telno {
	my ($string, $op) = @_;

	if ($op eq 'decode') {
		if ($string eq 'no') {

			# Can mean no number, or permission denied
			return '';
		}
		return $string;
	}

	return 'no' if (!defined $string || $string eq '');
	return $string;
}

# ---------------------------------------------------------------------------
# Parse a delay time which may be in seconds or minutes
# ---------------------------------------------------------------------------

sub resp_delay {
	my ($string, $op) = @_;

	if ($op eq 'decode') {
		my $value = hex($string);

		if ($value > 128) {
			return sprintf("%d minutes", $value - 128);
		}

		return sprintf("%d seconds", $value);
	}

	my $hex;

	if ($string =~ /(\d+) minutes/) {
		$hex = sprintf("%02x", $1 + 128);
	}

	if ($string =~ /(\d+) seconds/) {
		$hex = sprintf("%02x", $1);
	}

	if ($op eq 'client_encode') {
		$hex =~ tr/abcdef/:;<=>?/;
	}

	return $hex;
}

# ---------------------------------------------------------------------------
# Parse a 2nd type of interval
# ---------------------------------------------------------------------------

sub resp_interval2 {
	my ($string, $op) = @_;

	if ($op eq 'decode') {
		my $value = hex($string);

		if ($value > 64) {
			return sprintf("%d minutes", $value - 64);
		}

		return sprintf("%d seconds", $value);
	}

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

	if ($op eq 'client_encode') {
		$hex =~ tr/abcdef/:;<=>?/;
	}

	return $hex;
}

# ---------------------------------------------------------------------------
# Turn dddd into dd:dd
# ---------------------------------------------------------------------------

sub resp_decimal_time {
	my ($string, $op) = @_;

	if ($op eq 'decode') {
		if ($string !~ /^(\d\d)(\d\d)$/) {
			return undef;
		}

		return "$1:$2";
	}

	if (!$string) {
		return '????';
	} elsif ($string =~ /^(\d\d):(\d\d)$/) {
		return "$1$2";
	} else {
		LS30::Log::error("Incorrect decimal_time $string");
		return '????';
	}
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

	if ($op eq 'decode') {

		if ($string eq 'no') {
			return '';
		}

		# Remove padding
		$string =~ s/\?+$//;

		return $string;
	}

	# Client and server encoding are identical
	if ($string eq '') {
		$string = 'no';
	}

	# No change or padding required
	return $string;
}

# ---------------------------------------------------------------------------
# Parse/encode a date: yyyy-mm-dd <-> yymmdd
# ---------------------------------------------------------------------------

sub resp_date1 {
	my ($string, $op) = @_;

	if ($op eq 'decode') {
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

	if ($string =~ /^(\d\d)(\d\d)-(\d\d)-(\d\d)$/) {
		return "$2$3$4";
	}

	warn "Invalid format date string: $string";
	return undef;
}

# ---------------------------------------------------------------------------
# Parse/create a time string: hh:mm:ss <-> hhm
# ---------------------------------------------------------------------------

sub resp_date2 {
	my ($string, $op) = @_;

	if ($op eq 'decode') {
		if ($string =~ /^(\d\d)(\d\d)$/) {
			return "$1:$2:00";
		}

		die "Invalid format time string: $string";
	}

	if ($string =~ /^(\d\d):(\d\d)/) {
		return "$1$2";
	}

	warn "Invalid format time string: $string";
	return undef;
}

# ---------------------------------------------------------------------------

=item I<parseDeviceConfig($string)>

Parse device config hex string: Returned from k[bcmfe] and ib commands.

Return a hashref.

=cut

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
# Return remainder of string (or undef if error)
# ---------------------------------------------------------------------------

sub _parseFormat {
	my ($string, $return, $response_lr) = @_;

	if ($response_lr) {
		foreach my $hr2 (@$response_lr) {
			$string = _parseArg($string, $return, $hr2);
			return undef if (!defined $string);
		}
	}

	return $string;
}

# ---------------------------------------------------------------------------
# Parse a single argument from an input string.
# Return the modified input string.
# ---------------------------------------------------------------------------

sub _parseArg {
	my ($string, $return, $arg_hr) = @_;

	if (!defined $string) {
		$return->{error} = "_parseArg: input string is not defined\n";
		return undef;
	}

	my $length = $arg_hr->{'length'};

	if (!$length) {
		die "Command spec: Need to specify length";
	}

	my $input = substr($string, 0, $length);
	my $rest;
	if (length($string) >= $length) {
		$rest = substr($string, $length);
	}
	my $key = $arg_hr->{key};

	if ($arg_hr->{func}) {
		my $func_ref = $arg_hr->{func};
		my $value = &$func_ref($input, 'decode');
		if (!defined $value) {
			$return->{error} = "Unable to decode argument <$key>: <$input>";
		} else {
			$return->{$key} = $value;
		}
	} elsif ($arg_hr->{type}) {
		my $type = $arg_hr->{type};
		my $value = LS30::Type::getString($type, $input);
		$return->{$key} = $value;
		if (!defined $value) {
			$return->{error} = "Invalid value of type <$type>: <$input>";
		} else {
			$return->{$key} = $value;
		}
	}

	return $rest;
}

# ---------------------------------------------------------------------------
# Parse an optional password
# ---------------------------------------------------------------------------

sub _parsePassword {
	my ($string, $return) = @_;

	if (defined $string && length($string) == 8) {
		$return->{password} = $string;
	}
}

# ---------------------------------------------------------------------------
# Test if the supplied value is valid as an argument.
# hr is an argument hashref, not a setting hashref.
# Return undef if there's a problem, otherwise the converted value.
# ---------------------------------------------------------------------------

sub _testValue {
	my ($hr, $input) = @_;

	my $func = $hr->{func};

	if ($func) {
		# Input is defined in terms of a function
		my $ok = &$func($input, 'client_encode');
		if (!defined $ok) {
			# Assume it's bad
			return undef;
		} else {
			return $ok;
		}
	}

	my $type = $hr->{type};

	if ($type) {
		if (!defined $input) {
			return undef;
		} else {
			my $type = $hr->{type};
			my $ok = LS30::Type::getCode($type, $input);
			if (!defined $ok) {
				LS30::Log::error("Incorrect value <$input> for table <$type>");
			}
			return $ok;
		}
	}

	return undef;
}

# ---------------------------------------------------------------------------

=item I<testSettingValue($title, $value)>

Test if the supplied value $value is valid for the specified title $title.

If invalid, return undef.

Otherwise return the mapped value (i.e. the value which would appear in a
command or response string).

=cut

sub testSettingValue {
	my ($title, $value) = @_;

	my $hr = getCommand($title);

	if (!defined $hr || !$hr->{is_setting}) {
		LS30::Log::error("No setting <$title>");
		return 0;
	}

	if (!$hr->{args} || !$hr->{args}->[0]) {
		LS30::Log::error("Setting <$title> has no defined arguments");
		return 0;
	}

	return _testValue($hr->{args}->[0], $value);
}

# ---------------------------------------------------------------------------

=item I<getDeviceStatusCommand($device_type, $index)>

Return a command string to retrieve the device status for a specified
type of device.

Example: getDeviceStatus('Burglar Sensor', 0);

=cut

sub getDeviceStatus {
	my ($device_type, $index) = @_;

	my $title = $get_device_status_commands->{$device_type} or die "Invalid device type <$device_type";
	my $query = {title => $title, index => $index};
	my $cmd = queryCommand($query) or die "Invalid query command <$title>";

	return $cmd;
}

# ---------------------------------------------------------------------------

=item I<formatResponse($args)>

Format a response message from the server to a client. Return it as a string,
or undef if there was some error.

=cut

sub formatResponse {
	my ($args) = @_;

	if (!defined $args || ref($args) ne 'HASH') {
		die "formatResponse: args must be a hashref";
	}

	my $title = $args->{title};

	if (!$title) {
		die "formatResponse: args requires a title";
	}

	my $cmd_spec = getCommand($title);
	if (!$cmd_spec) {

		# Unknown title
		return undef;
	}

	my $string = '!';

	$string .= $cmd_spec->{key};

	my $lr = $cmd_spec->{response} || $cmd_spec->{args};
	$string = _addArguments($string, $args, $lr, $title, 'server_encode');
	return undef if (!defined $string);

	$string .= '&';

	return $string;
}

=back

=cut

1;
