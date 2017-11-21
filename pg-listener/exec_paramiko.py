#!/usr/bin/env python
# -*- coding: utf-8 -

import logging
from os.path import expanduser
import paramiko

def exec_paramiko(host, user, cmd, port=22):
    """
    OUT out_str character varying,
    OUT err_str character varying)
    """
    logging.getLogger(__name__).addHandler(logging.NullHandler())

    logging.debug("Start")

    if cmd is None:
        err_str = "cmd is None. Skip"
        logging.warning(err_str)
        out_str = ""
    else:
        pass
        # logging.info("cmd={0}".format(cmd))

        home_dir = expanduser("~")
        k = paramiko.RSAKey.from_private_key_file(home_dir + "/.ssh/id_rsa")

        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            out_str = ''
            err_str = ''
            client.connect(hostname=host, username=user, pkey=k, port=port)
        except BaseException as e:
            err_str = "client.connect exception={0}".format(e)
            logging.exception(err_str, exc_info=True)
            raise
        else:
            try:
                stdin, stdout, stderr = client.exec_command(cmd)
            except BaseException as e:
                err_str = "client.exec_command exception={0}".format(e)
                logging.exception(err_str, exc_info=True)
                raise
            else:
                logging.debug("exec_command completed")
                out_str = str(stdout.read()).strip()
                err_str = str(stderr.read()).strip()
                #logger.debug("out_str={0}".format(out_str))
                #logger.debug("err_str={0}".format(err_str))

                if '' != out_str:
                    logging.info("out_str={0}".format(out_str))
                if '' != err_str:
                    out_str += "ERROR: " + err_str
                    logging.warning("output+error={0}".format(out_str))
                    raise Exception(err_str)

        logging.debug("completed")
        client.close()


    return out_str, err_str
