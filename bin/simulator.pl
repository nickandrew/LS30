#!/usr/bin/env perl
#   Copyright (C) 2010-2016, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#  LS30 simulator.
#  Intended to be a server which both listens on one or more addresses
#  and connects out to remote clients. Not a proxy. Settings are emulated
#  and stored in YAML.
#
#  Usage: simulator.pl --settings settings.yaml [-l listen_addr] [-c host:port] ...
#
#  -c host:port  Connect to specified port
#
#  listen_addr   A listening address.
#                Format:  host:port
#                ipv4:    0.0.0.0:1681
#                ipv4:    127.0.0.1:1681
#                ipv6:    :::1681
#                ipv6:    [::]:1681
#
#  All I/O to/from the remote host is logged.

use strict;
use warnings;

use Getopt::Long qw(GetOptions);

use AlarmDaemon::Simulator qw();
use AlarmDaemon::SocketFactory qw();
use LS30::Log qw();

my @listen_addrs;
my @connect_addrs;
my $settings_file;

$| = 1;
GetOptions(
	'l=s' => \@listen_addrs,
	'c=s' => \@connect_addrs,
	'settings=s' => \$settings_file,
);

if (!@listen_addrs && !@connect_addrs) {
	die "Need to listen or connect to at least one address";
}

$SIG{'INT'} = sub {
	LS30::Log::timePrint("SIGINT received, exiting");
	exit(4);
};

$SIG{'PIPE'} = sub {
	LS30::Log::timePrint("SIGPIPE received, exiting");
	exit(4);
};

my $as = AlarmDaemon::Simulator->new();

if ($settings_file) {
	$as->settingsFile($settings_file);
}

# $ac->addServer($opt_h);

foreach my $local_addr (@listen_addrs) {
	my $listener = AlarmDaemon::SocketFactory->new(
		LocalAddr => $local_addr,
		Proto     => "tcp",
		ReuseAddr => 1,
		Listen    => 5,
	);

	if ($listener) {
		LS30::Log::timePrint("Listening on $local_addr");
		$as->addListener($listener);
	}
}

# TODO: Make all outbound connections

foreach my $peer_addr (@connect_addrs) {
	LS30::Log::timePrint("Adding remote client: $peer_addr");
	$as->addRemoteClient($peer_addr);
}

$as->eventLoop();

exit(0);
