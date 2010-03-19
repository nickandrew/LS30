#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#  Alarm watching daemon

package Watch;

use strict;

use Data::Dumper qw(Dumper);

use ContactID::EventCode qw();
use LS30::DeviceSet qw();
use LS30::Log qw();
use LS30Command qw();
use LS30Connection qw();

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
		ls30c => LS30Connection->new($server_address),
		pending => '',
	};

	bless $self, $class;

	my $ls30c = $self->{ls30c};
	if (! $ls30c->Connect()) {
		die "Unable to connect to server socket";
	}

	if (! $devices) {
		$devices = LS30::DeviceSet->new();
		$self->{devices} = $devices;
	}

	$ls30c->setHandler($self);

	return $self;
}

sub addSelector {
	my ($self, $selector) = @_;

	my $timer1 = [ \&timer_time, \&timer_event, undef, "timer1" ];
	$self->{timer1} = $timer1;
	$selector->addTimer($timer1);

	my $timer2 = [ \&disc_timer_time, \&disc_timer_event, undef, $self, 0 ];
	$self->{timer2} = $timer2;
	$selector->addTimer($timer2);

	my $ls30c = $self->{ls30c};
	$selector->addSelect( [$ls30c->socket(), \&readReady, $self] );
}

sub timer_time {
	my ($ref) = @_;

	if (! $ref->[2]) {
		# This is our first run
		my $now = time();
		my $dur = int(rand(5)) + 600;
		LS30::Log::timePrint(sprintf("Hello! %s first run, give me %d seconds\n", $ref->[3], $dur));
		$ref->[2] = $now + $dur;
	}

	return $ref->[2];
}

sub timer_event {
	my ($ref) = @_;

	my $now = time();
	my $dur = int(rand(5)) + 600;
	LS30::Log::timePrint(sprintf("Wow, we hit it! Waiting another %d seconds\n", $dur));
	$ref->[2] = $now + $dur;
}

sub disc_timer_time {
	my ($ref) = @_;

	return $ref->[2];
}

sub disc_timer_event {
	my ($ref) = @_;

	my $self = $ref->[3];
	my $ls30c = $self->{ls30c};

	if (! $ls30c->Connect()) {
		# Backoff try later
		if ($ref->[4] < 64) {
			$ref->[4] *= 2;
		}

		$ref->[2] += $ref->[4];
	} else {
		# Stop the timer
		$ref->[2] = undef;
		$self->{'select'}->addSelect( [$ls30c->socket(), \&readReady, $self] );
	}
}

sub disconnect_event {
	my ($self) = @_;

	my $ls30c = $self->{ls30c};
	my $socket = $ls30c->socket();
	$self->{'select'}->removeSelect($socket);
	$ls30c->Disconnect();

	$self->{timer2}->[4] = 4;
	$self->{timer2}->[2] = time() + 4;
}

sub readReady {
	my ($self, $selector, $socket) = @_;

	my $buffer;
	my $n = $socket->recv($buffer, 256);

	if (!defined $n) {
		# Error
		$self->disconnect_event();
	}
	else {
		$n = length($buffer);
		if ($n == 0) {
			# EOF
			$self->disconnect_event();
		}
		else {
			$self->{ls30c}->addBuffer($buffer);
		}
	}
}

sub handleCONTACTID {
	my ($self, $line) = @_;

	$line =~ m/^(....)(..)(.)(...)(..)(...)(.)/;
	my ($acct, $mt, $q, $xyz, $gg, $ccc, $s) = ($1, $2, $3, $4, $5, $6, $7);

	my $unknown = '';
	my $describe = '';

	if ($acct ne '1688') {
		$unknown .= " acct($acct)";
	}

	if ($mt eq '18') {
		$describe .= "Preferred";
	}
	elsif ($mt eq '98') {
		$describe .= "Optional";
	}
	else {
		$unknown .= " mt($mt)";
	}

	if ($q eq '1') {
		$describe .= " New Event/Opening";
	} elsif ($q eq '3') {
		$describe .= " New Restore/Closing";
	} elsif ($q eq '6') {
		$describe .= " Status report";
	} else {
		$unknown .= " q($q)";
	}

	my $event_description = ContactID::EventCode::eventDescription($xyz) || "Unknown code $xyz";

	$describe .= " $event_description";

	$describe .= " group $gg";

	$describe .= " zone $ccc";


	if ($unknown) {
		LS30::Log::timePrint("$line $describe Unknown $unknown");
	} else {
		LS30::Log::timePrint("$line $describe");
	}
}

sub handleMINPIC {
	my ($self, $minpic) = @_;

	$minpic =~ m/^(......)(......)(....)(..)(..)(..)/;
	my ($type, $device_id, $junk2, $signal, $junk3, $junk4) = ($1, $2, $3, $4, $5, $6, $7);

	my $unknown = '';
	my $device_ref = $self->{devices}->findDeviceByCode($device_id);
	my $device_name;

	if (! $device_ref) {
		$unknown .= " NoDevice($device_id)";
		$device_name = 'Unknown';
	} else {
		$device_name = $device_ref->{'zone'} . ' ' . $device_ref->{'name'};
	}

	my $signal_int = hex($signal) - 32;

	if ($type =~ /^0a2(019|050|070)/) {
		LS30::Log::timePrint("$minpic Test $device_name (signal $signal_int)");
	}
	elsif ($type =~ /^0a5019/) {
		LS30::Log::timePrint("$minpic Tamper alert $device_name (signal $signal_int)");
	}
	elsif ($type =~ /^0a5/) {
		LS30::Log::timePrint("$minpic Triggered $device_name (signal $signal_int)");
	}
	elsif ($type =~ /^0a1010/) {
		LS30::Log::timePrint("$minpic Away mode $device_name (signal $signal_int)");
	}
	elsif ($type =~ /^0a1410/) {
		LS30::Log::timePrint("$minpic Disarm mode $device_name (signal $signal_int)");
	}
	elsif ($type =~ /^0a1810/) {
		LS30::Log::timePrint("$minpic Home mode $device_name (signal $signal_int)");
	}
	elsif ($type =~ /^0a40/) {
		$unknown .= " UnknownType($type) Open (signal $signal_int)";
	}
	elsif ($type =~ /^0a48/) {
		$unknown .= " UnknownType($type) Close (signal $signal_int)";
	}
	elsif ($type =~ /^0a60/) {
		LS30::Log::timePrint("$minpic Panic $device_name (signal $signal_int)");
	}
	else {
		$unknown .= " UnknownType($type)";
	}

	if ($junk2 !~ /^(0000|0010|0030|0130)$/) {
		$unknown .= " junk2($junk2)";
	}

	my $junk3_value = hex($junk3);
	if ($junk3_value < 94 || $junk3_value > 101) {
		$unknown .= " junk3($junk3_value)";
	}

	if ($junk4 !~ /^73$/) {
		$unknown .= " junk4($junk4)";
	}

	if ($unknown) {
		LS30::Log::timePrint("$minpic Unknown $unknown");
	}
}

sub handleResponse {
	my ($self, $line) = @_;

	my $resp_hr = LS30Command::parseResponse($line);

	if (! $resp_hr) {
		LS30::Log::timePrint("Received unexpected response $line");
		return;
	}

	my $s = sprintf("Response: %s (%s)", $resp_hr->{title}, $resp_hr->{value});
	LS30::Log::timePrint($s);
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
