-- Function: devmod.chk_groups(character varying, character varying, character varying, integer)

-- DROP FUNCTION devmod.chk_groups(character varying, character varying, character varying, integer);

CREATE OR REPLACE FUNCTION devmod.chk_groups(
    devicename character varying,
    site character varying,
    username character varying DEFAULT 'uploader'::character varying,
    port integer DEFAULT 22)
  RETURNS record AS
$BODY$
DECLARE
  cmd varchar;
  err_str varchar;
  out_str varchar;
  res RECORD;
BEGIN
   devicename := quote_ident(devicename);
   IF (site = 'kipspb-fl.arc.world') THEN
      cmd := 'php -f ./chk-groups.php ' || devicename;
   ELSIF (site = 'kipspb.ru') THEN
      cmd := 'php -f ./bx-uploader/chk-groups.php ' || devicename;
   ELSE
      res := ('Недопустимое название сайта: ' || site, '' );
      cmd := 'none';
   END IF;

   IF cmd != 'none' THEN
      res := public.exec_paramiko(site, 22, 'uploader', cmd);
   END IF;

   RETURN res;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION devmod.chk_groups(character varying, character varying, character varying, integer)
  OWNER TO arc_energo;
COMMENT ON FUNCTION devmod.chk_groups(character varying, character varying, character varying, integer) IS 'Возвращает ветки каталога, в которых найден товар с заданным именем';
