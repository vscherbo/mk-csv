#!/bin/sh

rc=0
while [ $rc -eq 0 ]
do
  nohup ./pg-listener.py --host=vm-pg-devel --db arc_energo --user arc_energo &
  rc=$?
done
