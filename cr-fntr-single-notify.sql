-- Function: fntr_single_notify()

-- DROP FUNCTION fntr_single_notify();

CREATE OR REPLACE FUNCTION fntr_single_notify()
  RETURNS trigger AS
$BODY$DECLARE
loc_mod_id VARCHAR;
BEGIN
  SELECT mod_id INTO loc_mod_id 
        FROM devmod.modifications
        WHERE NEW.ks = "КодСодержания"
        AND version_num = 1;
  IF FOUND THEN
     EXECUTE pg_notify('do_single', loc_mod_id || '^' || NEW.stock_status_new::VARCHAR || '^' || NEW.id::VARCHAR);
  ELSE -- debug
     RAISE NOTICE 'Не найдена запись в devmod.modifications с КС=% и version_num=1', NEW.ks;
  END IF;
  RETURN NEW;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fntr_single_notify()
  OWNER TO arc_energo;
