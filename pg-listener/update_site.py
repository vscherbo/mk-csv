#!/usr/bin/env python
# -*- coding: utf-8 -

import exec_paramiko #.exec_paramiko as exec_paramiko
import logging
import inspect
import os


def do_update_site(site, cmd):

    logging.getLogger(__name__).addHandler(logging.NullHandler())
    whoami = inspect.stack()[0][3]

    ret_str = '{0}: cmd=[{1}]'.format(whoami, cmd if cmd is not None else 'None')
    logging.info(ret_str)

    (out_str, err_str) = exec_paramiko.exec_paramiko(site, 'uploader', cmd)

    if err_str != '':
        logging.error('{0} err_str={2}'.format(whoami, err_str))
        ret_str = err_str
    else:
        ret_str = out_str
        logging.info('completed');

    return ret_str

"""
def set_mod_timedelivery(site, mod_code, mod_timedelivery, mod_qnt = ''):
    cmd = "php $ARC_PATH/update-single-modification.php -m{0} -t'{1}' -q'{2}'".format(mod_code, mod_timedelivery, mod_qnt)

    logging.getLogger(__name__).addHandler(logging.NullHandler())

    if cmd is None:
        ret_str = 'update-single-modification cmd is None'
        logging.error(ret_str)
    else:
        logging.info('update-single-modification cmd={0}'.format(cmd));

        (out_str, err_str) = exec_paramiko.exec_paramiko(site, 'uploader', cmd)
        
        if err_str != '':
            logging.error('update-single-modification cmd={0}, err_str={1}'.format(cmd, err_str)) 
            ret_str = err_str
        else:
            ret_str = out_str
            logging.info('completed');
    
    return ret_str
"""

def set_mod_timedelivery(site, mod_code, mod_timedelivery, mod_qnt = ''):
    cmd = "php $ARC_PATH/update-single-modification.php -m{0} -t'{1}' -q'{2}'".format(mod_code, mod_timedelivery, mod_qnt)
    return do_update_site(site, cmd)

def set_mod_expected_shipments(site, mod_code, mod_expected_shipments):
    cmd = "php $ARC_PATH/update-expected-shipments.php -m{0} -e'{1}'".format(mod_code, mod_expected_shipments)
    return do_update_site(site, cmd)


if __name__ == "__main__":
    log_dir = ''
    log_format = '[%(filename)-20s:%(lineno)4s - %(funcName)20s()] %(levelname)-7s | %(asctime)-15s | %(message)s'

    (prg_name, prg_ext) = os.path.splitext(os.path.basename(__file__))
    logging.basicConfig(filename=prg_name+'.log', format=log_format, level=logging.INFO)

    logging.info('Started')
    # set_mod_timedelivery('kipspb-fl.arc.world', '010620000004', 'Со склада', 13)
    set_mod_expected_shipments('kipspb-fl.arc.world', '010620000004', '2017-12-12:12;')
    logging.info('Finished') 
