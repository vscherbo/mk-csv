#!/usr/bin/env python
# -*- coding: utf-8 -

import logging
from os.path import expanduser
import paramiko

def exec_paramiko(rem_host, rem_user, rem_cmd, rem_port=22):
    """
    OUT out_str character varying,
    OUT err_str character varying)
    """
    log_dir = ''
    # log_format = '%(levelname)-7s | %(asctime)-15s | %(message)s'
    log_format = '[%(filename)s:%(lineno)s - %(funcName)20s() ] %(levelname)-7s | %(asctime)-15s | %(message)s'

    logger = logging.getLogger("exec_paramiko")
    if not len(logger.handlers):
        file_handler = logging.FileHandler(log_dir+'exec_paramiko.log')
        formatter = logging.Formatter(log_format)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
        logger.setLevel(logging.DEBUG)
        #logger.setLevel(logging.WARNING)

    logging.getLogger("exec_paramiko").setLevel(logging.INFO)

    # ptr_ means paramiko.transport

    ptr_logger = logging.getLogger("paramiko.transport")
    if not len(ptr_logger.handlers):
        file_handler = logging.FileHandler(log_dir+'exec_paramiko.transport.log')
        formatter = logging.Formatter(log_format)
        file_handler.setFormatter(formatter)
        ptr_logger.addHandler(file_handler)
        ptr_logger.setLevel(logging.WARNING)


    logger.debug("Start")

    if rem_cmd is None:
        err_str = "rem_cmd is None. Skip"
        logger.warning(err_str)
        out_str = ""
    else:
        logger.info("rem_cmd={0}".format(rem_cmd))

        home_dir = expanduser("~")
        k = paramiko.RSAKey.from_private_key_file(home_dir + "/.ssh/id_rsa")

        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            out_str = ''
            err_str = ''
            client.connect(hostname=rem_host, username=rem_user, pkey=k, port=rem_port)
        except BaseException as e:
            err_str = "client.connect exception={0}".format(e)
            logger.exception(err_str)
        else:
            try:
                stdin, stdout, stderr = client.exec_command(rem_cmd)
            except BaseException as e:
                err_str = "client.exec_command exception={0}".format(e)
                logger.exception(err_str)
            else:
                logger.debug("exec_command completed")
                out_str = str(stdout.read()).strip()
                err_str = str(stderr.read()).strip()
                #logger.debug("out_str={0}".format(out_str))
                #logger.debug("err_str={0}".format(err_str))

                if '' != out_str:
                    logger.info("out_str={0}".format(out_str))
                if '' != err_str:
                    out_str += "ERROR: RC=" + err_str
                    logger.warning("output+error={0}".format(out_str))

        logger.debug("Finish")
        logger.info('================================')
        client.close()


    return out_str, err_str
