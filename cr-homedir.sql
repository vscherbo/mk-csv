-- Function: public.homedir()

-- DROP FUNCTION public.homedir();

CREATE OR REPLACE FUNCTION public.homedir()
  RETURNS character varying AS
$BODY$
 from os.path import expanduser
 return expanduser("~")
$BODY$
  LANGUAGE plpython2u VOLATILE
  COST 100;
ALTER FUNCTION public.homedir()
  OWNER TO postgres;
