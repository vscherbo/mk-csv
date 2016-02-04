-- Function: devmod.fn_mk_csv(integer)
-- Function: devmod.fn_mk_csv(integer)

-- DROP FUNCTION devmod.fn_mk_csv(integer);

CREATE OR REPLACE FUNCTION devmod.fn_mk_csv(IN aexp_id INTEGER)
  RETURNS VOID AS
$BODY$DECLARE
  model_name VARCHAR;
  res record;
  exp RECORD;
  res_exec RECORD;
  err_str VARCHAR;
  str_res VARCHAR;
  cmd VARCHAR;
  site VARCHAR;
  mods_section_id INTEGER;
  price_section_id INTEGER;
  dev_xml_id INTEGER;
  strFinInfoUpdateArgs VARCHAR;
  article_id INTEGER;
  device_mode bit(3) = B'001';
  modificators_mode bit(3) = B'010';
  price_mode bit(3) = B'100';
  flag_dev_new BOOLEAN;
  flag_mods_new BOOLEAN;
  flag_prices_new BOOLEAN;
  loc_xml_id INTEGER;
  loc_mod_single BOOLEAN; -- единственная модификация
  loc_prop674 INTEGER; -- Раздел с модификациями (ценами)
  loc_prop675 INTEGER; -- Модификаторы прибора
  strCatGroups VARCHAR;
  good_export_str VARCHAR;
  upd_str VARCHAR;
