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

#pg_channel = 'do_export'
pg_channels = ('do_export', 'do_single')
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
    logging.info('Got signal: %s',
          SIGNALS_TO_NAMES_DICT.get(asignal, "Unnamed signal: %d" % asignal))
    global do_while
    global do_connect
    do_while = 0
    do_connect = 0

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGHUP, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


def do_mk_csv(notify):
    try:
        curs.callproc('devmod.fn_mk_csv', [notify.payload])
    except psycopg2.Error, exc:
        logging.warning("%s _exception_fn_mk_csv=%s", parser.prog, str(exc))
        curs.execute('SELECT exp_creator FROM devmod.bx_export_log\
                     WHERE exp_id='
                     + notify.payload)
        emp_id = curs.fetchone()
        try:
            curs.callproc('fn_push_article2user', [emp_id, 'exp_id='+ notify.payload + '/' + str(exc)])
        except psycopg2.Error, exc:
            logging.warning("%s _excecption_fn_push_article2user=%s", parser.prog, str(exc))

        try:
            curs.execute("UPDATE devmod.bx_export_log SET exp_result = quote_literal('" + str(exc).replace("'", "''") +  "') WHERE exp_id = " + notify.payload + ";" )
        except psycopg2.Error, exc:
            logging.warning("%s _excecption_UPDATE bx_export_log=%", parser.prog, str(exc))
    logging.info("Finish fn_mk_csv")

def do_set_single(notify):
    logging.info("Inside do_set_single")
    time_delivery = u''
    (str_modid, stock_status) = notify.payload.split('^')
    if '0' == stock_status: # NOT in stock
        logging.info("not_in_stock branch")
        curs.callproc('devmod.get_def_time_delivery', [str_modid])
        res = curs.fetchone()
        time_delivery = res[0]
        logging.info("type of time_delivery=%s", type(time_delivery))
        logging.info("got default time_delivery=%s", time_delivery)
        #if time_delivery.find('not found') > 0:
        #    print 'ERROR. found'
        #else:
        #    print 'OK, not found'
        if time_delivery.find('not found') > 0:
            logging.warning("time_delivery = None")
            time_delivery = None # time_delivery is incorrect
        else:
            logging.info("time_delivery = %s", time_delivery)
    elif '1' == stock_status:
        time_delivery = u'Ожидается на склад'
        logging.info("time_delivery = %s", time_delivery)
    elif '2' == stock_status:
        time_delivery = u'Со склада'
        logging.info("time_delivery = %s", time_delivery)
    else:   
        # TODO wrong stock_status
        time_delivery = None
        logging.warning("wrong stock_status={%s}, time_delivery = None", stock_status)

    if time_delivery != None:
        # TODO - choose site
        site = 'kipspb-fl.arc.world'
        logging.info("before call devmod.set_mod_timedelivery([%s], [%s], [%s])", site, str_modid, time_delivery)
        curs.callproc('devmod.set_mod_timedelivery', [site, str_modid, time_delivery])
    else:
        logging.info("? time_delivery == None")
    logging.info("Finish set_mod_timedelivery")

def do_listen(a_pg_timeout):
    sel_res = select.select([conn], [], [], a_pg_timeout)
    if sel_res == ([], [], []):
        pass
        logging.debug("Timeout %s sec", a_pg_timeout)
    else:
        conn.poll()
        while conn.notifies:
            notify = conn.notifies.pop()
            logging.info(" Got NOTIFY: %s %s %s", notify.pid, notify.channel, notify.payload)
            if 'do_export' == notify.channel:
                do_mk_csv(notify)
            elif 'do_single' == notify.channel:
                do_set_single(notify)
            else:
                pass
        conn.commit()
# End of do_listen


# password='PASS'-.pgpass
DSN = 'dbname=%s host=%s user=%s' % (args.db, args.host, args.user)

numeric_level = getattr(logging, args.log, None)
if not isinstance(numeric_level, int):
    raise ValueError('Invalid log level: %s' % loglevel)
logging.basicConfig(filename='pg-listener.log', format='%(asctime)s %(levelname)s: %(message)s', level=numeric_level) # INFO)

logging.info("Started")
do_connect = 1
while 1 == do_connect:
    rc = 1
    sel_res = ([], [], [])
    try:
        conn = psycopg2.connect(DSN)
        conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
        curs = conn.cursor()
        for pg_channel in pg_channels:
            curs.execute("LISTEN " + pg_channel + ";")
            logging.info("Waiting for notifications on channel %s", pg_channel)
        mark_counter=0
        do_while = 1
    except BaseException, exc:
        logging.warning(" Exception on connect=%s. Sleep for %s", str(exc), str(pg_timeout))
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
        except BaseException, exc:
            if 4 == exc.args[0]:  # interrupt
                # do_while = 0
                rc = 0
                logging.info("exception4, %s", exc.args[1])
            elif exc.args[0].find('closed'):
                do_while = 0
                logging.info("Try to re-connect...")
            else:
                logging.warning("Other exception=%s", str(exc))

logging.info("Exiting")
exit(rc)
