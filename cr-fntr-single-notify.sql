-- DROP FUNCTION arc_energo.fntr_single_notify();

CREATE OR REPLACE FUNCTION arc_energo.fntr_single_notify()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
loc_calc NUMERIC;
loc_id integer;
BEGIN
    EXECUTE pg_notify('do_compute_single', format('%s',NEW.id));
    IF NEW.ks IS NOT NULL THEN
        PERFORM FROM ext.ozon_list WHERE NEW.ks = ks;
        IF FOUND THEN
            loc_calc := stock_pack_availability(NEW.ks);
            WITH inserted AS (INSERT INTO ozon_stock_changed(ssc_id, ks, qnt_ssc, qnt_calc)
                              VALUES (NEW.id, NEW.ks, NEW.qnt, loc_calc)
                              RETURNING id)
            SELECT id INTO loc_id FROM inserted;
            EXECUTE pg_notify('do_ozon_item', format('%s^%s^%s', NEW.ks, loc_calc, loc_id));
        END IF;    
    END IF;    
    RETURN NEW;
END;$function$
;
