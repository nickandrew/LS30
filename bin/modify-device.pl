#!/usr/bin/env perl
#   Copyright (C) 2010-2016, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Modify a device's settings e.g. zone and id
#
#   Options:
#     --host host:port       Override the server hostname and port
#     --type type            'Burglar Sensor' etc
#     --zone zz:cc           Modify zone and code
#     --id xx-yy             Specify id xx:yy

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Getopt::Long qw(GetOptions);
use YAML qw();

use LS30::Commander qw();
use LS30::Type qw();
use LS30Command qw();
use LS30Connection qw();

my $opt_host;
my $opt_type;
my $opt_zone;
my $opt_id;

GetOptions(
	'host=s' => \$opt_host,
	'id=s'   => \$opt_id,
	'type=s' => \$opt_type,
	'zone=s' => \$opt_zone,
);

my $devices_file = "etc/devices.yaml";

my $ls30c = LS30Connection->new($opt_host);

$ls30c->connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c);

if ($opt_id !~ /^([0-9a-f][0-9a-f])-([0-9a-f][0-9a-f])$/) {
	die "Invalid format id (need xx-xx)";
}

my ($zone, $id) = ($1, $2);


my $cv = $ls30cmdr->getDeviceByZoneId($opt_type, $zone, $id);
my $device = $cv->recv();

if (!$device) {
	die "No such device $opt_type $zone $id";
}

$device->commander($ls30cmdr);

if ($opt_zone) {
	if ($opt_zone !~ /^([0-9a-f][0-9a-f])-([0-9a-f][0-9a-f])$/) {
		die "Invalid format zone (need xx-xx)";
	}

	my ($zone, $id) = ($1, $2);

	my $cv = $device->setZoneId($zone, $id);
	my $result = $cv->recv();
	printf("Zone set to %s-%s result %s\n", $zone, $id, $result || 'failed');
}

exit(0);
