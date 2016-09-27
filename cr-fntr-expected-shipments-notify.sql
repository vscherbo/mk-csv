-- Function: fntr_expected_shipments_notify()

-- DROP FUNCTION fntr_expected_shipments_notify();

CREATE OR REPLACE FUNCTION fntr_expected_shipments_notify()
  RETURNS trigger AS
$BODY$
BEGIN
  EXECUTE pg_notify('do_expected', NEW.mod_id || '^' || NEW.expected || '^' || NEW.id::VARCHAR);
  RETURN NEW;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fntr_expected_shipments_notify()
  OWNER TO arc_energo;
