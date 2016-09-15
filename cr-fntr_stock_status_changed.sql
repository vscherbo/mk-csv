-- Function: fntr_stock_status_changed()

-- DROP FUNCTION fntr_stock_status_changed();

CREATE OR REPLACE FUNCTION fntr_stock_status_changed()
  RETURNS trigger AS
$BODY$DECLARE

BEGIN
  fn_add_stock_status_changed(NEW."КодСодержания", OLD.stock_status, NEW.stock_status);
  RETURN NEW;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fntr_stock_status_changed()
  OWNER TO arc_energo;