BEGIN
    SELECT * INTO exp FROM devmod.bx_export_log WHERE exp_id = aexp_id FOR UPDATE;
    -- IF exp IS NULL THEN RAISE 'exp_id=% not found in devmod.bx_export_log', aexp_id ; RETURN; END IF;
    IF NOT found THEN RAISE 'exp_id=% not found in devmod.bx_export_log', aexp_id ; RETURN; END IF;
    site := exp.exp_site;
    IF exp.exp_version_num <> 1 AND site = 'kipspb.ru' THEN
        RAISE 'Запрещённая комбинация version_num=% и site=%', exp.exp_version_num, site;
        RETURN;
    END IF;
    IF exp.exp_version_num <> 0 AND site = 'kipspb-fl.arc.world' THEN
        RAISE 'Запрещённая комбинация version_num=% и site=%', exp.exp_version_num, site;
        RETURN;
    END IF;
    
    -- for devmod.ie_param
    SELECT ie_xml_id, ip_prop674, ip_prop675, mod_single INTO loc_xml_id, loc_prop674, loc_prop675, loc_mod_single FROM devmod.device d
    WHERE d.dev_id = exp.dev_id AND d.version_num = exp.exp_version_num;
    IF NOT FOUND THEN 
       RAISE EXCEPTION 'Не найден прибор dev_id=%, version_num=%', exp.dev_id, exp.exp_version_num ;
       RETURN;    -- STOP
    END IF;
    
    IF loc_xml_id IS NULL THEN flag_dev_new := TRUE; ELSE flag_dev_new := FALSE; END IF;
    IF loc_prop674 IS NULL THEN flag_prices_new := TRUE; ELSE flag_prices_new := FALSE; END IF;
    IF loc_prop675 IS NULL THEN flag_mods_new := TRUE; ELSE flag_mods_new := FALSE; END IF;
    RAISE NOTICE 'flag_dev_new=%', flag_dev_new;
    RAISE NOTICE 'flag_mods_new=%', flag_mods_new;
    RAISE NOTICE 'flag_prices_new=%', flag_prices_new;

    IF ((exp.exp_mod::BIT(3) & modificators_mode) = modificators_mode) THEN -- modificators
        res := devmod.mk_csv_modificators(exp.exp_id);
        RAISE NOTICE 'mods_out_file=%', res.out_csv;
        RAISE NOTICE 'mods_model_name=%', res.out_model_name;
        IF (res.out_res != '') THEN RAISE 'Modificators out_res=%', res.out_res; END IF;
        
        cmd := 'scp -q '|| res.out_csv || ' uploader@' || site || ':upload/' || devmod.ie_param('csv_file', flag_mods_new, modificators_mode);
        str_res := public.shell(cmd);
        if (str_res != '') then RAISE 'Modificators cmd=%^result=[%]', cmd, str_res; END IF;

        -- TODO python paramiko.SSHClient()
        cmd := 'ssh uploader@' || site || ' sh ''$ARC_PATH/run-import-profile.sh '|| devmod.ie_param('import_profile', flag_mods_new, modificators_mode) || '''';
        str_res := public.shell(cmd);
        if (str_res != '') then RAISE 'Modificators cmd=%^result=[%]', cmd, str_res; END IF;

        -- только для модификаторов новых товаров
        IF flag_mods_new THEN
            -- cmd := 'ssh uploader@' || site || ' php -f ./get-modificators-ID.php '|| res.out_model_name;
            -- str_res := public.shell(cmd);
            cmd := E'php -f $ARC_PATH/get-modificators-ID.php '|| res.out_model_name;
            res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
            IF res_exec.err_str <> '' THEN RAISE 'Modificators cmd=%^err_str=[%]', cmd, res_exec.err_str; 
            ELSE str_res := res_exec.out_str;
            END IF;
            BEGIN
                mods_section_id := cast(str_res as integer);
                exception WHEN OTHERS 
                    THEN RAISE 'Modificators cmd=%^result=[%]', cmd, str_res; 
                END;
        ELSE mods_section_id := loc_prop675;
        END IF; -- flag_mods_new
        RAISE NOTICE 'mods_section_id=%', mods_section_id;

      exp.exp_csv_status := COALESCE( (exp.exp_csv_status::BIT(3) | modificators_mode)::INTEGER, modificators_mode::INTEGER);
    END IF;

  IF (exp.exp_mod::BIT(3) & price_mode = price_mode) THEN -- prices
    res := devmod.mk_csv_prices(exp.exp_id);
    RAISE NOTICE 'prices_out_file=%', res.out_csv;
    RAISE NOTICE 'prices_model_name=%', res.out_model_name;
    RAISE NOTICE 'prices_out_xml_id=%', res.out_xml_id;
    IF (res.out_res != '') THEN RAISE 'Prices out_res=%', res.out_res; END IF;

    IF flag_prices_new THEN
        cmd := E'php -f $ARC_PATH/del-price-section.php '|| COALESCE(res.out_model_name, '');
        res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
        IF res_exec.err_str <> '' THEN RAISE 'Prices cmd=%^err_str=[%]', cmd, res_exec.err_str; 
        END IF;
    ELSE -- existing prices section
        cmd := E'php -f $ARC_PATH/del-prices-before-import.php '|| COALESCE(res.out_xml_id, '');
        res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
        IF res_exec.err_str <> '' THEN RAISE 'Prices cmd=%^err_str=[%]', cmd, res_exec.err_str;
        END IF;
    END IF;

    cmd := 'scp -q '|| res.out_csv || ' uploader@' || site || ':upload/' || devmod.ie_param('csv_file', flag_prices_new, price_mode);
    str_res := public.shell(cmd);
    if (str_res != '') then RAISE 'Prices cmd=%^result=[%]', cmd, str_res; END IF;

    cmd := 'ssh uploader@' || site || ' sh ''$ARC_PATH/run-import-profile.sh '|| devmod.ie_param('import_profile', flag_prices_new, price_mode) || '''';
    str_res := public.shell(cmd);
    if (str_res != '') then RAISE 'Prices cmd=%^result=[%]', cmd, str_res; END IF;

    -- только для новых товаров
    IF flag_prices_new THEN
        -- fin-info-update будет вызвана в ветке device, т.к. для новых приборов цены должны экспортироваться вместе с прибором
        -- cmd := 'ssh uploader@' || site || ' php -f ./get-prices-ID.php '|| res.out_model_name;
        -- str_res := public.shell(cmd);
        cmd := E'php -f $ARC_PATH/get-prices-ID.php '|| res.out_model_name ;
        res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
        IF res_exec.err_str <> '' THEN RAISE 'get-prices cmd=%^err_str=[%]', cmd, res_exec.err_str; 
        ELSE str_res := res_exec.out_str;
        END IF;
        BEGIN
            price_section_id := cast(str_res as integer);
            exception WHEN OTHERS 
                THEN RAISE 'Prices cmd=%^result=[%]', cmd, str_res; 
        END;
    ELSE -- NOT flag_prices_new
        price_section_id := loc_prop674;
        -- TODO выделить в процедуру
        IF NOT (exp.exp_mod::BIT(3) & device_mode = device_mode) THEN -- если device не будет обновляться
            -- скопировано из ветки device
            -- cmd := 'ssh uploader@' || site || ' /usr/bin/php -f ./fin-info-update.php '|| res.out_model_name ;
            -- str_res := public.shell(cmd);
            strFinInfoUpdateArgs := ' ';
            IF (mods_section_id IS NOT NULL) THEN strFinInfoUpdateArgs := strFinInfoUpdateArgs || ' -m' || mods_section_id::VARCHAR; END IF;
            IF (price_section_id IS NOT NULL) THEN strFinInfoUpdateArgs := strFinInfoUpdateArgs || ' -p' || price_section_id::VARCHAR; END IF;
            RAISE NOTICE 'Price strFinInfoUpdateArgs=[%]', strFinInfoUpdateArgs;
            RAISE NOTICE 'Price res.out_model_name=[%]', res.out_model_name;
            -- cmd := '/usr/bin/ssh uploader@' || site || ' /usr/bin/php -f ./fin-info-update.php '|| res.out_model_name || strFinInfoUpdateArgs;
            cmd := E'php $ARC_PATH/fin-info-update-params.php -n'|| res.out_model_name || strFinInfoUpdateArgs ;
            res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
            IF res_exec.err_str <> '' THEN RAISE 'just prices fin-info-update cmd=%^err_str=[%]', cmd, res_exec.err_str; 
            ELSE str_res := res_exec.out_str;
            END IF;
            BEGIN
                dev_xml_id := cast(str_res as integer);
                exception WHEN OTHERS 
                    THEN RAISE 'just prices fin-info-update cmd=%^result=[%]', cmd, str_res; 
            END;
        END IF; -- если device не будет обновляться
    END IF; -- flag_prices_new
    RAISE NOTICE 'price_section_id=%', price_section_id;
    
    
    exp.exp_csv_status := COALESCE( (exp.exp_csv_status::BIT(3) | price_mode)::INTEGER, price_mode::INTEGER);
  END IF;

  IF (exp.exp_mod::BIT(3) & device_mode = device_mode) THEN -- device
    res := devmod.mk_csv_device(exp.exp_id);
    RAISE NOTICE 'dev_out_file=%', res.out_csv;
    RAISE NOTICE 'dev_model_name=%', res.out_model_name;
    IF (res.out_res != '') THEN RAISE 'Device out_res=%', res.out_res; END IF;

    cmd := '/usr/bin/scp -q '|| res.out_csv || ' uploader@' || site || ':upload/' || devmod.ie_param('csv_file', flag_dev_new, device_mode);
    RAISE NOTICE 'Device upload cmd=[%]', cmd;
    str_res := public.shell(cmd);    
    if (str_res != '') then RAISE 'Device cmd=%^result=[%]', cmd, str_res; END IF;

    cmd := '/usr/bin/ssh uploader@' || site || ' sh ''$ARC_PATH/run-import-profile.sh '|| devmod.ie_param('import_profile', flag_dev_new, device_mode) || '''';
    RAISE NOTICE 'Device import cmd=[%]', cmd;
    str_res := public.shell(cmd);
    if (str_res != '') then RAISE 'Device cmd=%^result=[%]', cmd, str_res; END IF;

    /*
    SELECT ' '|| bx_fld_value INTO strCatGroups FROM devmod.bx_export_csv WHERE exp_id = aexp_id AND bx_fld_name = 'bx_groups' ;
    cmd := '/usr/bin/ssh uploader@' || site || ' /usr/bin/php -f ./set-dev-groups.php '|| res.out_model_name || strCatGroups;
    str_res := public.shell(cmd);
    if position('ERROR' in str_res) > 0 then RAISE 'Device cmd=%^result=[%]', cmd, str_res; END IF;
    */
    
    strFinInfoUpdateArgs := ' ';
    IF (mods_section_id IS NOT NULL)
    THEN 
       strFinInfoUpdateArgs := strFinInfoUpdateArgs || ' -m' || mods_section_id::VARCHAR;
    ELSIF (loc_prop675 IS NOT NULL) THEN
       strFinInfoUpdateArgs := strFinInfoUpdateArgs || ' -m' || loc_prop675::VARCHAR;
    END IF;
    IF (price_section_id IS NOT NULL)
    THEN 
       strFinInfoUpdateArgs := strFinInfoUpdateArgs || ' -p' || price_section_id::VARCHAR;
    ELSIF (loc_prop674 IS NOT NULL) THEN
       strFinInfoUpdateArgs := strFinInfoUpdateArgs || ' -p' || loc_prop674::VARCHAR;
    END IF;
    
    RAISE NOTICE 'Device strFinInfoUpdateArgs=[%]', strFinInfoUpdateArgs;
    RAISE NOTICE 'Device res.out_model_name=[%]', res.out_model_name;
    cmd := E'php $ARC_PATH/fin-info-update-params.php';
    IF flag_dev_new THEN 
       cmd := cmd ||  ' -n'|| res.out_model_name || strFinInfoUpdateArgs;
    ELSE
       cmd := cmd ||  ' -i'|| loc_xml_id || strFinInfoUpdateArgs;
    END IF;

    IF cmd IS NULL THEN RAISE 'Device fin-info-update-params cmd IS NULL'; END IF;
    RAISE NOTICE 'Device fin-info-update-params cmd=[%]', cmd;
    res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
    IF res_exec.err_str <> '' THEN RAISE 'fin-info-update cmd=%^err_str=[%]', cmd, res_exec.err_str; 
    ELSE str_res := res_exec.out_str;
    END IF;
    /* 
    SELECT * INTO str_res, err_str FROM public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
    IF err_str <> '' THEN RAISE 'Device cmd=%^err_str=[%]', cmd, err_str; 
    END IF; */
    BEGIN
        dev_xml_id := cast(str_res as integer);
        exception WHEN OTHERS 
            THEN RAISE 'Device cmd=%^result=[%]', cmd, str_res; 
    END;
    RAISE NOTICE 'dev_xml_id=%', dev_xml_id;
    

    upd_str := '';
    IF flag_dev_new AND (exp.exp_mod::BIT(3) & device_mode = device_mode) -- xml_id is NULL и есть бит device_mode
    THEN
       upd_str := upd_str || 'ie_xml_id = '||dev_xml_id ||', ie_xml_id_dt = now(), ';
        -- UPDATE devmod.device SET  ie_xml_id = dev_xml_id, ie_xml_id_dt = now()
            -- WHERE exp.dev_id = dev_id AND exp.exp_version_num = version_num;
    END IF; -- flag_dev_new

    IF flag_mods_new AND (exp.exp_mod::BIT(3) & modificators_mode = modificators_mode) -- prop675 is NULL и есть бит modificators_mode
    THEN
       upd_str := upd_str || 'ip_prop675 = ' || mods_section_id || ', ';
       --UPDATE devmod.device SET  ip_prop675 = mods_section_id
         -- WHERE exp.dev_id = dev_id AND exp.exp_version_num = version_num;
    END IF; -- flag_mods_new

    IF flag_prices_new AND (exp.exp_mod::BIT(3) & price_mode = price_mode) -- prop674 is NULL и есть бит price_mode
    THEN
       upd_str := upd_str || 'ip_prop674 = ' || price_section_id || ', ';
       --UPDATE devmod.device SET  ip_prop674 = price_section_id
           -- WHERE exp.dev_id = dev_id AND exp.exp_version_num = version_num;
    END IF; -- flag_prices_new

/**/
    RAISE NOTICE 'upd_str=%', upd_str;
    IF char_length(upd_str)>0 THEN
       -- delete last comma
        upd_str := 'UPDATE devmod.device SET ' || TRIM(trailing ', ' from upd_str) || 
                   ' WHERE dev_id = ' || exp.dev_id || ' AND version_num = ' || exp.exp_version_num || ';';
        RAISE NOTICE 'UPDATE device=%', upd_str;
        EXECUTE upd_str;
    END IF; -- do_update_flag
/**/
        
    exp.exp_csv_status := COALESCE( (exp.exp_csv_status::BIT(3) | device_mode)::INTEGER, device_mode::INTEGER);
    -- exp.exp_csv_status := COALESCE( (exp.exp_csv_status | device_mode), device_mode);
  END IF; -- device

  -- DEBUG flush memcache
  /*
  IF 'kipspb-fl.arc.world' = site THEN
  */
     res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, '/usr/bin/php $ARC_PATH/test-flush-memcache.php');
     IF res_exec.err_str <> '' THEN RAISE 'flush-memcache cmd=%^err_str=[%]', cmd, res_exec.err_str; 
     ELSE str_res := res_exec.out_str;
     END IF;
  /*
  END IF;
  */

    -- put an Article about finish of export
  good_export_str := 'Завершён экспорт модели ' || res.out_model_name || ' на сайт ' || site || ' (exp_id='||aexp_id|| ')' ;
  WITH inserted AS (
        INSERT INTO "Статьи"("Содержание", "ДатаСтатьи", "Автор") 
        VALUES (good_export_str, clock_timestamp(), 0)
        RETURNING "НомерСтатьи"
  )
  SELECT "НомерСтатьи" INTO article_id FROM inserted;
  INSERT INTO "Задания"("НомерСтатей", "Кому", "Прочел") VALUES (article_id, exp.exp_creator, TRUE);

  UPDATE devmod.bx_export_log SET exp_csv_status = exp.exp_csv_status, exp_result = good_export_str, exp_finish_dt = clock_timestamp() WHERE exp_id = aexp_id;
  
  RETURN;
END$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION devmod.fn_mk_csv(integer)
  OWNER TO arc_energo;
