#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Execute scripts upon device or event messages

package LS30Client::RunScripts;

use strict;
use warnings;

use ContactID::EventCode qw();
use LS30::DeviceSet qw();
use LS30::Log qw();
use LS30Command qw();
use LS30Connection qw();
use LS30::Decoder qw();
use Timer qw();

# This is the subdirectory where event scripts are placed. Scripts can
# be added and deleted while the daemon is running.

my $event_dir = 'event.d';

# Temporarily this is a class variable as the responder functions don't
# take a $self parameter.
my $devices;

sub new {
	my ($class, $server_address) = @_;

	if (!defined $server_address) {
		$server_address = $ENV{'LS30_SERVER'};
	}

	my $self = {
		server_address => $server_address,
		ls30c          => LS30Connection->new($server_address),
		pending        => '',
	};

	bless $self, $class;

	my $ls30c = $self->{ls30c};

	$ls30c->onConnectFail(sub {
		LS30::Log::timePrint("RunScripts: Connection to $server_address failed, retrying");
		shift->retryConnect();
	});

	$ls30c->onDisconnect(sub {
		LS30::Log::timePrint("RunScripts: Disconnected from $server_address, retrying");
		shift->retryConnect();
	});

	if (!$ls30c->connect()) {
		die "Unable to connect to server socket";
	}

	if (!$devices) {
		$devices = LS30::DeviceSet->new();
		$self->{devices} = $devices;
	}

	my $decoder = LS30::Decoder->new($self);

	$ls30c->setHandler($decoder);

	return $self;
}

sub addSelector {
	my ($self, $selector) = @_;

	$self->{'select'} = $selector;

	my $timer2 = Timer->new(
		func_ref  => \&disc_timer_event,
		arg_ref   => ["timer2", $self, 0, 1],
		next_time => undef,
	);
	$self->{timer2} = $timer2;
	$selector->addTimer($timer2);

	my $ls30c = $self->{ls30c};
	$selector->addSelect([$ls30c->socket(), $ls30c]);
}

sub disc_timer_event {
	my ($ref, $selector) = @_;

	LS30::Log::timePrint("Disconnected, retrying connect");
	my $self  = $ref->[1];
	my $ls30c = $self->{ls30c};
	my $timer = $self->{timer2};

	if (!$ls30c->connect()) {

		# Backoff try later
		if ($ref->[3] < 64) {
			$ref->[3] *= 2;
		}

		$ref->[2] += $ref->[3];
		LS30::Log::timePrint(sprintf("Connect failed, retry in %d sec", $ref->[3]));
		$timer->setNextTime($ref->[2]);
	} else {
		LS30::Log::timePrint("Connected");

		# Stop the timer
		$timer->stop();

		$self->{'select'}->addSelect([$ls30c->socket(), $ls30c]);
	}
}

# ---------------------------------------------------------------------------
# Run one or more scripts when a device message is received (trigger, test,
# open, close).
# ---------------------------------------------------------------------------

sub handleDeviceMessage {
	my ($self, $devmsg_obj) = @_;

	my $string        = $devmsg_obj->getString();
	my $event_name    = $devmsg_obj->getEventName();
	my $dev_type_name = $devmsg_obj->getDeviceType();
	my $device_id     = $devmsg_obj->getDeviceID();
	my $signal        = $devmsg_obj->getSignalStrength();
	my $unknown       = $devmsg_obj->getUnknown();

	my $ls30c = $self->{ls30c};

	my $device_ref = $self->{devices}->findDeviceByCode($device_id);
	my $device_name;
	my $device_zone = 'Unknown';

	if (!$device_ref) {
		$device_name = 'Unknown';
	} else {
		$device_zone = $device_ref->{'zone'};
		$device_name = $device_ref->{'name'};
	}

	$ENV{DEVICE_NAME}   = $device_name;
	$ENV{DEVICE_ZONE}   = $device_zone;
	$ENV{DEVICE_EVENT}  = $event_name;
	$ENV{DEVICE_TYPE}   = $dev_type_name;
	$ENV{DEVICE_ID}     = $device_id;
	$ENV{DEVICE_SIGNAL} = $signal;
	my $concat = join(' ', $string, $event_name, $dev_type_name, "$device_id $device_name", "signal $signal", ($unknown ? $unknown : ''));
	runCommands('device', $concat);

	foreach my $k (qw(DEVICE_NAME DEVICE_EVENT DEVICE_TYPE DEVICE_ID DEVICE_SIGNAL DEVICE_ZONE)) {
		delete $ENV{$k};
	}
}

# ---------------------------------------------------------------------------
# Run one or more scripts when an event message is received (periodic test
# etc).
# ---------------------------------------------------------------------------

sub handleEventMessage {
	my ($self, $evmsg_obj) = @_;

	my $text = $evmsg_obj->asText();
	LS30::Log::timePrint($text);
	my $description = $evmsg_obj->getDescription();
	my $group       = $evmsg_obj->getGroup();
	my $zone        = $evmsg_obj->getZone();

	$ENV{EVENT_DESCRIPTION} = $description;
	$ENV{EVENT_GROUP}       = $group;
	$ENV{EVENT_ZONE}        = $zone;
	runCommands('event', $text);
	delete $ENV{EVENT_DESCRIPTION};
	delete $ENV{EVENT_GROUP};
	delete $ENV{EVENT_ZONE};
}

# ---------------------------------------------------------------------------
# Run all scripts in $event_dir where the script name begins with $file_prefix.
# The specified $message is the command line passed to the script.
# ---------------------------------------------------------------------------

sub runCommands {
	my ($file_prefix, $message) = @_;

	if (!-d $event_dir) {

		# Cannot run anything
		return;
	}

	if (!opendir(DIR, $event_dir)) {
		warn "Unable to opendir $event_dir - $!";
		return;
	}

	my @files = sort(readdir DIR);

	foreach my $f (@files) {
		next if ($f =~ /^\./);

		next if ($f !~ /^$file_prefix/);

		my $path = "$event_dir/$f";

		my @buf = stat($path);
		next if (!-f _ || !-r _ || !-x _);

		my $rc = system($path, $message);

		if ($rc) {
			print "system($path, $message) rc is $rc\n";
		}
	}
}

sub handleResponse {
	my ($self, $line) = @_;

	my $resp_hr = LS30Command::parseResponse($line);

	if (!$resp_hr) {
		LS30::Log::timePrint("Received unexpected response $line");
		return;
	}

	my $s = sprintf("Response: %s (%s)", $resp_hr->{title}, $resp_hr->{value});
	LS30::Log::timePrint($s);
}

sub handleResponseMessage {
	my ($self, $response_obj) = @_;

	if (!$response_obj) {
		LS30::Log::timePrint("Received unexpected response");
		return;
	}

	if ($response_obj->{error}) {
		my $s = sprintf("Response: ", $response_obj->{error});
		LS30::Log::timePrint($s);
	} else {
		my $value = $response_obj->{value};
		$value = '' if (!defined $value);
		my $title = $response_obj->{title} || 'Unknown';
		my $s = sprintf("Response: %s (%s)", $title, $value);
		LS30::Log::timePrint($s);
	}
}

sub handleAT {
	my ($self, $line) = @_;

	LS30::Log::timePrint("Ignoring AT: $line");
}

sub handleGSM {
	my ($self, $line) = @_;

	LS30::Log::timePrint("Ignoring GSM: $line");
}

1;
