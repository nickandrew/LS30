# LS30 control software

	Nick Andrew <nick@nick-andrew.net>
	First release 3rd April, 2010

This package provides control and monitoring for the LS30 alarm system.

The LS30 is an alarm system which uses radio to talk to sensors, sirens
and other devices. It was created by LifeSOS Taiwan, also known as
Scientech Electronics Co, Ltd.

Some URLs for information about the device:

  * http://www.lifesos.com.tw/
  * http://210.68.28.137/WebApps/showproductdetail.html?id=3
  * http://www.securepro.com.au/

The LS30 has many features, including multiple zones, different kinds
of alarm, integrated PSTN dialer and optional GSM dialer. Best though,
is that it has an optional ethernet interface and the system can be
fully monitored and operated through a TCP/IP connection.

This package is the work of Nick Andrew <nick@nick-andrew.net> and is
not associated with LifeSOS or Scientech. All code is licensed under
the GNU General Public License, version 3.

# HOW TO USE

You need the optional ethernet interface. Configure it on your network.
It listens on port 1681 by default. Assume its IP address is A.B.C.D

The PERLLIB environment variable needs to be set, so that perl can find
the modules. PERLLIB is a colon-separated list of pathnames like $PATH.
If PERLLIB is not already set, then do this from the directory into
which you unpacked the code:

	export PERLLIB=./lib

If PERLLIB is already set then add ./lib or $PWD/lib to the current
value.

You should run the proxy daemon (`bin/alarm-daemon.pl`). This daemon
will establish a connection to the LS30 and listen on one or more local
ports for connections from client code. Multiple client connections are
possible at the same time. You will need this if you intend to control
the LS30 while monitoring it, or use two different monitors, etc.

Run the proxy daemon as follows:

	bin/alarm-daemon.pl -h A.B.C.D:1681 127.0.0.1:1681

This establishes a connection to A.B.C.D port 1681 and listens on local
port 1681. The LS30 sends regular event messages. Any event messages
received while no client is connected will be buffered by the proxy daemon
and sent all at once to the first client to connect. That helps to
avoid missing useful messages.

To run client code you should set the address of your proxy daemon in
the environment:

	export LS30_SERVER=127.0.0.1:1681

You can now run scripts:

1. Watch daemon

	bin/watch.pl -c Watch

This will connect and observe all responses from the LS30. It tries to
decode them and print them to standard output.

The types of responses are:

  * Contact ID Event Messages
  * Device Messages
  * Command Responses
  * AT & GSM strings

Contact ID Event Messages are strings in the ContactID protocol. They
contain updates on events (such as arming or disarming) as well as
periodic test reports.

Device Messages are received transmissions from wireless devices (both
registered and unregistered devices). They tell when a device has been
triggered or performs a self-test, when a door sensor opens or closes,
when a remote controller is used and more.

Command Responses are lines which the LS30 sends back in response to
an issued command. Commands start with '!' and end with '&' and
responses are in the same format.

AT & GSM strings are sent by the LS30 when it attempts to communicate
with the GSM dialer.

2. Arm and Disarm the LS30

	bin/arm.pl -m away
	bin/arm.pl -m disarm
	bin/arm.pl -m home
	bin/arm.pl -m monitor

3. Send commands and decode the responses

	bin/send.pl '!n1?&'

4. Make the system safe for trigger testing

	bin/safe-test.pl -y
	bin/safe-test.pl -n

This command sets certain parameters to ensure that if the LS30 is triggered
in away mode, it won't set off the siren(s). Used for testing the LS30 response
to burglary and other situations, especially GSM dialout.

5. List registered devices

	bin/list-devices.pl

6. Get the date and time

	bin/dt.pl

## DEPENDENCIES

All classes and scripts are written in Perl. They use:

  * Data::Dumper
  * Getopt::Std
  * IO::Select
  * IO::Socket
  * Test::More
  * YAML
  * Date::Format
  * Socket6 (for IPv6)
  * IO::Socket::INET6 (for IPv6)

Debian/Ubuntu users install perl modules with names like "lib*-perl", so you
should install the following packages:

  * libio-socket-inet6-perl (for IPv6)
  * libsocket6-perl (for IPv6)
  * libtimedate-perl
  * libyaml-perl
  * perl-modules
