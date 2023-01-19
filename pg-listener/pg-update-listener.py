#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function
from time import sleep
import argparse

import os
from sys import exit
from sys import exc_info
import logging
import signal
import select
import psycopg2
import psycopg2.extensions
import update_site

# pg_channels = ('do_export', 'do_compute_single', 'do_expected')
pg_channels = ('do_compute_single', 'do_expected')
pg_timeout = 5
mark_display = 3600

parser = argparse.ArgumentParser(description='Pg listener for .')
parser.add_argument('--host', type=str, required=True, help='PG host')
parser.add_argument('--db', type=str, required=True, help='database name')
parser.add_argument('--user', type=str, required=True, help='db user')
parser.add_argument('--site', type=str, default="kipspb-dev.arc.world", help='site')
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

def get_site(arg_host, arg_site):
    if ('vm-pg' == arg_host) or ('vm-pg.arc.world' == arg_host):
        #loc_site = 'kipspb.ru'
        loc_site = arg_site
    elif arg_site.endswith('arc.world'):
        loc_site = arg_site
    else:
        loc_site = 'kipspb-dev.arc.world'
    return loc_site


##############################################################################
def do_compute_set_single(notify):
    logging.debug("     Inside do_compute_set_single")
    chg_id = notify.payload

    site = get_site(args.host, args.site)
    logging.debug("chg_id=%s, site=%s", chg_id, site)
    try:
        curs.callproc('ssc_compute', [int(chg_id)])
        (ssc_status, ssc_time_delivery, ssc_qnt, ssc_mod_id, ssc_active) = curs.fetchone()
        logging.debug("arc_energo.ssc_compute completed")
    except BaseException, exc:
        logging.error("ERROR arc_energo.ssc_compute")
        (e_type, e_value, e_traceback) = exc_info()
        sent_result = "{} _exception_ in arc_energo.ssc_compute, type=[{}] value=[{}]".format(parser.prog, str(e_type), str(e_value))
        logging.error(sent_result)
        try:
            upd_cmd = """UPDATE stock_status_changed SET sent_result='{sent_result}', dt_sent=clock_timestamp() WHERE id={id};""".format(sent_result=sent_result, id=chg_id)
            logging.info("upd_cmd=%s", upd_cmd)
            curs.execute(upd_cmd)
            conn.commit()
        except psycopg2.Error, exc:
            logging.error("_exception_UPDATE stock_status_changed=%s", str(exc))
    else:
        try:
            upd_cmd = """UPDATE stock_status_changed SET sent_result='ssc_compute completed', dt_sent=clock_timestamp() WHERE id={id};""".format(id=chg_id)
            logging.info("upd_cmd=%s", upd_cmd)
            curs.execute(upd_cmd)
            conn.commit()
        except psycopg2.Error, exc:
            logging.error("_exception_UPDATE stock_status_changed=%s", str(exc))
        else:
            if 0 == ssc_status:
                logging.info("ssc_status={0}, ssc_time_delivery={1}, ssc_qnt={2}, ssc_mod_id={3}".format(ssc_status, ssc_time_delivery, ssc_qnt, ssc_mod_id))
                time_delivery = str(ssc_time_delivery)
                qnt = str(ssc_qnt)
                bx_update_mod(chg_id, site, ssc_mod_id, time_delivery, qnt, ssc_active)
            else:
                logging.info("-> ssc_status={0}, skip sending".format(ssc_status))

    logging.info("Finish")

