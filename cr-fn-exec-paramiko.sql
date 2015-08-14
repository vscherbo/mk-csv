-- Function: public.exec_paramiko(character varying, integer, character varying, character varying)

-- DROP FUNCTION public.exec_paramiko(character varying, integer, character varying, character varying);

CREATE OR REPLACE FUNCTION public.exec_paramiko(
    IN rem_host character varying,
    IN rem_port integer,
    IN rem_user character varying,
    IN rem_cmd1 character varying,
    OUT out_str character varying,
    OUT err_str character varying)
  RETURNS record AS
$BODY$

 import paramiko
 from datetime import datetime
 flog = open("/tmp/shell.log", "a")
 flog.write("Start at " + str(datetime.now()) +'\n')
 rem_cmd = rem_cmd1

 if rem_cmd is None:
    rem_cmd = 'None str'
 flog.write("rem_cmd=" + rem_cmd +'\n')

 k = paramiko.RSAKey.from_private_key_file("/var/lib/pgsql/.ssh/id_rsa")

 client = paramiko.SSHClient()
 client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
 client.connect(hostname=rem_host, username=rem_user, pkey=k, port=rem_port)
 stdin, stdout, stderr = client.exec_command(rem_cmd)
 out_str = str(stdout.read()).strip()
 err_str = str(stderr.read()).strip()

 flog.write("out_str=" + out_str +'\n')
 flog.write("err_str=" + err_str +'\n')

 if '' != err_str:
     out_str += "ERROR: RC=" + err_str
 flog.write("output+errors=" + out_str +'\n')
 flog.write('================================\n')
 flog.close
 client.close()
 return out_str, err_str
$BODY$
  LANGUAGE plpython2u VOLATILE
  COST 100;
ALTER FUNCTION public.exec_paramiko(character varying, integer, character varying, character varying)
  OWNER TO postgres;
