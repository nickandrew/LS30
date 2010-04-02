#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Test scripts and module syntax

use Test::More qw(no_plan);

test_dir('lib');
test_dir('bin');

exit(0);

sub test_dir {
	my ($dir) = @_;

	if (! opendir(DIR, $dir)) {
		return;
	}

	my @files = grep { ! /^\./ } readdir(DIR);

	foreach my $f (@files) {
		my $path = "$dir/$f";

		if (-d $path) {
			test_dir($path);
		}
		elsif (-f _ && $f =~ /\.(pl|pm)$/) {
			test_file($path);
		}
	}
}

sub test_file {
	my ($path) = @_;

	open(P, "perl -Mstrict -wc $path 2>&1 |");
	my @diag = <P>;
	close(P);

	my $rc = $?;

	if ($rc) {
		foreach my $line (@diag) {
			diag($line);
		}
		fail("syntax check failed $path, code $rc");
	} else {
		pass("$path OK");
	}
}
