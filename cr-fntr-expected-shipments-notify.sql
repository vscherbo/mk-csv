-- Function: fntr_expected_shipments_notify()

-- DROP FUNCTION fntr_expected_shipments_notify();

CREATE OR REPLACE FUNCTION fntr_expected_shipments_notify()
  RETURNS trigger AS
$BODY$
DECLARE
  loc_mod_id INTEGER;
BEGIN
    loc_mod_id := get_mod_id(NEW.ks);
    IF loc_mod_id IS NOT NULL THEN
        EXECUTE pg_notify('do_expected', loc_mod_id || '^' || NEW.expected || '^' || NEW.id::VARCHAR);
    ELSE
        RAISE NOTICE 'mod_id for KS=% not found', NEW.ks;
    END IF;
    RETURN NEW;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fntr_expected_shipments_notify()
  OWNER TO arc_energo;
