#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Arm or Disarm the alarm

use strict;
use warnings;

use Getopt::Std qw(getopts);

use LS30Command qw();
use LS30Connection qw();
use LS30::Commander qw();
use LS30::ResponseMessage qw();
use LS30::Type qw();

use vars qw($opt_h $opt_m);

getopts('h:m:');

my @mode_list = LS30::Type::listStrings('Arm Mode');

if (!$opt_m) {
	die "Must specify option -m; valid modes are: " . join(', ', @mode_list);
}

my $mode;

foreach my $m (@mode_list) {
	if ($opt_m =~ /^$m$/i) {
		$mode = $m;
		last;
	}
}

if (!$mode) {
	die "Incorrect -m option: valid modes are: " . join(', ', @mode_list);
}

my $hr = { title => 'Operation Mode', value => $mode };

# Connect and send commands

my $ls30c = LS30Connection->new($opt_h);

$ls30c->connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c, 5);

my $cmd = LS30Command::setCommand($hr);

if (!defined $cmd) {
	die "Invalid command";
}

my $response = $ls30cmdr->sendCommand($cmd);

if (!$response) {
	die "No response to $mode command";
}

my $resp_obj = LS30::ResponseMessage->new($response);

my $error = $resp_obj->get('error');
if ($error) {
	printf("%-40s | Error: %s\n", $hr->{title}, $error);
} else {
	printf("%-40s | %s\n", $hr->{title}, $resp_obj->value);
}

exit(0);
