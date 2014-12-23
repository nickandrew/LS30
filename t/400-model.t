#!/usr/bin/perl
#
#  Test LS30::Model

use strict;
use warnings;

use Test::More qw(no_plan);

use LS30Command qw();
use LS30::Model qw();

LS30Command::addCommands();

my $model = LS30::Model->new();
isa_ok($model, 'LS30::Model');

can_ok($model, qw(upstream getSetting setSetting));

my $rc;

$rc = $model->setSetting('Operation Mode', 'Disarm');
ok($rc == 1, "setSetting valid value");

$rc = $model->setSetting('Operation Mode', 'Invalid');
ok(!defined $rc, "setSetting invalid value");

$rc = $model->setSetting('Invalid Setting Name', 'Invalid');
ok(!defined $rc, "setSetting invalid setting name");

my $value;

$value = $model->getSetting('Operation Mode');
ok($value eq 'Disarm', "getSetting Operation Mode");

$value = $model->getSetting('Something invalid');
ok(!defined $value, "getSetting invalid setting name");
