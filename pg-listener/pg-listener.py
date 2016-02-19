#!/usr/bin/env python
# -*- coding: utf-8 -

from __future__ import print_function
from datetime import datetime
from time import sleep
import argparse

from sys import exit
import signal
import select
import psycopg2
import psycopg2.extensions
import logging

pg_channel = 'do_export'
pg_timeout = 5
mark_display=3600

parser = argparse.ArgumentParser(description='Pg listener for .')
parser.add_argument('--host', type=str, help='PG host')
parser.add_argument('--db', type=str, help='database name')
parser.add_argument('--user', type=str, help='db user')
parser.add_argument('--log', type=str, default="INFO", help='log level')
args = parser.parse_args()
# print(parser.prog)
# print(args.host)
# print(args.db)
# print(args.user)

SIGNALS_TO_NAMES_DICT = dict((getattr(signal, n), n) for n in dir(signal)
                             if n.startswith('SIG') and '_' not in n)


def signal_handler(asignal, frame):
    # print('\nGot signal: ',
    #      SIGNALS_TO_NAMES_DICT.get(asignal, "Unnamed signal: %d" % asignal))
    logging.info('Got signal: %s',
          SIGNALS_TO_NAMES_DICT.get(asignal, "Unnamed signal: %d" % asignal))
    global do_while
    global do_connect
    do_while = 0
    do_connect = 0

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGHUP, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


def do_listen(a_pg_timeout):
    sel_res = select.select([conn], [], [], a_pg_timeout)
    if sel_res == ([], [], []):
        pass
        # print("%s Timeout" % datetime.now())
        logging.debug("Timeout %s sec", a_pg_timeout)
    else:
        conn.poll()
        # while (1 == do_while) and conn.notifies:
        while conn.notifies:
            notify = conn.notifies.pop()
            logging.info(" Got NOTIFY: %s %s %s", notify.pid, notify.channel, notify.payload)
            # print(str(datetime.now()) + " Got NOTIFY:",
            #      notify.pid, notify.channel, notify.payload)
            try:
                curs.callproc('devmod.fn_mk_csv', [notify.payload])
            except psycopg2.Error, exc:
                # print("% _exc_fn_mk_csv=%", parser.prog, exc)
                logging.warning("%s _exception_fn_mk_csv=%s", parser.prog, str(exc))
                curs.execute('SELECT exp_creator FROM devmod.bx_export_log\
                             WHERE exp_id='
                             + notify.payload)
                emp_id = curs.fetchone()
                try:
                    curs.callproc('fn_push_article2user', [emp_id, 'exp_id='+ notify.payload + '/' + str(exc)])
                except psycopg2.Error, exc:
                    logging.warning("%s _excecption_fn_push_article2user=%s", parser.prog, str(exc))
                    # print("% _exc_fn_push_article2user=%", parser.prog, exc)

                try:
                    curs.execute("UPDATE devmod.bx_export_log SET exp_result = quote_literal('" + str(exc).replace("'", "''") +  "') WHERE exp_id = " + notify.payload + ";" )
                except psycopg2.Error, exc:
                    logging.warning("%s _excecption_UPDATE bx_export_log=%", parser.prog, str(exc))
                    # print("% _exc UPDATE bx_export_log=%", parser.prog, exc)
            conn.commit()
            logging.info("Finish fn_mk_csv")
            # print(str(datetime.now()) + " Finish fn_mk_csv")
# End of do_listen


# password='PASS'-.pgpass
DSN = 'dbname=%s host=%s user=%s' % (args.db, args.host, args.user)

numeric_level = getattr(logging, args.log, None)
if not isinstance(numeric_level, int):
    raise ValueError('Invalid log level: %s' % loglevel)
logging.basicConfig(filename='pg-listener.log', format='%(asctime)s %(levelname)s: %(message)s', level=numeric_level) # INFO)

# print("Started at %s" % datetime.now())
logging.info("Started")
do_connect = 1
while 1 == do_connect:
    rc = 1
    sel_res = ([], [], [])
    try:
        conn = psycopg2.connect(DSN)
        conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
        curs = conn.cursor()
        curs.execute("LISTEN " + pg_channel + ";")
        mark_counter=0
        # print("Waiting for notifications on channel %s" % pg_channel)
        logging.info("Waiting for notifications on channel %s", pg_channel)
        do_while = 1
    except BaseException, exc:
        logging.warning(" Exception on connect=%s. Sleep for %s", str(exc), str(pg_timeout))
        # print(" Exception on connect=", exc.args)
        do_while = 0
        sleep(pg_timeout);

    # main loop
    while 1 == do_while:
        try:
            do_listen(pg_timeout)
            mark_counter += pg_timeout
            if mark_counter >= mark_display:
                mark_counter=0
                logging.info("Heartbeat mark")
                # print("%s Heartbeat mark" % datetime.now())
        except BaseException, exc:
            if 4 == exc.args[0]:  # interrupt
                # do_while = 0
                rc = 0
                # print(" exception4=", exc.args[1])
                logging.info("exception4, %s", exc.args[1])
            elif exc.args[0].find('closed'):
                do_while = 0
                logging.info("Try to re-connect...")
                # print("Try to re-connect...")
            else:
                logging.warning("Other exception=%s", str(exc))
                # print(" Other exception=", exc.args)

# print(str(datetime.now()) + " Exiting...")
logging.info("Exiting")
exit(rc)
