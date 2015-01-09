#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30::DeviceSet - A set of known devices

=head1 DESCRIPTION

This class stores all known devices in a YAML file. It reads the file
on instantiation and can find a device by its 6-digit hex code.

=head1 METHODS

=over

=cut

package LS30::DeviceSet;

use strict;
use warnings;

use YAML qw();


# ---------------------------------------------------------------------------

=item I<new($device_file)>

Construct a new LS30::DeviceSet, read the list of devices from a YAML
file and return the newly constructed object.

$device_file is an optional argument. If not supplied, the filename is
taken from environment variable LS30_DEVICES.

=cut

sub new {
	my ($class, $device_file) = @_;

	if (!$device_file) {
		$device_file = $ENV{'LS30_DEVICES'};

		if (!$device_file) {
			die "Environment LS30_DEVICES must be set to a filename";
		}
	}

	my $data;

	if (!-f $device_file) {
		$data = {};
	} else {
		$data = YAML::LoadFile($device_file);
	}

	my $self = {
		device_file => $device_file,
		devices     => $data,
	};

	bless $self, $class;

	return $self;
}


# ---------------------------------------------------------------------------

=item I<saveDevices()>

Write the known devices to the device_file in YAML format.

=cut

sub saveDevices {
	my ($self) = @_;

	my $device_file = $self->{device_file};

	if (!open(LS30_DEVICES, '>', $device_file)) {
		die "Unable to open $device_file for write - $!";
	}

	if (!print LS30_DEVICES YAML::Dump($self->{devices})) {
		die "Unable to write empty device file - $!";
	}

	if (!close(LS30_DEVICES)) {
		die "Unable to close device file - $!";
	}

}


# ---------------------------------------------------------------------------

=item I<findDeviceByCode($device_code)>

Find the specified device in our device set, and return a reference
to it. The reference is expected to be blessed into the class LS30::Device.

The device code is a 6-digit hex string which specifies the 24-bit unique
device code.

If there's no such device, return undef.

=cut

sub findDeviceByCode {
	my ($self, $device_code) = @_;

	return $self->{devices}->{$device_code};
}

=back

=cut

1;
