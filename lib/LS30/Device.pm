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

=item I<configDelay($enable)>

Get/Set the 'delay' bit in the device configuration.

=cut

sub configDelay {
	my $self = shift;

	if (scalar @_) {
		$self->{config}->{delay} = shift;
	}

	return $self->{config}->{delay};
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

# ---------------------------------------------------------------------------

=item I<setZoneId($zone, $id)>

Modifies the device's zone and/or id fields. Duplicate (zone,id) tuples are
not permitted, so the new values are checked before applying them.

Returns a condvar.

=cut

sub setZoneId {
	my ($self, $zone, $id) = @_;

	my $cv = AnyEvent->condvar;

	if ($self->{commander}) {
		my $cmdr = $self->{commander};

		my $args = {
			title => 'Information ' . $self->{device_class},
			zone  => $zone,
			id    => $id,
		};

		my $cmd = LS30Command::queryCommand($args);
		print "Query command: $cmd\n";
		my $cv1 = $cmdr->queueCommand($cmd);

		$cv1->cb(sub {
			my $response = $cv1->recv();
			my $resp = LS30Command::parseResponse($response);

			if ($resp->{'device_id'}) {
				print "Zone $zone id $id is already in use.\n";
				$cv->send(undef);
				return;
			}

			print "Zone $zone id $id is free.\n";

			my $args2 = {
				type  => $self->{device_class},
				index => $self->{index},
				zone  => $zone,
				id    => $id,
			};

			my $cmd2 = LS30Command::formatDeviceModifyCommand($args2);
			print "Modify command: <$cmd2>\n";
			my $cv2 = $cmdr->queueCommand($cmd2);

			$cv2->cb(sub {
				my $response = $cv1->recv();
				printf("Response was: %s\n", $response);
				$cv->send(1);
			})
		});

	} else {
		print "Nothing to do.\n";
		$cv->send(1);
	}

	return $cv;
}

=back

=cut

1;