##############################################################################
def bx_update_mod(arg_chg_id, arg_site, arg_mod_id, arg_time_delivery, arg_qnt, arg_active):
    sent_result = 'before {} update'.format(arg_site)
    do_retry = False
    # Re-read change_status.
    curs.execute('SELECT change_status, retry_cnt FROM stock_status_changed WHERE id=' + arg_chg_id)
    (chg_status, retry_cnt) = curs.fetchone()
    try:
        update_site.set_mod_timedelivery(arg_site, arg_mod_id, arg_time_delivery, arg_qnt, arg_active)
    except BaseException, exc:
        (e_type, e_value, e_traceback) = exc_info()
        logging.error("_exception_ in set_mod_timedelivery, type=[%s] value=[%s]", str(e_type), str(e_value))
        # logging.exception("_exception_ in set_mod_timedelivery", exc_info=True)
        sent_result = str(exc).replace("'", "''")
        if (str(e_value).find('client.') > 0
           or str(e_value).find('Error reading SSH protocol banner') > 0
           or str(e_value).find('Network is unreachable') > 0
           or str(e_value).find('Unable to connect') > 0
           or str(e_value).find('timed out') > 0
           or str(e_value).find('503 Service Temporarily Unavailable') > 0
           or str(e_value).find('Connection re') > 0):  # exec_paramiko exception
            # If change_status = chg_id then it is sign of retry
            #if int(chg_status) == int(arg_chg_id):  # ? does not work
            logging.warning("exec_paramiko exception: change_status={0}, id={1}, retry_cnt={2}".format(chg_status, arg_chg_id, retry_cnt))
            chg_status = arg_chg_id
            do_retry = True
            if int(retry_cnt) > 0:  # retry
                logging.info("It was retry")
                if int(retry_cnt) > 3:
                    chg_status = 2  # stop retry
                    do_retry = False
            else:  # 1st exception
                logging.info("1st exception chg_status={0}. Will retry".format(chg_status))
            logging.info("set chg_status = {0}".format(chg_status))
            retry_cnt += 1
        else:  # Not exec_paramiko exception
            chg_status = -1
            retry_cnt = 0
    else:
        chg_status = 1 # set_mod_timedelivery() returns OK
        sent_result = arg_site +' updated'
    finally:
        try:
            logging.debug("before construct upd_cmd")
            upd_cmd = """UPDATE stock_status_changed SET change_status={chg_status}, retry_cnt={retry_cnt}, sent_result='{sent_result}', dt_sent=clock_timestamp() WHERE id={id};""".format(chg_status=chg_status, retry_cnt=retry_cnt, sent_result=sent_result, id=arg_chg_id)
            logging.log(logging.WARN if do_retry else logging.INFO, "do_retry={0}, upd_cmd={1}".format(do_retry, upd_cmd))
            if upd_cmd:
                curs.execute(upd_cmd)
                conn.commit()
                logging.info("Run upd_cmd")
            else:
                logging.error("upd_cmd is None")
        except psycopg2.Error, exc:
            logging.error("_exception_UPDATE stock_status_changed=%s", str(exc))
        except BaseException, exc:
            logging.error("Unexpected=%s", str(exc))
            raise
        else:
            if do_retry:
                logging.info("arc_energo.resend_to_site_stock_status({0})".format(arg_chg_id))
                sleep(2)
                curs.callproc('arc_energo.resend_to_site_stock_status', [arg_chg_id])

