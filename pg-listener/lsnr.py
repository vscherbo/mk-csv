#!/usr/bin/env python
# -*- coding: utf-8 -

from __future__ import print_function
import select
import psycopg2
import psycopg2.extensions
from datetime import datetime
import signal
import sys

SIGNALS_TO_NAMES_DICT = dict((getattr(signal, n), n) for n in dir(signal) if n.startswith('SIG') and '_' not in n )

def signal_handler(signal, frame):
        do_while = 0
        print('\nGot signal: ' , SIGNALS_TO_NAMES_DICT.get(signal, "Unnamed signal: %d" % signal) )
        #print('Got signal: ', signal )
        #sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGHUP, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

dbname = 'arc_energo'
host = 'vm-pg-devel'
user = 'arc_energo'
#password = 'XXXX'
pg_channel = 'do_export'
pg_timeout = 2

#DSN = 'dbname=%s host=%s user=%s password=%s' % (dbname, host, user, password)
DSN = 'dbname=%s host=%s user=%s' % (dbname, host, user) # password='XXXX' - .pgpass


conn = psycopg2.connect(DSN)
conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)

curs = conn.cursor()
curs.execute("LISTEN " + pg_channel +";")

print("Waiting for notifications on channel %s" % pg_channel)
do_while = 1
while 1 == do_while:
    try:
        sel_res = select.select([conn],[],[],pg_timeout)
    except Exception, exc:
        if 4 == exc.args[0]: # interrupt
            do_while = 0
            print(exc.args[1])
    finally:
        sel_res == ([],[],[])


    if sel_res == ([],[],[]):
        #print str(datetime.now()) + " Timeout"
        print("%s Timeout" % datetime.now() )
    else:
        conn.poll()
        while (1 == do_while) and conn.notifies:
            notify = conn.notifies.pop()
            print( str(datetime.now()) + " Got NOTIFY:", notify.pid, notify.channel, notify.payload) 
            try:
                curs.callproc('devmod.fn_mk_csv', [notify.payload])
            except Exception, exc:
                #print(exc.args[1])
                print("lsnr.py exc=",exc)
                curs.execute('SELECT exp_creator FROM devmod.bx_export_log WHERE exp_id=' + notify.payload ) 
                emp_id = curs.fetchone()
                curs.callproc('fn_push_article2user', [emp_id, str(exc)])
            print(str(datetime.now()) + " Finish fn_mk_csv")

print(str(datetime.now()) + " Exiting...")

