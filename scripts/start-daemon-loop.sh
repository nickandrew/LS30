#!/bin/bash
#  Start and loop running the alarm daemon

export LS30_SERVER='[::]:1681'
export LS30_DEVICES=etc/devices.yaml
export PERLLIB=lib

cd ~/GIT/Priv/Src/Misc/Alarm-Control

while true ; do
	echo $(date) Starting alarm daemon to listen on $LS30_SERVER >> tmp/daemon.out
	bin/alarm-daemon.pl -h 10.0.0.102:1681 $LS30_SERVER >> tmp/daemon.out 2>>tmp/daemon.err
	sleep 4
done
