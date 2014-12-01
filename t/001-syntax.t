#!/usr/bin/env perl
#
#   Copyright (C) 2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Syntax-check all modules, scripts and test scripts

use strict;
use warnings;

use Test::More qw(no_plan);

test_dir('bin');
test_dir('lib');
test_dir('perllib');
test_dir('scripts');
test_dir('t');

exit(0);

sub test_dir {
	my ($dir) = @_;

	if (! -d $dir) {
		return;
	}

	if (! opendir(DIR, $dir)) {
		return;
	}

	my @files = sort(grep { ! /^\./ } (readdir DIR));
	closedir(DIR);

	foreach my $f (@files) {
		my $path = "$dir/$f";

		if (-d $path) {
			test_dir($path);
		}
		elsif (-f $path && $f =~ /\.(pl|pm|t)$/) {
			test_file($path);
		}
	}
}

sub test_file {
	my ($path) = @_;

	open(P, "perl -Mstrict -wc $path 2>&1 |");
	my $lines;

	while (<P>) {
		$lines .= $_;
	}

	if (! close(P)) {
		warn "Error closing pipe from perl syntax check $path";
	}

	my $rc = $?;

	if ($rc) {
		diag($lines);
		fail("$path failed - code $rc");
	} else {
		pass($path);
	}
}
