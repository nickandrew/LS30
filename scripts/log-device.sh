#!/bin/bash

while true ; do
	bin/watch.pl -c LS30Client::LogDeviceMessage data/device.log
	sleep 10
done
