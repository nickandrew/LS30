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

can_ok($model, qw(upstream getSetting setSetting));

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
