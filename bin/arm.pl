#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Arm or Disarm the alarm

use Getopt::Std qw(getopts);

use LS30Command qw();
use LS30Connection qw();
use LS30::Commander qw();
use LS30::ResponseMessage qw();
use LS30::Type qw();

use vars qw($opt_h $opt_m);

getopts('h:m:');

my @mode_list = LS30::Type::listStrings('Arm Mode');

if (! $opt_m) {
	die "Must specify option -m; valid modes are: " . join(', ', @mode_list);
}

my $mode;

foreach my $m (@mode_list) {
	if ($opt_m =~ /$m/i) {
		$mode = $m;
		last;
	}
}

if (! $mode) {
	die "Incorrect -m option: valid modes are: " . join(', ', @mode_list);
}

my $hr = { title => 'Operation Mode', value => $mode };

# Connect and send commands

my $ls30c = LS30Connection->new($opt_h);

$ls30c->Connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c, 5);

my $cmd = LS30Command::setCommand($hr);

my $response = $ls30cmdr->sendCommand($cmd);

if ($response) {
	printf "%-40s | %-15s | %s\n", $hr->{title}, $cmd, $response;
	my $resp_obj = LS30::ResponseMessage->new($response);
	print Data::Dumper::Dumper($resp_obj) if ($resp_obj);
}

exit(0);
