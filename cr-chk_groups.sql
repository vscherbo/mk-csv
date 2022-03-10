-- Function: devmod.chk_groups(character varying, character varying, character varying, integer)

-- DROP FUNCTION devmod.chk_groups(character varying, character varying, character varying, integer);

CREATE OR REPLACE FUNCTION devmod.chk_groups(
    devicename character varying,
    site character varying,
    username character varying DEFAULT 'uploader'::character varying,
    port integer DEFAULT 22,
    inactive boolean DEFAULT 'False')
  RETURNS record AS
$BODY$
DECLARE
  cmd varchar;
  err_str varchar;
  out_str varchar;
  res RECORD;
BEGIN
    devicename := quote_literal(devicename);
    cmd := 'php -f $ARC_PATH/chk-groups.php ' || devicename;
    if inactive then
        cmd := cmd || ' inactive';
    end if;
    res := public.exec_paramiko(site, port, username, cmd);
    RETURN res;
END;$BODY$
    LANGUAGE plpgsql VOLATILE
    COST 100;
ALTER FUNCTION devmod.chk_groups(character varying, character varying, character varying, integer)
    OWNER TO arc_energo;
COMMENT ON FUNCTION devmod.chk_groups(character varying, character varying, character varying, integer) IS 'Возвращает ветки каталога, в которых найден товар с заданным именем';
