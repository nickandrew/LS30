#!/usr/bin/env perl
#   Copyright (C) 2010-2016, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Print current operating mode: "Disarm", "Home", "Monitor" or "Away"

use strict;
use warnings;

use Getopt::Std qw(getopts);

use LS30Command qw();
use LS30Connection qw();
use LS30::Commander qw();
use LS30::ResponseMessage qw();

use vars qw($opt_h);

getopts('h:');

LS30Command::addCommands();

my $ls30c = LS30Connection->new($opt_h, reconnect => 1);

if (!$ls30c->connect()) {
	warn "Unable to connect!";
}

my $ls30cmdr = LS30::Commander->new($ls30c, 5);
my @output;

my $cmd_ref = { title => 'Operation Mode', };

my $cmd      = LS30Command::queryCommand($cmd_ref);
my $response = $ls30cmdr->sendCommand($cmd, 5);

if (!$response) {
	die "No response received\n";
}

my $resp_obj = LS30::ResponseMessage->new($response);

if ($resp_obj) {
	printf "%s\n", $resp_obj->get('value');
} else {
	print "Unknown\n";
}

exit(0);
