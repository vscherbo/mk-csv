#!/usr/bin/env python
# -*- coding: utf-8 -

from __future__ import print_function
from datetime import datetime
from time import sleep
import argparse

from sys import exit
from sys import exc_info
import signal
import select
import psycopg2
import psycopg2.extensions
import logging

#pg_channel = 'do_export'
pg_channels = ('do_export', 'do_compute_single', 'do_single', 'do_expected')
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

    logging.info("commit_ts=[%s] chg_id=%s before call arc_energo.set_mod_timedelivery([%s], [%s], [%s], [%s])", commit_ts_str, chg_id, site, str_modid, time_delivery, qnt)
    sent_result = site +' updated'
    do_retry = False
    retry_cnt = 0
    try:
        curs.callproc('arc_energo.set_mod_timedelivery', [site, str_modid, time_delivery, qnt])
        logging.info("arc_energo.set_mod_timedelivery completed")
    except BaseException, exc:
        logging.error("ERROR arc_energo.set_mod_timedelivery")
        (e_type, e_value, e_traceback) = exc_info()
        logging.error("%s _exception_ in arc_energo.set_mod_timedelivery, type=[%s] value=[%s]", parser.prog, str(e_type), str(e_value))
        sent_result = str(exc).replace("'", "''")
        if str(e_value).find('client.') > 0:  # exec_paramiko exception
            logging.debug("There was exec_paramiko exception on chg_id={0}".format(chg_id))
            # Re-read change_status.
            # If change_status = chg_id
            # then it is sign of retry
            curs.execute('SELECT change_status, retry_cnt FROM stock_status_changed WHERE id=' + chg_id)
            (chg_status, retry_cnt) = curs.fetchone()
            logging.debug("change_status={0}, id={1}, retry_cnt{2}".format(chg_status, chg_id, retry_cnt))
            if int(chg_status) == int(chg_id):  # retry
                logging.debug("It was retry")
                if int(retry_cnt) > 2:
                    chg_status = 2  # stop retry
                    do_retry = False
            else:  # 1st exception
                logging.debug("chg_status={0}. Will retry".format(chg_status))
                chg_status = chg_id
                do_retry = True
                logging.debug("set chg_status = {0}".format(chg_status))
            retry_cnt += 1
        else:  # Not exec_paramiko exception
            chg_status = -1
    else:
        chg_status = 1
    finally:
        try:
            logging.debug("before construct upd_cmd")
            upd_cmd = """UPDATE stock_status_changed SET change_status={chg_status}, retry_cnt={retry_cnt}, sent_result='{sent_result}', dt_sent=clock_timestamp() WHERE id={id};""".format(chg_status=chg_status, retry_cnt=retry_cnt, sent_result=sent_result, id=chg_id)
            # upd_cmd = "UPDATE stock_status_changed SET change_status = " + str(chg_status) + ", sent_result = '" + sent_result + "', dt_sent = '" + str(datetime.now()) + "' WHERE id = " + str(chg_id) +";"
            if do_retry:
                logging.info("upd_cmd=%s", upd_cmd)
            else:
                logging.debug("upd_cmd=%s", upd_cmd)

            curs.execute(upd_cmd)
        except psycopg2.Error, exc:
            logging.error("%s _exception_UPDATE stock_status_changed=%s", parser.prog, str(exc))
        else:
            if do_retry:
                logging.debug("arc_energo.resend_to_site_stock_status({0})".format(chg_id))
                sleep(2)
                curs.callproc('arc_energo.resend_to_site_stock_status', [chg_id])

    logging.info("Finish set_mod_timedelivery")

##############################################################################
def do_compute_set_single(notify):
    logging.debug("     Inside do_compute_set_single")
    chg_id = notify.payload
 
    if ('vm-pg' == args.host) or ('vm-pg.arc.world' == args.host):
        site = 'kipspb.ru'
    else:
        site = 'kipspb-fl.arc.world'

    logging.debug("chg_id=%s, site=%s", chg_id, site)
    try:
        curs.callproc('ssc_compute', [int(chg_id)])
        logging.info("arc_energo.ssc_compute completed")
    except BaseException, exc:
        logging.error("ERROR arc_energo.ssc_compute")
        (e_type, e_value, e_traceback) = exc_info()
        sent_result = "{} _exception_ in arc_energo.ssc_compute, type=[{}] value=[{}]".format(parser.prog, str(e_type), str(e_value))
        logging.error(sent_result)
        try:
            upd_cmd = """UPDATE stock_status_changed SET sent_result='{sent_result}', dt_sent=clock_timestamp() WHERE id={id};""".format(sent_result=sent_result, id=chg_id)
            logging.debug("upd_cmd=%s", upd_cmd)

            curs.execute(upd_cmd)
        except psycopg2.Error, exc:
                logging.error("%s _exception_UPDATE stock_status_changed=%s", parser.prog, str(exc))
    else:
        (ssc_status, ssc_time_delivery, ssc_qnt, ssc_mod_id) = curs.fetchone()
        if 0 == ssc_status:
            logging.debug("ssc_status={0}, ssc_time_delivery={1}, ssc_qnt={2}, ssc_mod_id={3}".format(ssc_status, ssc_time_delivery, ssc_qnt, ssc_mod_id))
            time_delivery = str(ssc_time_delivery)
            qnt = str(ssc_qnt)
            bx_set_mod(chg_id, site, ssc_mod_id, time_delivery, qnt)
        else:
            logging.info("ssc_status={0}, skip sending".format(ssc_status))

    logging.info("Finish do_compute_set_single")

