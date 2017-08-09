-- DROP FUNCTION resend_to_site_expected_shipment(do_status integer);

CREATE OR REPLACE FUNCTION resend_to_site_expected_shipment(do_status integer)
  RETURNS void AS
$BODY$
DECLARE
   chg RECORD;
   loc_mod_id VARCHAR;
BEGIN
IF 1 = do_status THEN return; end IF; -- ignore status 1 (sent)
IF -1 = do_status THEN return; end IF; -- ignore status -1 (blocked)
   
FOR chg IN SELECT * FROM expected_shipments WHERE status = do_status ORDER BY id LOOP
  loc_mod_id := get_mod_id(chg.ks);
  IF loc_mod_id IS NOT NULL THEN
      RAISE NOTICE 'Resent expected_shipment: dt_insert=%, KS=%, mod_id=%, expected=%', chg.dt_insert, chg.ks, loc_mod_id, quote_nullable(chg.expected) ;
      EXECUTE pg_notify('do_expected', concat_ws('^', loc_mod_id, chg.expected, chg.id));
  END IF;
END LOOP;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
