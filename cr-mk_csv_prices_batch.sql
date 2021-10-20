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
  loc_exp_result VARCHAR := '';
  loc_exp_status INTEGER := 1; -- успешно, если будут ошибки, устанавливаем в -1, -2, -3
  loc_batch_result VARCHAR := 'Были ошибки в пакетном экспорте';
  csv_filename VARCHAR;
  loc_who INTEGER;
  loc_title VARCHAR;
  loc_dt_created TIMESTAMP WITHOUT TIME ZONE;
  loc_article VARCHAR;
BEGIN
  -- check every exp has 
     -- already synced (not NULL device 's fileds: ie_xml_id, ip_prop674, ip_prop 675)
     -- same site
     -- same version

  PERFORM devmod.mk_csv_general(exp_id, 'devmod.bx_dict_ib30', price_mode::INTEGER, false) 
          FROM devmod.bx_export_log 
          WHERE exp_batch_id=abatch_id
          AND exp_status = 0; -- только не выгруженные 

  IF NOT FOUND THEN
     RETURN;
  END IF;

  SELECT exp_site into site 
         FROM devmod.bx_export_log 
          WHERE exp_batch_id=abatch_id LIMIT 1; 

 -- convert before import (remove IC_CODE0, IC_GROUP0)
  ALTER TABLE csv_ib30_tmp DROP COLUMN ic_code0;
  ALTER TABLE csv_ib30_tmp DROP COLUMN ic_group0;

  -- make csv-file
  csv_filename := public.homedir() || '/mk_csv_data/ib30-list.csv';
  str_res := mk_csv('SELECT * FROM csv_ib30_tmp', csv_filename);
  if (str_res != '') then RAISE 'mk_csv: str_res=[%]', str_res; END IF;
  DROP TABLE csv_ib30_tmp;

  -- copy csv-file to site
  str_res := public.scp(csv_filename, 'uploader', site, 'upload/import-update.csv');
  IF (str_res != 'OK') then RAISE 'scp: str_res=[%]', str_res; END IF;
  

 -- run import
 -- cmd := ' sh ''$ARC_PATH/run-import-profile.sh '|| devmod.ie_param('import_profile', FALSE, price_mode) || '''';
 cmd := 'sh $ARC_PATH/run-import-profile.sh 35';
 RAISE NOTICE 'Import prices cmd=[%]', cmd;
 /***/
 res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
 IF res_exec.err_str <> '' THEN 
    loc_exp_status := -1;
    loc_exp_result := res_exec.err_str;
    RAISE NOTICE 'Import prices cmd=%^err_str=[%]', cmd, res_exec.err_str; 
 END IF;
 IF res_exec.out_str <> '' THEN 
    loc_exp_status := -2;
    loc_exp_result := loc_exp_result || '/' || res_exec.out_str;
    RAISE NOTICE 'Import prices cmd=%^out_str=[%]', cmd, res_exec.out_str; 
 END IF;

 -- update fin info. file fin-info-update-list.csv is symlink to the just imported csv (see run-import-profile.sh)
 cmd := '/usr/bin/php $ARC_PATH/fin-info-update-list.php -f /home/uploader/upload/fin-info-update-list.csv ';
 res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
 IF res_exec.err_str <> '' THEN
    loc_exp_status := -3;
    loc_exp_result := loc_exp_result || '/' || res_exec.err_str;
    RAISE NOTICE 'fin-info-update-list cmd=%^err_str=[%]', cmd, res_exec.err_str; 
 END IF;
/***/


/** TODO **/
IF '' = loc_exp_result 
THEN
    loc_exp_result := quote_literal('Завершён экспорт в составе пакета batch_id=' || abatch_id);
    loc_batch_result := quote_literal('Завершён пакетный экспорт');
ELSE
    loc_batch_result := quote_literal('Ошибка пакетного экспорта');
    SELECT who, title, dt_created INTO loc_who, loc_title, loc_dt_created FROM bx_export_bat WHERE id=abatch_id;
    loc_article := format('Пакетный экспорт №%s %s от %s завершился с ошибкой:%s',
                           abatch_id, quote_literal(loc_title), loc_dt_created, loc_exp_result);
    PERFORM push_arc_article(loc_who, loc_article, 1);
    IF loc_who <> 124 THEN
        PERFORM push_arc_article(124, loc_article, 1); -- ВН
    END IF;
    loc_exp_result := quote_literal('Ошибка экспорта в составе пакета batch_id=' || abatch_id);
END IF;

FOR exp IN SELECT exp_id, dev_id, exp_mod, exp_version_num FROM devmod.bx_export_log WHERE exp_batch_id=abatch_id
LOOP
    upd_str := 'ie_xml_id_dt = clock_timestamp(), ip_prop674_dt = clock_timestamp()' ;
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

upd_str := 'UPDATE devmod.bx_export_bat SET ' || 
              'exp_result = ' || loc_batch_result ||
              ', dt_finished = clock_timestamp()' ||
              ', status = ' || loc_exp_status ||
              ' WHERE id = ' || abatch_id || ';' ;
RAISE NOTICE 'UPDATE bx_export_bat=%', upd_str;
EXECUTE upd_str;
/**/
  
END$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION devmod.mk_csv_prices_batch(integer)
  OWNER TO arc_energo;
