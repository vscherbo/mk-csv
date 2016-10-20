-- Function: resend_to_site_stock_status(integer)

-- DROP FUNCTION resend_to_site_stock_status(integer);

CREATE OR REPLACE FUNCTION resend_to_site_stock_status(do_status integer)
  RETURNS void AS
$BODY$
DECLARE
   chg RECORD;
BEGIN
   IF 1 = do_status THEN return; end IF; -- ignore status 1 (sent)
   IF -1 = do_status THEN return; end IF; -- ignore status -1 (blocked)
   
   FOR chg IN SELECT * FROM stock_status_changed WHERE change_status = do_status LOOP
      RAISE NOTICE 'Resent stock_status: dt_change=%, KS=%, mod_id=%, qnt=%', chg.dt_change, chg.ks, chg.mod_id, quote_nullable(chg.qnt) ;
      -- EXECUTE pg_notify('do_single', chg.mod_id || '^' || chg.time_delivery::VARCHAR || '^' || chg.id::VARCHAR);
      EXECUTE pg_notify('do_single', concat_ws('^', chg.mod_id, chg.time_delivery::VARCHAR, chg.id::VARCHAR, COALESCE(chg.qnt::VARCHAR,'')));
   END LOOP;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION resend_to_site_stock_status(integer)
  OWNER TO arc_energo;
