#!/usr/bin/env python2.7
# -*- coding: utf-8 -

import logging
import inspect
import os
import exec_paramiko #.exec_paramiko as exec_paramiko


def do_update_site(site, cmd):

    logging.getLogger(__name__).addHandler(logging.NullHandler())
    whoami = inspect.stack()[0][3]

    ret_str = '{0}: cmd=[{1}]'.format(whoami, cmd if cmd is not None else 'None')
    logging.info(ret_str)

    try:
        (out_str, err_str) = exec_paramiko.exec_paramiko(site, 'uploader', cmd, timeout=15)  # PRODUCTION
        # (out_str, err_str) = exec_paramiko.exec_paramiko(site, 'uploader', cmd, timeout=5, port=2222)  # DEBUG timeout
    except BaseException, exc:
        ret_str = 'do_update_site exec_paramiko exception={0}'.format(exc)
        #logging.exception(ret_str, exc_info=True)
        #raise
    else:
        ret_str = out_str
        logging.info('completed')

    return ret_str


def set_mod_timedelivery(site, mod_code, mod_timedelivery, mod_qnt = '', active=True):
    cmd = "php $ARC_PATH/update-single-modification.php -m{0} -t'{1}' -q'{2}'".format(mod_code, mod_timedelivery, mod_qnt)
    logging.info('set_mod_timedelivery, active=%s', active);
    if active is None:  # PATCH!!!
        active = True

    if not active:
        logging.info('set_mod_timedelivery, add -aN');
        cmd = "{0} -aN".format(cmd)

    rest_str = None
    try:
        ret_str = do_update_site(site, cmd)
    except Exception, exc:
        ret_str = 'set_mod_timedelivery call do_update_site exception={0}'.format(ret_str)
        #raise
    if ret_str and ret_str != '':
        raise ValueError(ret_str) 
    return ret_str

def set_mod_expected_shipments(site, mod_code, mod_expected_shipments):
    cmd = "php $ARC_PATH/update-expected-shipments.php -m{0} -e'{1}'".format(mod_code,\
            mod_expected_shipments)
    try:
        ret_str = do_update_site(site, cmd)
    except Exception, exc:
        ret_str = 'set_mod_expected_shipments call do_update_site exception={0}'.format(ret_str)
        #raise
    if ret_str and ret_str != '':
        raise ValueError(ret_str) 
    return ret_str
    #return do_update_site(site, cmd)


if __name__ == "__main__":
    LOG_FORMAT = '[%(filename)-21s:%(lineno)4s - %(funcName)20s()] %(levelname)-7s | %(asctime)-15s | %(message)s'

    (PRG_NAME, PRG_EXT) = os.path.splitext(os.path.basename(__file__))
    logging.basicConfig(filename=PRG_NAME+'.log', format=LOG_FORMAT, level=logging.INFO)

    logging.info('Started')
    # set_mod_timedelivery('kipspb-dev.arc.world', '010620000004', 'Со склада', 13)
    set_mod_expected_shipments('kipspb-dev.arc.world', '010620000004', '2017-12-12:12;')
    logging.info('Finished')
