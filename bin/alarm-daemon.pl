#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#  Act as a proxy, logging all comms to and from a remote host/port
#
#  Usage: alarm-daemon.pl [-h host:port] listen_addr ...
#
#  -h host:port  Connect to specified port
#
#  listen_addr   A set of one or more listening addresses.
#                Format:  host:port
#                ipv4:    0.0.0.0:1681
#                ipv4:    127.0.0.1:1681
#                ipv6:    :::1681
#                ipv6:    [::]:1681
#
#  All I/O to/from the remote host is logged.

use strict;

use Getopt::Std qw(getopts);
use IO::Select qw();

use AlarmDaemon::Controller qw();
use AlarmDaemon::SocketFactory qw();
use LS30::Log qw();

use vars qw($opt_h);

$| = 1;
getopts('h:');

$opt_h || die "Need option -h host:port";

$SIG{'INT'} = sub {
	LS30::Log::timePrint("SIGINT received, exiting");
	exit(4);
};

$SIG{'PIPE'} = sub {
	LS30::Log::timePrint("SIGPIPE received, exiting");
	exit(4);
};

my $ac = AlarmDaemon::Controller->new();

$ac->addServer($opt_h);

foreach my $local_addr (@ARGV) {
	my $listener = AlarmDaemon::SocketFactory->new(
		LocalAddr => $local_addr,
		Proto => "tcp",
		ReuseAddr => 1,
		Listen => 5,
	);

	if ($listener) {
		LS30::Log::timePrint("Listening on $local_addr");
		$ac->addListener($listener);
	}
}

$ac->eventLoop();
exit(0);
