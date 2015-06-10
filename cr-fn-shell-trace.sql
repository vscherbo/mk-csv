-- Function: shell(text)

DROP FUNCTION shell(VARCHAR);

CREATE OR REPLACE FUNCTION shell(IN acmd VARCHAR)
  RETURNS VARCHAR AS
$BODY$
 import subprocess
 from datetime import datetime
 flog = open("/tmp/shell.log", "a")
 flog.write("Start at " + str(datetime.now()) +'\n')
 # flog.write("acmd=" + acmd +'\n')
 cmd = acmd
 if cmd is None:
    cmd = 'None str'
 flog.write("cmd=" + cmd +'\n')
 proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
 #proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
 flog = open("/tmp/shell.log", "a")
 output1, errors1 = proc.communicate()
 flog.write("output1=" + str(output1) +'\n')
 flog.write("err=" + str(errors1) +'\n')
 if 0 != proc.returncode:
     output1 += "ERROR: RC=" + str(proc.returncode)
     if errors1 is not None:
        output1 += ", errmsg=" + errors1
 flog.write("output+errors=" + str(output1) +'\n')
 flog.write('================================\n')
 flog.close
 return output1
$BODY$
  LANGUAGE plpython2u VOLATILE
  COST 100;
