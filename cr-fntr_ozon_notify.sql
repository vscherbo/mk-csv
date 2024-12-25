-- DROP FUNCTION arc_energo.fntr_ozon_notify();

CREATE OR REPLACE FUNCTION arc_energo.fntr_ozon_notify()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
loc_calc NUMERIC;
loc_id INTEGER;
loc_elapsed INTEGER := 0;
BEGIN
    PERFORM FROM ext.ozon_list WHERE NEW.ks = ks;
    IF FOUND THEN
        loc_calc := stock_pack_availability(NEW.ks);
        WITH inserted AS (INSERT INTO ozon_stock_changed(ssc_id, ks, qnt_ssc, qnt_calc)
                          VALUES (NEW.id, NEW.ks, NEW.qnt, loc_calc)
                          RETURNING id)
        SELECT id INTO loc_id FROM inserted;

        SELECT extract(epoch from (now() - osc.dt_sent)) INTO loc_elapsed
        FROM ozon_stock_changed osc 
        WHERE osc.ks = NEW.ks AND osc.change_status = 99
        ORDER BY osc.id DESC LIMIT 1;

        EXECUTE pg_notify('do_ozon_item', format('%s^%s^%s^%s', NEW.ks, loc_calc, loc_id, loc_elapsed));
    END IF;    
    RETURN NEW;
END;$function$
;
