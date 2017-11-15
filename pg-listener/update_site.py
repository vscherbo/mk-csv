#!/usr/bin/env python
# -*- coding: utf-8 -

import exec_paramiko #.exec_paramiko as exec_paramiko
import logging

def set_mod_timedelivery(site, mod_code, mod_timedelivery, mod_qnt = ''):
    cmd = "php $ARC_PATH/update-single-modification.php -m{0} -t'{1}' -q'{2}'".format(mod_code, mod_timedelivery, mod_qnt)

    logging.getLogger(__name__).addHandler(logging.NullHandler())

    if cmd is None:
        ret_str = 'update-single-modification cmd is None'
        logging.error('update-single-modification cmd is None')
    else:
        logging.debug('update-single-modification cmd={0}'.format(cmd));

        (out_str, err_str) = exec_paramiko.exec_paramiko(site, 'uploader', cmd)
        
        if err_str != '':
            logging.error('update-single-modification cmd={0}, err_str={1}'.format(cmd, err_str)) 
            ret_str = err_str
        else:
            ret_str = out_str
    
    return ret_str

if __name__ == "__main__":
    log_dir = ''
    log_format = '[%(filename)-20s:%(lineno)4s - %(funcName)20s()] %(levelname)-7s | %(asctime)-15s | %(message)s'

    logging.basicConfig(filename='update_site.log', format=log_format, level=logging.INFO)

    logging.info('Started')
    set_mod_timedelivery('kipspb-fl.arc.world', '010620000004', 'Со склада', 13)
    logging.info('Finished') 
