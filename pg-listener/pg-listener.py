#!/usr/bin/env python
# -*- coding: utf-8 -

from __future__ import print_function
from datetime import datetime
import argparse

import signal
import select
import psycopg2
import psycopg2.extensions

parser = argparse.ArgumentParser(description='Pg listener for .')
parser.add_argument('--host', type=str, help='PG host')
parser.add_argument('--db', type=str, help='database name')
parser.add_argument('--user', type=str, help='db user')
args = parser.parse_args()
# print(parser.prog)
# print(args.host)
# print(args.db)
# print(args.user)

SIGNALS_TO_NAMES_DICT = dict((getattr(signal, n), n) for n in dir(signal)
                             if n.startswith('SIG') and '_' not in n)


def signal_handler(asignal, frame):
    print('\nGot signal: ',
          SIGNALS_TO_NAMES_DICT.get(asignal, "Unnamed signal: %d" % asignal))

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGHUP, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

pg_channel = 'do_export'
pg_timeout = 2

# password='PASS'-.pgpass
DSN = 'dbname=%s host=%s user=%s' % (args.db, args.host, args.user)

conn = psycopg2.connect(DSN)
conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)

curs = conn.cursor()
curs.execute("LISTEN " + pg_channel + ";")

print("Waiting for notifications on channel %s" % pg_channel)
do_while = 1
while 1 == do_while:
    try:
        sel_res = select.select([conn], [], [], pg_timeout)
    except BaseException, exc:
        if 4 == exc.args[0]:  # interrupt
            do_while = 0
            print(" exception4=", exc.args[1])
    # finally:
    #    sel_res == ([], [], [])

    if sel_res == ([], [], []):
        print("%s Timeout" % datetime.now())
    else:
        conn.poll()
        while (1 == do_while) and conn.notifies:
            notify = conn.notifies.pop()
            print(str(datetime.now()) + " Got NOTIFY:",
                  notify.pid, notify.channel, notify.payload)
            try:
                curs.callproc('devmod.fn_mk_csv', [notify.payload])
            except psycopg2.Error, exc:
                print("% _exception=%", parser.prog, exc)
                curs.execute('SELECT exp_creator FROM devmod.bx_export_log\
                             WHERE exp_id='
                             + notify.payload)
                emp_id = curs.fetchone()
                curs.callproc('fn_push_article2user', [emp_id, str(exc)])
            print(str(datetime.now()) + " Finish fn_mk_csv")

print(str(datetime.now()) + " Exiting...")
