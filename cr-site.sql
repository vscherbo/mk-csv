CREATE OR REPLACE FUNCTION site()
  RETURNS character varying AS
$BODY$
DECLARE
loc_production boolean;
BEGIN
loc_production := pg_production();

IF loc_production THEN
  RETURN 'kipspb.ru';
ELSE
  -- RETURN 'kipspb-fl.arc.world';
  RETURN arc_const('devsite');
END IF;

END;$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;
