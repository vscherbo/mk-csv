-- Function: site()

-- DROP FUNCTION site();

CREATE OR REPLACE FUNCTION site()
  RETURNS character varying AS
$BODY$
#     Devel inet = '192.168.1.82';
#     Prod inet = '192.168.1.52';
import socket
from dns import reversename
from dns import resolver

loc_ip = socket.gethostbyname(socket.gethostname())

pg_ip = resolver.query('vm-pg', "A")[0].to_text()

if loc_ip == pg_ip:
  return 'kipspb.ru'
else:
  return 'kipspb-fl.arc.world'


"""
host_name = resolver.query(reversename.from_address(loc_host), "PTR")[0].target.to_text()
if host_name.find('devel') > 0:
  return 'kipspb-fl.arc.world'
else:
  return 'kipspb.ru'
"""
$BODY$
  LANGUAGE plpython2u VOLATILE
  COST 100;
