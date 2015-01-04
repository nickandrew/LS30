#!/usr/bin/perl
#
#  Test LS30::Model

use strict;
use warnings;

use Test::More qw(no_plan);
use AnyEvent qw();

use LS30Command qw();
use LS30::Model qw();

LS30Command::addCommands();

my $model = LS30::Model->new();
isa_ok($model, 'LS30::Model');

can_ok($model, qw(upstream getSetting setSetting clearSetting getDeviceCount));

test_settings();
test_getdevicecount();

exit(0);

# ---------------------------------------------------------------------------
# Test getSetting and setSetting
# ---------------------------------------------------------------------------

sub test_settings {
	my ($cv, $rc, $value);

	$cv = $model->setSetting('Operation Mode', 'Disarm');
	isa_ok($cv, 'AnyEvent::CondVar');
	$rc = $cv->recv;
	ok($rc == 1, "setSetting valid value");

	$cv = $model->setSetting('Operation Mode', 'Invalid');
	$rc = $cv->recv;
	ok(!defined $rc, "setSetting invalid value");

	$cv = $model->setSetting('Invalid Setting Name', 'Invalid');
	$rc = $cv->recv;
	ok(!defined $rc, "setSetting invalid setting name");

	# Test first synchronous style
	$cv = $model->getSetting('Operation Mode');
	$value = $cv->recv;
	ok($value eq 'Disarm', "getSetting Operation Mode");

	# Then asynchronous
	$cv = $model->getSetting('Operation Mode');
	$cv->cb(sub {
		$value = $cv->recv;
		ok($value eq 'Disarm', "getSetting Operation Mode asynchronous");
	});

	$cv = $model->getSetting('Something invalid');
	$value = $cv->recv;
	ok(!defined $value, "getSetting invalid setting name");
}

# ---------------------------------------------------------------------------
# Test getDeviceCount
# ---------------------------------------------------------------------------

sub test_getdevicecount {

	my $cv = $model->getDeviceCount('Burglar Sensor', 1);
	my $value = $cv->recv();
	ok($value == 0, "Returned device count is $value");

	my $cv = $model->getDeviceCount('Invalid', 1);
	my $value = $cv->recv();
	ok(!defined $value, "Returned device count for invalid device is undef");
}
