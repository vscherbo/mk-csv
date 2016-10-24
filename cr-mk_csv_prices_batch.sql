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
  exp RECORD;
  upd_str VARCHAR;
  loc_exp_result VARCHAR;
  loc_exp_status INTEGER := 1; -- успешно, если будут ошибки, сбрасываем в 0
  loc_batch_result VARCHAR := 'Были ошибки в пакетном экспорте';
BEGIN
  -- check every exp has 
     -- already synced (not NULL device 's fileds: ie_xml_id, ip_prop674, ip_prop 675)
     -- same site
     -- same version

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
  DROP TABLE csv_ib30_tmp;

  -- copy csv-file to site
  str_res := public.scp('/tmp/ib30-list.csv', 'uploader', site, 'upload/import-update.csv');
  IF (str_res != 'OK') then RAISE 'scp: str_res=[%]', str_res; END IF;
  

 -- run import
 -- cmd := ' sh ''$ARC_PATH/run-import-profile.sh '|| devmod.ie_param('import_profile', FALSE, price_mode) || '''';
 cmd := 'sh $ARC_PATH/run-import-profile.sh 35';
 RAISE NOTICE 'Import prices cmd=[%]', cmd;
 /***/
 res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
 IF res_exec.err_str <> '' THEN 
    loc_exp_status := 0;
    loc_exp_result := res_exec.err_str;
    RAISE 'Import prices cmd=%^err_str=[%]', cmd, res_exec.err_str; 
 END IF;
 IF res_exec.out_str <> '' THEN 
    loc_exp_status := 0;
    loc_exp_result := loc_exp_result || '/' || res_exec.out_str;
    RAISE 'Import prices cmd=%^out_str=[%]', cmd, res_exec.out_str; 
 END IF;

 -- update fin info
 cmd := '/usr/bin/php $ARC_PATH/fin-info-update-list.php -f upload/import-update.csv';
 res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
 IF res_exec.err_str <> '' THEN
    loc_exp_status := 0;
    loc_exp_result := loc_exp_result || '/' || res_exec.err_str;
    RAISE 'fin-info-update-list cmd=%^err_str=[%]', cmd, res_exec.err_str; 
 END IF;
/***/

/** TODO **/
IF loc_exp_result IS NULL
THEN
    loc_exp_result := quote_literal('Завершён экспорт в составе пакета batch_id=' || abatch_id);
    loc_batch_result := quote_literal('Завершён пакетный экспорт');
END IF;

FOR exp IN SELECT exp_id, dev_id, exp_mod, exp_version_num FROM devmod.bx_export_log WHERE exp_batch_id=abatch_id
LOOP
    upd_str := 'ie_xml_id_dt = now(), ip_prop674_dt = now()' ;
    upd_str := 'UPDATE devmod.device SET ' || upd_str || 
               ' WHERE dev_id = ' || exp.dev_id || ' AND version_num = ' || exp.exp_version_num || ';';
    RAISE NOTICE 'UPDATE device=%', upd_str;
    EXECUTE upd_str;

    upd_str := 'UPDATE devmod.bx_export_log SET ' || 
              'exp_csv_status = ' || exp.exp_mod ||
              ', exp_result = ' || loc_exp_result ||
              ', exp_finish_dt = clock_timestamp()' ||
              ', exp_status = ' || loc_exp_status ||
              ' WHERE exp_id = ' || exp.exp_id || ';' ;
    RAISE NOTICE 'UPDATE bx_export_log=%', upd_str;
    EXECUTE upd_str;
    
END LOOP;    
/**/

upd_str := 'UPDATE devmod.bx_export_bat SET ' || 
              'exp_result = ' || loc_batch_result ||
              ', dt_finished = clock_timestamp()' ||
              ', status = ' || loc_exp_status ||
              ' WHERE id = ' || abatch_id || ';' ;
RAISE NOTICE 'UPDATE bx_export_bat=%', upd_str;
EXECUTE upd_str;
  
END$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION devmod.mk_csv_prices_batch(integer)
  OWNER TO arc_energo;
