
CREATE OR REPLACE FUNCTION devmod.fntr_bx_export_batch_au ()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    PERFORM devmod.mk_csv_prices_batch(OLD.id);
RETURN NEW;
END;
$function$
;

