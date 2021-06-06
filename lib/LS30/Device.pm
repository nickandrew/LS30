#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30::Device - Representation of a device (sensor, etc)

=head1 DESCRIPTION

An instance of this class represents one device. Devices are one of the
following types:

  - Burglar Sensor
  - Controller (including Keypad and Key Fob remote)
  - Fire Sensor
  - Medical Sensor
  - Special Sensor

=head1 METHODS

=over

=cut

package LS30::Device;

use strict;
use warnings;


# ---------------------------------------------------------------------------

=item I<new()>

Return a new, blank instance of this class.

=cut

sub new {
	my ($class, $device_class) = @_;

	my $self = {
		device_class => $device_class,
		index     => undef,
		type      => undef,
		zone      => undef,
		id        => undef,
		device_id => undef,
		name      => undef,
		config    => {},
		events    => [],
		state     => {},
		commander => undef,
	};

	bless $self, $class;
	return $self;
}


# ---------------------------------------------------------------------------

=item I<newFromResponse($response_obj)>

Return a new instance of this class, initialised from a 'kb' ('kf', 'kc', etc)
response or an 'ib' ('if', 'ic', etc) response.

=cut

sub newFromResponse {
	my ($class, $resp_obj, $device_class, $device_index) = @_;

	my $self = $class->new($device_class);
	$self->{index} = $device_index;

	my $device_id = $resp_obj->get('device_id');
	return undef if ($device_id eq '000000');

	foreach my $key (qw(type zone id device_id)) {
		my $v = $resp_obj->get($key);
		if (defined $v) {
			$self->{$key} = $v;
		}
	}

	# Config is a hex-encoded bitmap
	my $config = $resp_obj->get('config');

	if ($config) {
		$self->{config} = LS30Command::parseDeviceConfig($config);
	}

	return $self;
}

# ---------------------------------------------------------------------------

=item I<commander($commander)>

Get/Set the 'commander' (an instance of LS30::Commander)

=cut

sub commander {
	my $self = shift;

	if (scalar @_) {
		$self->{commander} = shift;
	}

	return $self->{commander};
}

# ---------------------------------------------------------------------------

=item I<device_id($device_id)>

Get/Set 6-char device id (hex).

=cut

sub device_id {
	my $self = shift;

	if (scalar @_) {
		$self->{device_id} = shift;
		return $self;
	}

	return $self->{device_id};
}

=back

=cut

1;