##############################################################################
def do_set_expected(notify):
    logging.debug("     Inside do_set_expected")
    (str_modid, str_expected, chg_id) = notify.payload.split('^')

    site = get_site(args.host, args.site)

    logging.info("before call chg_id=[%s] arc_energo.set_mod_expected_shipments([%s], [%s], [%s])", chg_id, site, str_modid, str_expected)
    sent_result = 'before {} update'.format(site)
    do_retry = False
    # Re-read change_status.
    curs.execute('SELECT status, retry_cnt FROM expected_shipments WHERE id=' + chg_id)
    (chg_status, retry_cnt) = curs.fetchone()
    try:
        update_site.set_mod_expected_shipments(site, str_modid, str_expected)
    except BaseException, exc:
        chg_status = 9
        logging.error("ERROR arc_energo.set_mod_expected_shipments")
        (e_type, e_value, e_traceback) = exc_info()
        logging.error("_exception_ in arc_energo.set_mod_expected_shipments, type=[%s] value=[%s]", str(e_type), str(e_value))
        sent_result = str(exc).replace("'", "''")
        #if (str(e_value).find('client.') > 0
        #       or str(e_value).find('Connection reset by peer') > 0):  # exec_paramiko exception
        if (str(e_value).find('client.') > 0
           or str(e_value).find('Error reading SSH protocol banner') > 0
           or str(e_value).find('Network is unreachable') > 0
           or str(e_value).find('Unable to connect') > 0
           or str(e_value).find('timed out') > 0
           or str(e_value).find('503 Service Temporarily Unavailable') > 0
           or str(e_value).find('Connection re') > 0):  # exec_paramiko exception
            logging.warning("exec_paramiko exception: status={0}, id={1}, retry_cnt{2}".format(chg_status, chg_id, retry_cnt))
            chg_status = chg_id
            do_retry = True
            if int(retry_cnt) > 0:  # retry
                logging.info("It was retry")
                if int(retry_cnt) > 3:
                    chg_status = 2  # stop retry
                    do_retry = False
            else:  # 1st exception
                logging.info("1st exception chg_status={0}. Will retry".format(chg_status))
            logging.info("set chg_status = {0}".format(chg_status))
            retry_cnt += 1
        else:  # Not exec_paramiko exception
            chg_status = -1
            retry_cnt = 0
    else:
        chg_status = 1
        sent_result = site +' updated'
    finally:
        try:
            # upd_cmd = "UPDATE expected_shipments SET status = " + str(chg_status) + ", sent_result = '" + sent_result + "', dt_sent = '" + str(datetime.now()) + "' WHERE id = " + str(chg_id) +";"
            upd_cmd = """UPDATE expected_shipments SET status={chg_status}, retry_cnt={retry_cnt}, sent_result='{sent_result}', dt_sent=clock_timestamp() WHERE id={chg_id};""".format(chg_status=chg_status, retry_cnt=retry_cnt, sent_result=sent_result, chg_id=chg_id)
            logging.log(logging.WARN if do_retry else logging.INFO, "do_retry={0}, upd_cmd={1}".format(do_retry, upd_cmd))
            if upd_cmd:
                curs.execute(upd_cmd)
                conn.commit()
                logging.info("Run upd_cmd")
            else:
                logging.error("upd_cmd is None")

            #logging.info("upd_cmd=%s", upd_cmd) if do_retry else logging.debug("upd_cmd=%s", upd_cmd)
            #curs.execute(upd_cmd)
        except psycopg2.Error, exc:
            logging.error("_exception_UPDATE expected_shipments=%s", str(exc))
        else:
            if do_retry:
                logging.info("arc_energo.resend_to_site_expected_shipment({0})".format(chg_id))
                sleep(2)
                curs.callproc('arc_energo.resend_to_site_expected_shipment', [chg_id])

    logging.info("Finish set_mod_expected_shipments")

def do_mk_csv(notify):
    pass

#############################################################################
def do_listen(a_pg_timeout):
    sel_res = select.select([conn], [], [], a_pg_timeout)
    if sel_res == ([], [], []):
        pass
    else:
        conn.poll()
        while conn.notifies:
            notify = conn.notifies.pop(0)
            logging.info("=========================================")
            logging.info("Got NOTIFY: %s %s %s", notify.pid, notify.channel, notify.payload)
            if 'do_export' == notify.channel:
                do_mk_csv(notify)
            elif 'do_compute_single' == notify.channel:
                do_compute_set_single(notify)
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

log_format = '%(asctime)-15s | %(levelname)-7s | %(filename)-25s:%(lineno)4s - %(funcName)25s() | %(message)s'
(prg_name, prg_ext) = os.path.splitext(os.path.basename(__file__))
logging.basicConfig(filename=prg_name+'.log', format=log_format, level=numeric_level) # INFO)

logging.info("Started")
do_connect = 1
while 1 == do_connect:
    rc = 1
    sel_res = ([], [], [])
    try:
        conn = psycopg2.connect(DSN)
        conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
        curs = conn.cursor()
        curs.callproc('arc_const', ('prodsite',))
        prod_site = curs.fetchone()  # does not used yet
        logging.info('prod_site=%s', prod_site[0])
        for pg_channel in pg_channels:
            curs.execute("LISTEN " + pg_channel + ";")
            logging.info("Waiting for notifications on channel %s", pg_channel)
        mark_counter = 0
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
            logging.info("do_listen exception, %s", str(exc.args))
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
