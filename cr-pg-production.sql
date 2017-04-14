CREATE OR REPLACE FUNCTION pg_production()
  RETURNS boolean AS
$BODY$
import socket
from dns import resolver

loc_ip = socket.gethostbyname(socket.gethostname())

pg_ip = resolver.query('vm-pg', "A")[0].to_text()

return loc_ip == pg_ip

$BODY$
  LANGUAGE plpython2u VOLATILE
  COST 100;
