-- Function: devmod.mk_csv_prices_batch(integer)

-- DROP FUNCTION devmod.mk_csv_prices_batch(integer);

CREATE OR REPLACE FUNCTION devmod.mk_csv_prices_batch(abatch_id integer)
  RETURNS void AS
$BODY$DECLARE
  str_res VARCHAR;
  res_exec RECORD;
  site VARCHAR;
  cmd VARCHAR;
  price_mode bit(3) = B'100';
BEGIN
  -- check every exp has 
     -- already synced (not NULL device 's fileds: ie_xml_id, ip_prop674, ip_prop 675)
     -- same site
     -- same version

  -- patch
  DROP TABLE csv_ib30_tmp;

  PERFORM devmod.mk_csv_general(exp_id, 'devmod.bx_dict_ib30', price_mode::INTEGER, false) 
          FROM devmod.bx_export_log 
          WHERE exp_batch_id=abatch_id; 

  SELECT exp_site into site 
         FROM devmod.bx_export_log 
          WHERE exp_batch_id=abatch_id LIMIT 1; 

 -- convert before import (remove IC_CODE0, IC_GROUP0)
  ALTER TABLE csv_ib30_tmp DROP COLUMN ic_code0;
  ALTER TABLE csv_ib30_tmp DROP COLUMN ic_group0;

  -- make csv-file
  str_res := mk_csv('SELECT * FROM csv_ib30_tmp', '/tmp/ib30-list.csv');
  if (str_res != '') then RAISE 'mk_csv: str_res=[%]', str_res; END IF;

  -- copy csv-file to site
  str_res := public.scp('/tmp/ib30-list.csv', 'uploader', site, 'upload/import-update.csv');
  IF (str_res != 'OK') then RAISE 'scp: str_res=[%]', str_res; END IF;
  

 -- run import
 -- cmd := ' sh ''$ARC_PATH/run-import-profile.sh '|| devmod.ie_param('import_profile', FALSE, price_mode) || '''';
 cmd := 'sh $ARC_PATH/run-import-profile.sh 35';
 RAISE NOTICE 'Import prices cmd=[%]', cmd;
 res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
 IF res_exec.err_str <> '' THEN RAISE 'Import prices cmd=%^err_str=[%]', cmd, res_exec.err_str; 
 END IF;
 IF res_exec.out_str <> '' THEN RAISE 'Import prices cmd=%^out_str=[%]', cmd, res_exec.out_str; 
 END IF;

 -- update fin info
 cmd := '/usr/bin/php $ARC_PATH/fin-info-update-list.php -f upload/import-update.csv';
 res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
 IF res_exec.err_str <> '' THEN RAISE 'fin-info-update-list cmd=%^err_str=[%]', cmd, res_exec.err_str; 
 END IF;

  
END$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION devmod.mk_csv_prices_batch(integer)
  OWNER TO arc_energo;
