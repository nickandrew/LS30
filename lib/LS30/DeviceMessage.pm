#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30::DeviceMessage - A message from or about a device

=head1 DESCRIPTION

This class parses the most frequent message type used by the LS30.
It looks like these two examples:

  MINPIC=0a201912345600305e6473
  XINPIC=0a204012345600108b6473

'MINPIC' is used for a known device, 'XINPIC' for an unknown device.

The objects of this class represent the above strings decoded.

=head1 METHODS

=over

=cut

package LS30::DeviceMessage;

use strict;

use Carp qw(confess);

my $device_type_map = {
	'50' => 'PIR',
	'70' => 'Siren',
	'10' => 'Remote Control',
	'19' => 'Keypad',
	'20' => 'Smoke Detector',
	'40' => 'Door Switch',
};

my $event_code_map = {
	'0a10' => 'Away mode',
	'0a13' => 'Check Status',
	'0a14' => 'Disarm mode',
	'0a18' => 'Home mode',
	'0a20' => 'Test',
	'0a40' => 'Open',
	'0a48' => 'Close',
	'0a50' => 'Tamper',
	'0a58' => 'Trigger',
	'0a60' => 'Panic',
};


# ---------------------------------------------------------------------------

=item new($string)

Parse $string and return a new LS30::DeviceMessage.

If string is not supplied, return an empty object.

=cut

sub new {
	my ($class, $string) = @_;

	my $self = { };
	bless $self, $class;

	if ($string) {
		$self->_parseString($string);
	}

	return $self;
}


# ---------------------------------------------------------------------------

=item _parseString($string)

Parse the string and update $self.

=cut

sub _parseString {
	my ($self, $string) = @_;

	if ($string !~ m/^(....)(..)(......)(....)(..)(..)(..)$/) {
		$self->{error} = "Invalid DeviceMessage string: $string";
		return;
	}

	my ($type, $dev_type, $device_id, $unk1, $signal, $unk2, $unk3) = ($1, $2, $3, $4, $5, $6, $7);

	my $unknown = '';

	my $signal_int = hex($signal) - 32;
	my $type_name = $event_code_map->{$type};

	if (! $type_name) {
		$type_name = 'Unknown';
		$unknown .= " UnknownType($type)";
	}

	my $dev_type_name = $device_type_map->{$dev_type} || 'Unknown';

	if ($unk1 !~ /^(0000|0010|0030|0130)$/) {
		$unknown .= " unk1($unk1)";
	}

	my $unk2_value = hex($unk2);
	if ($unk2_value < 94 || $unk2_value > 101) {
		$unknown .= " unk2($unk2_value)";
	}

	if ($unk3 !~ /^73$/) {
		$unknown .= " unk3($unk3)";
	}

	if ($unknown) {
		$self->{unknown} = $unknown;
	}

	$self->{string} = $string;
	$self->{event_code} = $type;
	$self->{event_name} = $type_name;
	$self->{device_id} = $device_id;
	$self->{device_type} = $dev_type_name;
	$self->{signal_strength} = $signal_int;
	$self->{unk1} = $unk1;
	$self->{unk2} = $unk2;
	$self->{unk3} = $unk3;
}

sub getEventName {
	my ($self) = @_;

	return $self->{event_name};
}

sub getDeviceID {
	my ($self) = @_;

	return $self->{device_id};
}

sub getDeviceType {
	my ($self) = @_;

	return $self->{device_type};
}

sub getSignalStrength {
	my ($self) = @_;

	return $self->{signal_strength};
}

sub getString {
	my ($self) = @_;

	return $self->{string};
}

sub getUnknown {
	my ($self) = @_;

	return $self->{unknown};
}

1;
