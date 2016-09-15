-- Function: devmod.get_def_time_delivery(character varying)

-- DROP FUNCTION devmod.get_def_time_delivery(character varying);

CREATE OR REPLACE FUNCTION devmod.get_def_time_delivery(modid character varying)
  RETURNS character varying AS
$BODY$DECLARE 
loc_def_delivery_time VARCHAR;
mod RECORD;
BEGIN
  -- выбираем срок поставки из модификации
  SELECT * INTO mod
        FROM devmod.modifications
        WHERE mod_id = modid
        AND version_num = 1;

  IF NOT FOUND THEN -- mod_id не найден
     loc_def_delivery_time := 'modification not found';
  ELSIF mod.mod_delivery_time IS NULL OR mod.mod_delivery_time = ''
  THEN -- если не задан в модификации, берём из прибора   
     SELECT timedelivery INTO loc_def_delivery_time 
        FROM devmod.device
        WHERE dev_id = mod.dev_id
        AND version_num = 1;
     IF NOT FOUND THEN -- прибор для этой модификации не найден
        loc_def_delivery_time := 'device not found';
     END IF;
  ELSE
    loc_def_delivery_time := mod.mod_delivery_time;
  END IF;
  
  RETURN loc_def_delivery_time;
  -- RETURN COALESCE(loc_def_delivery_time, 'value not found');
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION devmod.get_def_time_delivery(character varying)
  OWNER TO arc_energo;
COMMENT ON FUNCTION devmod.get_def_time_delivery(character varying) IS 'Возвращает срок поставки для модификации по её идентификатору';
