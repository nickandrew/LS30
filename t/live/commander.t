#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Test LS30::Commander

use Test::More qw(no_plan);
use Data::Dumper qw(Dumper);

use LS30Command qw();
use LS30Connection qw();
use LS30::Commander qw();

LS30Command::addCommands();

my $ls30c = LS30Connection->new();

$ls30c->connect();
my $ls30cmdr = LS30::Commander->new($ls30c, 5);

isa_ok($ls30cmdr, 'LS30::Commander');

my ($cv, $cmd, $value);

# ---------------------------------------------------------------------------
# Test queueCommand
# ---------------------------------------------------------------------------

$cmd = '!n0?&';
$cv = $ls30cmdr->queueCommand($cmd);

isa_ok($cv, 'AnyEvent::CondVar');

$value = $cv->recv();
ok($value =~ /^!n0[012]&$/, "queueCommand response \"$value\"");

# ---------------------------------------------------------------------------
# Test sendCommand (synchronous version of queueCommand)
# ---------------------------------------------------------------------------

my $value2 = $ls30cmdr->sendCommand($cmd);
ok($value2 =~ /^!n0[012]&$/, "sendCommand response \"$value\"");

# ---------------------------------------------------------------------------
# Test setSetting
# ---------------------------------------------------------------------------

my $rc;

$cv = $ls30cmdr->setSetting('Operation Mode', 'Disarm');
isa_ok($cv, 'AnyEvent::CondVar');
$rc = $cv->recv;
ok($rc == 1, "setSetting Operation Mode to Disarm");

# ---------------------------------------------------------------------------
# Test getSetting
# ---------------------------------------------------------------------------

# Test first synchronous style
$cv = $ls30cmdr->getSetting('Operation Mode');
$value = $cv->recv;
ok($value eq 'Disarm', "getSetting Operation Mode");

# Then asynchronous
my $cv2 = $ls30cmdr->getSetting('Operation Mode');
$cv2->cb(sub {
	my $value = $cv2->recv;
	ok($value eq 'Disarm', "getSetting Operation Mode asynchronous");
});

$cv = $ls30cmdr->getSetting('Something invalid');
$value = $cv->recv;
ok(!defined $value, "getSetting invalid setting name");

test_clearsetting();

test_devices();

exit(0);

# ---------------------------------------------------------------------------
# Test clearSetting
# ---------------------------------------------------------------------------

sub test_clearsetting {
	# First retrieve current setting
	my $setting = 'GSM Phone 2';
	my $new_value = "1234546";

	my $cv = $ls30cmdr->getSetting($setting);
	my $original = $cv->recv();
	pass("Original value of <$setting> was <$original>");

	# Now set it to something
	$cv = $ls30cmdr->setSetting($setting, $new_value);
	my $rc = $cv->recv();
	ok($rc == 1, "return value from setSetting was $rc");

	# Retrieve current value
	$cv = $ls30cmdr->getSetting($setting);
	my $current = $cv->recv();
	ok($current eq $new_value, "Setting changed to $current");

	# And clear it
	$cv = $ls30cmdr->clearSetting($setting);
	$rc = $cv->recv();
	ok($rc == 1, "return value from clearSetting was $rc");

	# Retrieve cleared value
	$cv = $ls30cmdr->getSetting($setting);
	$current = $cv->recv();
	ok($current eq '', "Setting cleared to <$current>");

	# Replace original value
	if (defined $original) {
		$cv = $ls30cmdr->setSetting($setting, $original);
		my $rc = $cv->recv();
		ok($rc == 1, "Original value restored to <$original>");
	}
}

# ---------------------------------------------------------------------------
# Test getDeviceCount and getDeviceStatus
# ---------------------------------------------------------------------------

sub test_devices {
	my $cv = $ls30cmdr->getDeviceCount('Burglar Sensor');
	my $value = $cv->recv;
	ok(defined $value && $value =~ /^\d+$/, "Device Count Burglar Sensor is $value");

	$cv = $ls30cmdr->getDeviceCount('Invalid Device Type');
	my $value2 = $cv->recv;
	ok(!defined $value2, "Device Count for an invalid type returns undef");

	if ($value > 0) {
		# Retrieve one
		my $cv = $ls30cmdr->getDeviceStatus('Burglar Sensor', 0);
		my $obj = $cv->recv();
		isa_ok($obj, 'LS30::Device', "Returned object is a $obj");
	}
}
