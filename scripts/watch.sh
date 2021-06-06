#!/bin/bash

while true ; do
	DT=$(date '+%Y%m%d')

	bin/watch.pl -c Watch2 | tee -a tmp/watch2-$DT.out
	sleep 15
done
