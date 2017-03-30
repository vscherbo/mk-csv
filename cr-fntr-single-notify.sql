-- Function: fntr_single_notify()

-- DROP FUNCTION fntr_single_notify();

CREATE OR REPLACE FUNCTION fntr_single_notify()
  RETURNS trigger AS
$BODY$
BEGIN
  -- EXECUTE pg_notify('do_single', NEW.mod_id || '^' || NEW.time_delivery::VARCHAR || '^' || NEW.id::VARCHAR || '^' || COALESCE(NEW.qnt::VARCHAR, ''));
  EXECUTE pg_notify('do_single', format('%s^%s^%s^%s',NEW.mod_id, NEW.time_delivery, NEW.id, NEW.qnt));
  RETURN NEW;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fntr_single_notify()
  OWNER TO arc_energo;
