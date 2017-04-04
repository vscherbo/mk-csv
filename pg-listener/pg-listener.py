#!/usr/bin/env python
# -*- coding: utf-8 -

from __future__ import print_function
from datetime import datetime
from time import sleep
import argparse

from sys import exit
# from sys import exc_info
import signal
import select
import psycopg2
import psycopg2.extensions
import logging

#pg_channel = 'do_export'
pg_channels = ('do_export', 'do_single', 'do_expected')
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


##############################################################################
def do_mk_csv(notify):
    try:
        logging.debug("try devmod.fn_mk_csv(%s)", notify.payload)
        curs.callproc('devmod.fn_mk_csv', [notify.payload])
    except psycopg2.Error, exc:
        logging.warning("%s _exception_fn_mk_csv=%s", parser.prog, str(exc))
        curs.execute('SELECT exp_creator FROM devmod.bx_export_log\
                     WHERE exp_id='
                     + notify.payload)
        emp_id = curs.fetchone()
        try:
            logging.debug("try fn_push_article2user(%s, %s)", emp_id, 'exp_id='+ notify.payload + '/' + str(exc)) 
            curs.callproc('fn_push_article2user', [emp_id, 'exp_id='+ notify.payload + '/' + str(exc)])
        except psycopg2.Error, exc:
            logging.warning("%s _exception_fn_push_article2user=%s", parser.prog, str(exc))

        try:
            logging.debug("try UPDATE devmod.bx_export_log SET exp_result ... WHERE exp_id=%s", notify.payload)
            curs.execute("UPDATE devmod.bx_export_log SET exp_result = quote_literal('" + str(exc).replace("'", "''") +  "') WHERE exp_id = " + notify.payload + ";" )
        except psycopg2.Error, exc:
            logging.warning("%s _exception_UPDATE bx_export_log=%", parser.prog, str(exc))
    logging.info("Finish fn_mk_csv")

##############################################################################
def do_set_single(notify):
    logging.debug("     Inside do_set_single")
    (str_modid, time_delivery, chg_id, qnt) = notify.payload.split('^')
    commit_ts_cmd = 'SELECT pg_xact_commit_timestamp(xmin) FROM stock_status_changed WHERE id={0};'.format(chg_id);
    try:
        curs.execute(commit_ts_cmd)
        commit_ts = curs.fetchone()
        commit_ts_str = commit_ts[0].strftime('%Y-%m-%d %H:%M:%S.%f')
    except:
        commit_ts_str = 'commit_ts error'
 
    if ('vm-pg' == args.host) or ('vm-pg.arc.world' == args.host):
        site = 'kipspb.ru'
    else:
        site = 'kipspb-fl.arc.world'

    logging.info("commit_ts=[%s] before call arc_energo.set_mod_timedelivery([%s], [%s], [%s], [%s])", commit_ts_str, site, str_modid, time_delivery, qnt)
    sent_result = site +' updated'
    try:
        curs.callproc('arc_energo.set_mod_timedelivery', [site, str_modid, time_delivery, qnt])
        logging.info("arc_energo.set_mod_timedelivery completed")
        chg_status = 1
    except psycopg2.Error, exc:
        chg_status = 2
        logging.error("ERROR arc_energo.set_mod_timedelivery")
        # (e_type, e_value, e_traceback) = exc_info()[0]
        # logging.error("%s _exception_ in arc_energo.set_mod_timedelivery, type=[%s] value=[%s] traceback=[%s]", parser.prog, str(e_type), str(e_value), str(e_traceback))
        sent_result = str(exc).replace("'", "''")
        logging.error("%s _exception_ in arc_energo.set_mod_timedelivery=%s", parser.prog, sent_result)
    finally:
        try:
            # fast and dirty patch
            if chg_id <> 0:
                upd_cmd = "UPDATE stock_status_changed SET change_status = " + str(chg_status) + ", sent_result = '" + sent_result + "', dt_sent = '" + str(datetime.now()) + "' WHERE id = " + str(chg_id) +";"
                logging.debug("upd_cmd=%s", upd_cmd)
                curs.execute(upd_cmd)
            else:
                logging.warning("WARNING: chg_id=0 arc_energo.set_mod_timedelivery")
        except psycopg2.Error, exc:
            logging.error("%s _exception_UPDATE stock_status_changed=%s", parser.prog, str(exc))

    logging.info("Finish set_mod_timedelivery")

##############################################################################
def do_set_expected(notify):
    logging.debug("     Inside do_set_expected")
    (str_modid, str_expected, chg_id) = notify.payload.split('^')

    if ('vm-pg' == args.host) or ('vm-pg.arc.world' == args.host):
        site = 'kipspb.ru'
    else:
        site = 'kipspb-fl.arc.world'
    logging.info("before call chg_id=[%s] arc_energo.set_mod_expected_shipments([%s], [%s], [%s])", chg_id, site, str_modid, str_expected)
    sent_result = site +' updated'
    try:
        curs.callproc('arc_energo.set_mod_expected_shipments', [site, str_modid, str_expected])
        logging.info("arc_energo.set_mod_expected_shipments completed")
        chg_status = 1
    except psycopg2.Error, exc:
        chg_status = 9
        logging.error("ERROR arc_energo.set_mod_expected_shipments")
        # (e_type, e_value, e_traceback) = exc_info()[0]
        # logging.error("%s _exception_ in arc_energo.set_mod_expected_shipments, type=[%s] value=[%s] traceback=[%s]", parser.prog, str(e_type), str(e_value), str(e_traceback))
        sent_result = str(exc).replace("'", "''")
        logging.error("%s _exception_ in arc_energo.set_mod_expected_shipments=%s", parser.prog, sent_result)
    finally:
        try:
            # fast and dirty patch
            if chg_id <> 0:
                upd_cmd = "UPDATE expected_shipments SET status = " + str(chg_status) + ", sent_result = '" + sent_result + "', dt_sent = '" + str(datetime.now()) + "' WHERE id = " + str(chg_id) +";"
                logging.debug("upd_cmd=%s", upd_cmd)
                curs.execute(upd_cmd)
            else:
                logging.warning("WARNING chg_id=0 arc_energo.set_mod_expected_shipments")
        except psycopg2.Error, exc:
            logging.error("%s _exception_UPDATE expected_shipments=%s", parser.prog, str(exc))

    logging.info("Finish set_mod_expected_shipments")

#############################################################################
def do_listen(a_pg_timeout):
    sel_res = select.select([conn], [], [], a_pg_timeout)
    if sel_res == ([], [], []):
        pass
    else:
        conn.poll()
        while conn.notifies:
            notify = conn.notifies.pop(0)
            logging.info(" Got NOTIFY: %s %s %s", notify.pid, notify.channel, notify.payload)
            if 'do_export' == notify.channel:
                do_mk_csv(notify)
            elif 'do_single' == notify.channel:
                do_set_single(notify)
            elif 'do_expected' == notify.channel:
                do_set_expected(notify)
            else:
                logging.warning("unexpected notify.channel=%s", notify.channel)
                pass
            conn.commit()
# End of do_listen


# password='PASS'-.pgpass
DSN = 'dbname=%s host=%s user=%s' % (args.db, args.host, args.user)

numeric_level = getattr(logging, args.log, None)
if not isinstance(numeric_level, int):
    raise ValueError('Invalid log level: %s' % numeric_level)
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
