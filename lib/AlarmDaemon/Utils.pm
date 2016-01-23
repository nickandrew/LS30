#!/usr/bin/env perl
#   Copyright (C) 2010-2016, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

use strict;
use warnings;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(_onfunc _runonfunc _defineonfunc);

# ---------------------------------------------------------------------------
# Set/Get and/or run a function
# ---------------------------------------------------------------------------

sub _onfunc {
	my $self = shift;
	my $name = shift;

	if (scalar @_) {
		$self->{on_func}->{$name} = shift;
		return $self;
	}

	return $self->{on_func}->{$name};
}

sub _runonfunc {
	my $self = shift;
	my $name = shift;

	my $sub = $self->{on_func}->{$name};
	if (defined $sub) {
		$sub->(@_);
	}
}

# _defineonfunc('Fred') creates a method $self->onFred(...)

sub _defineonfunc {
	my ($self, $name) = @_;

	no strict 'refs';
	my $package = ref($self) || $self;
	*{"${package}::on${name}"} = sub { return shift->_onfunc($name, @_); };
}

1;
