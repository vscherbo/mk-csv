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

    loc_mod_id VARCHAR;
    loc_mod_name VARCHAR;
    loc_time_delivery VARCHAR;
BEGIN
  SELECT mod_id, dev_name ||': '||mod_id AS mod_name INTO loc_mod_id, loc_mod_name
        FROM devmod.modifications m, devmod.device d
        WHERE NEW."КодСодержания" = "КодСодержания"
        AND m.version_num = 1
        AND d.version_num = 1
        AND d.ie_xml_id_dt IS NOT NULL
        AND d.dev_id = m.dev_id;
  IF FOUND THEN
    IF NEW.stock_status = 0 THEN -- под заказ
        loc_time_delivery := devmod.get_def_time_delivery(loc_mod_id); 
    ELSIF NEW.stock_status = 1 THEN -- заказан
        loc_time_delivery := get_expect_date(NEW."КодСодержания");
    ELSIF NEW.stock_status = 2 THEN -- в наличии 
        loc_time_delivery := E'Со склада';
    END IF;
    INSERT INTO stock_status_changed(stock_status_old, stock_status_new, ks, mod_id, mod_name, time_delivery) 
         VALUES(OLD.stock_status, NEW.stock_status, NEW."КодСодержания", loc_mod_id, loc_mod_name, loc_time_delivery);
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
  ELSE
     RAISE NOTICE 'stock_status_changed, Не найден KS=%', NEW."КодСодержания";
  END IF;
 
  RETURN NEW;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fntr_stock_status_changed()
  OWNER TO arc_energo;
