-- Function: fntr_stock_status_changed()

-- DROP FUNCTION fntr_stock_status_changed();

CREATE OR REPLACE FUNCTION fntr_stock_status_changed()
  RETURNS trigger AS
$BODY$DECLARE
    loc_problem varchar;

    loc_RETURNED_SQLSTATE varchar;
    loc_MESSAGE_TEXT varchar;
    loc_PG_EXCEPTION_DETAIL varchar;
    loc_PG_EXCEPTION_HINT varchar;
    loc_PG_EXCEPTION_CONTEXT varchar;
BEGIN
  BEGIN
    INSERT INTO stock_status_changed(stock_status_old, stock_status_new, ks) VALUES(OLD.stock_status, NEW.stock_status, NEW."КодСодержания");
/**    
  EXCEPTION  WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
    loc_RETURNED_SQLSTATE = RETURNED_SQLSTATE,
    loc_MESSAGE_TEXT = MESSAGE_TEXT,
    loc_PG_EXCEPTION_DETAIL = PG_EXCEPTION_DETAIL,
    loc_PG_EXCEPTION_HINT = PG_EXCEPTION_HINT,
    loc_PG_EXCEPTION_CONTEXT = PG_EXCEPTION_CONTEXT ;
    loc_problem = format(
                            'RETURNED_SQLSTATE=%s, 
                            MESSAGE_TEXT=%s, 
                            PG_EXCEPTION_DETAIL=%s, 
                            PG_EXCEPTION_HINT=%s, 
                            PG_EXCEPTION_CONTEXT=%s',
                            loc_RETURNED_SQLSTATE,
                            loc_MESSAGE_TEXT,
                            loc_PG_EXCEPTION_DETAIL,
                            loc_PG_EXCEPTION_HINT,
                            loc_PG_EXCEPTION_CONTEXT );

  
**/    
  END;
 
  RETURN NEW;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fntr_stock_status_changed()
  OWNER TO arc_energo;
