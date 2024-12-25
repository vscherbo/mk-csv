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
    RETURN NEW;
END;$function$
;
