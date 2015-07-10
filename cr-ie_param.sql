-- Function: devmod.ie_param(character varying, boolean, bit)

-- DROP FUNCTION devmod.ie_param(character varying, boolean, bit);

CREATE OR REPLACE FUNCTION devmod.ie_param(
    aname character varying,
    isnew boolean,
    amode bit)
  RETURNS character varying AS
$BODY$
SELECT ie_param_value FROM devmod.impex 
        WHERE ie_param_name = aname AND brand_new = isnew AND imp_mode = amode;

$BODY$
  LANGUAGE sql VOLATILE
  COST 100;
ALTER FUNCTION devmod.ie_param(character varying, boolean, bit)
  OWNER TO arc_energo;