##############################################################################
def bx_set_mod(arg_chg_id, arg_site, arg_mod_id, arg_time_delivery, arg_qnt):
        sent_result = arg_site +' updated'
        do_retry = False
        retry_cnt = 0
        try:
            curs.callproc('arc_energo.set_mod_timedelivery', [arg_site, arg_mod_id, arg_time_delivery, arg_qnt])
            logging.info("arc_energo.set_mod_timedelivery completed")
        except BaseException, exc:
            (e_type, e_value, e_traceback) = exc_info()
            logging.error("%s _exception_ in arc_energo.set_mod_timedelivery, type=[%s] value=[%s]", parser.prog, str(e_type), str(e_value))
            sent_result = str(exc).replace("'", "''")
            if str(e_value).find('client.') > 0:  # exec_paramiko exception
                # Re-read change_status.
                curs.execute('SELECT change_status, retry_cnt FROM stock_status_changed WHERE id=' + arg_chg_id)
                (chg_status, retry_cnt) = curs.fetchone()
                logging.debug("exec_paramiko exception: change_status={0}, id={1}, retry_cnt{2}".format(chg_status, arg_chg_id, retry_cnt))
                # If change_status = chg_id then it is sign of retry
                if int(chg_status) == int(arg_chg_id):  # retry
                    logging.debug("It was retry")
                    if int(retry_cnt) > 3:
                        chg_status = 2  # stop retry
                        do_retry = False
                else:  # 1st exception
                    logging.debug("chg_status={0}. Will retry".format(chg_status))
                    chg_status = arg_chg_id
                    do_retry = True
                    logging.debug("set chg_status = {0}".format(chg_status))
                retry_cnt += 1
            else:  # Not exec_paramiko exception
                chg_status = -1
        else:
            chg_status = 1 # set_mod_timedelivery() returns OK
        finally:
            try:
                logging.debug("before construct upd_cmd")
                upd_cmd = """UPDATE stock_status_changed SET change_status={chg_status}, retry_cnt={retry_cnt}, sent_result='{sent_result}', dt_sent=clock_timestamp() WHERE id={id};""".format(chg_status=chg_status, retry_cnt=retry_cnt, sent_result=sent_result, id=arg_chg_id)
                if do_retry:
                    logging.info("upd_cmd=%s", upd_cmd)
                else:
                    logging.debug("upd_cmd=%s", upd_cmd)

                curs.execute(upd_cmd)
            except psycopg2.Error, exc:
                logging.error("%s _exception_UPDATE stock_status_changed=%s", parser.prog, str(exc))
            else:
                if do_retry:
                    logging.debug("arc_energo.resend_to_site_stock_status({0})".format(arg_chg_id))
                    sleep(2)
                    curs.callproc('arc_energo.resend_to_site_stock_status', [arg_chg_id])

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
    except BaseException, exc:
        chg_status = 9
        logging.error("ERROR arc_energo.set_mod_expected_shipments")
        (e_type, e_value, e_traceback) = exc_info()
        logging.error("%s _exception_ in arc_energo.set_mod_expected_shipments, type=[%s] value=[%s]", parser.prog, str(e_type), str(e_value))
        sent_result = str(exc).replace("'", "''")
    finally:
        try:
            upd_cmd = "UPDATE expected_shipments SET status = " + str(chg_status) + ", sent_result = '" + sent_result + "', dt_sent = '" + str(datetime.now()) + "' WHERE id = " + str(chg_id) +";"
            logging.debug("upd_cmd=%s", upd_cmd)
            curs.execute(upd_cmd)
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
            elif 'do_compute_single' == notify.channel:
                do_compute_set_single(notify)
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
