#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   ContactID protocol - event codes

=head1 NAME

ContactID::EventCode - List of event codes

=head1 SYNOPSIS

This class maps 3-character event codes used in the Ademco Contact ID protocol
into corresponding short English descriptions.

    $description = ContactID::EventCode::eventDescription('301');
    # Return value is "AC Loss"

=head1 METHODS

=over

=cut

package ContactID::EventCode;

use strict;

# Event codes come from DC-05 "Digital Communication Standard - Ademco Contact ID Protocol"
# Document is at http://www.smartelectron.ru/files/DC-05_Contact_ID.pdf

my $event_codes = {
	'100' => 'Medical Alarm',
	'101' => 'Personal Emergency',
	'102' => 'Fail to report in',

	'110' => 'Fire',
	'111' => 'Smoke',
	'112' => 'Combustion',
	'113' => 'Water flow',
	'114' => 'Heat',
	'115' => 'Pull Station',
	'116' => 'Duct',
	'117' => 'Flame',
	'118' => 'Near Alarm',

	'120' => 'Panic',
	'121' => 'Duress',
	'122' => 'Silent',
	'123' => 'Audible',
	'124' => 'Duress - Access granted',
	'125' => 'Duress - Egress granted',

	'130' => 'Burglary',
	'131' => 'Perimeter',
	'132' => 'Interior',
	'133' => '24 Hour (Safe)',
	'134' => 'Entry/Exit',
	'135' => 'Day/night',
	'136' => 'Outdoor',
	'137' => 'Tamper',
	'138' => 'Near alarm',
	'139' => 'Intrusion Verifier',

	'140' => 'General Alarm',
	'141' => 'Polling loop open',
	'142' => 'Polling loop short',
	'143' => 'Expansion module failure',
	'144' => 'Sensor tamper',
	'145' => 'Expansion module tamper',
	'146' => 'Silent Burglary',
	'147' => 'Sensor Supervision Failure',

	'150' => '24 Hour Non-Burglary',
	'151' => 'Gas detected',
	'152' => 'Refrigeration',
	'153' => 'Loss of heat',
	'154' => 'Water Leakage',
	'155' => 'Foil Break',
	'156' => 'Day Trouble',
	'157' => 'Low bottled gas level',
	'158' => 'High temp',
	'159' => 'Low temp',
	'161' => 'Loss of air flow',
	'162' => 'Carbon Monoxide detected',
	'163' => 'Tank level',

	'200' => 'Fire Supervisory',
	'201' => 'Low water pressure',
	'202' => 'Low CO2',
	'203' => 'Gate valve sensor',
	'204' => 'Low water level',
	'205' => 'Pump activated',
	'206' => 'Pump failure',

	'300' => 'System Trouble',
	'301' => 'AC Loss',
	'302' => 'Low system battery',
	'303' => 'RAM Checksum bad',
	'304' => 'ROM checksum bad',
	'305' => 'System reset',
	'306' => 'Panel programming changed',
	'307' => 'Self-test failure',
	'308' => 'System shutdown',
	'309' => 'Battery test failure',
	'310' => 'Ground fault',
	'311' => 'Battery Missing/Dead',
	'312' => 'Power Supply Overcurrent',
	'313' => 'Engineer Reset',

	'320' => 'Sounder/Relay',
	'321' => 'Bell 1',
	'322' => 'Bell 2',
	'323' => 'Alarm relay',
	'324' => 'Trouble relay',
	'325' => 'Reversing relay',
	'326' => 'Notification Appliance Ckt. #3',
	'327' => 'Notification Appliance Ckt. #4',

	'330' => 'System Peripheral trouble',
	'331' => 'Polling loop open',
	'332' => 'Polling loop short',
	'333' => 'Expansion module failure',
	'334' => 'Repeater failure',
	'335' => 'Local printer out of paper',
	'336' => 'Local printer failure',
	'337' => 'Exp. Module DC Loss',
	'338' => 'Exp. Module Low Batt.',
	'339' => 'Exp. Module Reset',
	'341' => 'Exp. Module Tamper',
	'342' => 'Exp. Module AC Loss',
	'343' => 'Exp. Module self-test fail',
	'344' => 'RF Receiver Jam Detect',

	'350' => 'Communication trouble',
	'351' => 'Telco 1 fault',
	'352' => 'Telco 2 fault',
	'353' => 'Long Range Radio xmitter fault',
	'354' => 'Failure to communicate event',
	'355' => 'Loss of Radio supervision',
	'356' => 'Loss of central polling',
	'357' => 'Long Range Radio VSWR problem',

	'370' => 'Protection loop',
	'371' => 'Protection loop open',
	'372' => 'Protection loop short',
	'373' => 'Fire trouble',
	'374' => 'Exit error alarm (zone)',
	'375' => 'Panic zone trouble',
	'376' => 'Hold-up zone trouble',
	'377' => 'Swinger Trouble',
	'378' => 'Cross-zone Trouble',

	'380' => 'Sensor trouble',
	'381' => 'Loss of supervision - RF',
	'382' => 'Loss of supervision - RPM',
	'383' => 'Sensor tamper',
	'384' => 'RF low battery',
	'385' => 'Smoke detector Hi sensitivity',
	'386' => 'Smoke detector Low sensitivity',
	'387' => 'Intrusion detector Hi sensitivity',
	'388' => 'Intrusion detector Low sensitivity',
	'389' => 'Sensor self-test failure',
	'391' => 'Sensor Watch trouble',
	'392' => 'Drift Compensation Error',
	'393' => 'Maintenance Alert',

	'400' => 'Open/Close',
	'401' => 'O/C by user',
	'402' => 'Group O/C',
	'403' => 'Automatic O/C',
	'404' => 'Late to O/C', # (Note: use 453, 454 instead)
	'405' => 'Deferred O/C', # (Obsolete - do not use)
	'406' => 'Cancel',
	'407' => 'Remote arm/disarm',
	'408' => 'Quick arm',
	'409' => 'Keyswitch O/C',

	'411' => 'Callback request made',
	'412' => 'Successful download/access',
	'413' => 'Unsuccessful access',
	'414' => 'System shutdown command received',
	'415' => 'Dialer shutdown command received',
	'416' => 'Successful Upload',

	'421' => 'Access denied',
	'422' => 'Access report by user',
	'423' => 'Forced Access',
	'424' => 'Egress Denied',
	'425' => 'Egress Granted',
	'426' => 'Access Door propped open',
	'427' => 'Access point Door Status Monitor trouble',
	'428' => 'Access point Request To Exit trouble',
	'429' => 'Access program mode entry',
	'430' => 'Access program mode exit',
	'431' => 'Access threat level change',
	'432' => 'Access relay/trigger fail',
	'433' => 'Access RTE shunt',
	'434' => 'Access DSM shunt',

	'441' => 'Armed STAY',
	'442' => 'Keyswitch Armed STAY',

	'450' => 'Exception O/C',
	'451' => 'Early O/C',
	'452' => 'Late O/C',
	'453' => 'Failed to Open',
	'454' => 'Failed to Close',
	'455' => 'Auto-arm Failed',
	'456' => 'Partial Arm',
	'457' => 'Exit Error (user)',
	'458' => 'User on Premises',
	'459' => 'Recent Close',
	'461' => 'Wrong Code Entry',
	'462' => 'Legal Code Entry',
	'463' => 'Re-arm after Alarm',
	'464' => 'Auto-arm Time Extended',
	'465' => 'Panic Alarm Reset',
	'466' => 'Service On/Off Premises',

	'501' => 'Access reader disable',

	'520' => 'Sounder/Relay Disable',
	'521' => 'Bell 1 disable',
	'522' => 'Bell 2 disable',
	'523' => 'Alarm relay disable',
	'524' => 'Trouble relay disable',
	'525' => 'Reversing relay disable',
	'526' => 'Notification Appliance Ckt #3 disable',
	'527' => 'Notification Appliance Ckt #4 disable',

	'531' => 'Module Added',
	'532' => 'Module Removed',

	'551' => 'Dialer disabled',
	'552' => 'Radio transmitter disabled',
	'553' => 'Remote Upload/Download disabled',

	'570' => 'Zone/Sensor bypass',
	'571' => 'Fire bypass',
	'572' => '24 Hour zone bypass',
	'573' => 'Burg. Bypass',
	'574' => 'Group bypass',
	'575' => 'Swinger bypass',
	'576' => 'Access zone shunt',
	'577' => 'Access point bypass',

	'601' => 'Manual trigger test report',
	'602' => 'Periodic test report',
	'603' => 'Periodic RF transmission',
	'604' => 'Fire test',
	'605' => 'Status report to follow',
	'606' => 'Listen-in to follow',
	'607' => 'Walk test mode',
	'608' => 'Periodic test - System Trouble Present',
	'609' => 'Video Xmitter active',

	'611' => 'Point tested OK',
	'612' => 'Point not tested',
	'613' => 'Intrusion Zone Walk Tested',
	'614' => 'Fire Zone Walk Tested',
	'615' => 'Panic Zone Walk Tested',
	'616' => 'Service Request',

	'621' => 'Event Log reset',
	'622' => 'Event Log 50% full',
	'623' => 'Event Log 90% full',
	'624' => 'Event Log overflow',
	'625' => 'Time/Date reset',
	'626' => 'Time/Date inaccurate',
	'627' => 'Program mode entry',
	'628' => 'Program mode exit',
	'629' => '32 Hour Event log marker',

	'630' => 'Schedule change',
	'631' => 'Exception schedule change',
	'632' => 'Access schedule change',

	'641' => 'Senior Watch Trouble',
	'642' => 'Latch-Key Supervision',

	'651' => 'Reserved for Ademco Use',
	'652' => 'Reserved for Ademco Use',
	'653' => 'Reserved for Ademco Use',
	'654' => 'System Inactivity',
};


# ---------------------------------------------------------------------------

=item eventDescription($code)

Return the short description of the specified 3-digit code number. If the
code is not known, return the empty string.

=cut

sub eventDescription {
	my ($code) = @_;

	return $event_codes->{$code} || '';
}

1;