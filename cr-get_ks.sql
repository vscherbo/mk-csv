CREATE OR REPLACE FUNCTION get_ks(arg_mod_id character varying )
  RETURNS integer AS
$BODY$SELECT "КодСодержания" AS result 
FROM devmod.modifications
WHERE mod_id = arg_mod_id AND version_num = 1;
$BODY$
  LANGUAGE sql VOLATILE
  COST 100;
COMMENT ON FUNCTION get_ks(character varying) IS 'Возвращает КодСодержания, найденный  по идентификатору модификации';
