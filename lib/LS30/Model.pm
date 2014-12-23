#!/usr/bin/perl -w
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30::Model - A representation of an LS30 alarm system

=head1 SYNOPSIS

#   my $model = LS30::Model->new();
#   my $current_mode = $model->getSetting('Operation Mode');
#   $model->setSetting('Operation Mode', 'Arm');

=head1 DESCRIPTION

This class models the internal state of an LS30 alarm system.

=head1 METHODS

=over

=cut

package LS30::Model;

use strict;
use warnings;

=item I<new()>

Return a new instance of this class.

=cut

sub new {
	my ($class) = @_;

	my $self = {
		settings => {},
		devices => {},
	};

	bless $self, $class;

	return $self;
}

=item I<upstream($upstream)>

If $upstream is provided, then set the upstream object and return $self,
else return the upstream object.

=cut

sub upstream {
	my $self = shift;

	if (scalar @_) {
		$self->{upstream} = shift;
		return $self;
	}

	return $self->{upstream};
}

# ---------------------------------------------------------------------------
# Get or set a named setting
# ---------------------------------------------------------------------------

sub _setting {
	my $self = shift;
	my $setting_name = shift;

	if (scalar @_) {
		$self->{settings}->{$setting_name} = shift;
	}

	return $self->{settings}->{$setting_name};
}

=item I<getSetting($setting_name, $cached)>

Return the current value of $setting_name (which is defined in LS30Command).

If $cached is set, a cached one may be returned, otherwise upstream is
queried and the value is cached.

=cut

sub getSetting {
	my ($self, $setting_name, $cached) = @_;

	my $hr = LS30Command::getCommand($setting_name);
	if (!defined $hr || !$hr->{is_setting}) {
		print STDERR "Is not a setting: <$setting_name>\n";
		return undef;
	}

	my $key = $hr->{key};
	my $value = $self->_setting($setting_name);

	if ($cached && defined $value) {
		return $value;
	}

	my $upstream = $self->upstream();

	if ($upstream) {
		$value = $upstream->getSetting($setting_name, $cached);
		$self->_setting($setting_name, $value);
		return $value;
	}

	if (defined $value) {
		return $value;
	}

	# TODO Return a default value.
	return undef;
}

=item I<setSetting($setting_name, $value)>

Set a new value for $setting_name (which is defined in LS30Command).

If an upstream is set, the value is always propagated to upstream.

Return undef if there was some problem, 1 otherwise.

=cut

sub setSetting {
	my ($self, $setting_name, $value) = @_;

	my $hr = LS30Command::getCommand($setting_name);
	if (!defined $hr || !$hr->{is_setting}) {
		warn "Is not a setting: <$setting_name>\n";
		return undef;
	}

	my $raw_value = LS30Command::testSettingValue($setting_name, $value);
	if (!defined $raw_value) {
		warn "Value <$value> is not valid for setting <$setting_name>\n";
		return undef;
	}

	my $key = $hr->{key};

	my $upstream = $self->upstream();

	if ($upstream) {
		$upstream->setSetting($setting_name, $value);
	}

	$self->_setting($setting_name, $value);
	return 1;
}

1;
