-- Function: get_mod_id(integer)

-- DROP FUNCTION get_mod_id(integer);

CREATE OR REPLACE FUNCTION get_mod_id(ks integer)
  RETURNS character varying AS
$BODY$SELECT mod_id AS result 
FROM devmod.modifications
WHERE "КодСодержания" = ks AND version_num = 1;
$BODY$
  LANGUAGE sql VOLATILE
  COST 100;
ALTER FUNCTION get_mod_id(integer)
  OWNER TO arc_energo;
COMMENT ON FUNCTION get_mod_id(integer) IS 'Возвращает идентификатор модификации, найденный по КодуСодержания';
