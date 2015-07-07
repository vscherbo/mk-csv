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
  loc_prop674 INTEGER; -- Раздел с модификациями (ценами)
  loc_prop675 INTEGER; -- Модификаторы прибора
  strCatGroups VARCHAR;
  good_export_str VARCHAR;
BEGIN
    -- site := site();
    SELECT * INTO exp FROM devmod.bx_export_log WHERE exp_id = aexp_id FOR UPDATE;
    -- IF exp IS NULL THEN RAISE 'exp_id=% not found in devmod.bx_export_log', aexp_id ; RETURN; END IF;
    IF NOT found THEN RAISE 'exp_id=% not found in devmod.bx_export_log', aexp_id ; RETURN; END IF;
    site := exp.exp_site;
    IF site != 'kipspb2.arc.world' THEN -- DEBUG
        RAISE 'Запрещённый сайт=%', site;
        RETURN;
    END IF;
    
    -- for devmod.ie_param
    SELECT ie_xml_id, ip_prop674, ip_prop675 INTO loc_xml_id, loc_prop674, loc_prop675 FROM devmod.device d
    WHERE d.dev_id = exp.dev_id AND d.version_num = exp.exp_version_num;
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
        cmd := 'ssh uploader@' || site || ' sh ./run-import-profile.sh '|| devmod.ie_param('import_profile', flag_mods_new, modificators_mode);
        str_res := public.shell(cmd);
        if (str_res != '') then RAISE 'Modificators cmd=%^result=[%]', cmd, str_res; END IF;

        -- только для новых товаров
        IF flag_mods_new THEN
            -- cmd := 'ssh uploader@' || site || ' php -f ./get-modificators-ID.php '|| res.out_model_name;
            -- str_res := public.shell(cmd);
            cmd := 'php -f ./get-modificators-ID.php '|| res.out_model_name;
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
    IF (res.out_res != '') THEN RAISE 'Prices out_res=%', res.out_res; END IF;

    -- IF not flag_prices_new THEN
        -- cmd := 'ssh uploader@' || site || ' php -f ./del-prices-before-import.php '|| res.out_xml_id ;
        -- str_res := public.shell(cmd);
        cmd := 'php -f ./del-prices-before-import.php '|| COALESCE(res.out_xml_id, '') ;
        res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
        IF res_exec.err_str <> '' THEN RAISE 'Prices cmd=%^err_str=[%]', cmd, res_exec.err_str; 
        ELSE str_res := res_exec.out_str;
        END IF;
    -- END IF;

    cmd := 'scp -q '|| res.out_csv || ' uploader@' || site || ':upload/' || devmod.ie_param('csv_file', flag_prices_new, price_mode);
    str_res := public.shell(cmd);
    if (str_res != '') then RAISE 'Prices cmd=%^result=[%]', cmd, str_res; END IF;

    cmd := 'ssh uploader@' || site || ' sh ./run-import-profile.sh '|| devmod.ie_param('import_profile', flag_prices_new, price_mode);
    str_res := public.shell(cmd);
    if (str_res != '') then RAISE 'Prices cmd=%^result=[%]', cmd, str_res; END IF;

    -- только для новых товаров
    IF flag_prices_new THEN
        -- fin-info-update будет вызвана в ветке device, т.к. для новых приборов цены должны экспортироваться вместе с прибором
        -- cmd := 'ssh uploader@' || site || ' php -f ./get-prices-ID.php '|| res.out_model_name;
        -- str_res := public.shell(cmd);
        cmd := '/usr/bin/php -f ./get-prices-ID.php '|| res.out_model_name;
        res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
        IF res_exec.err_str <> '' THEN RAISE 'get-prices cmd=%^err_str=[%]', cmd, res_exec.err_str; 
        ELSE str_res := res_exec.out_str;
        END IF;
        BEGIN
            price_section_id := cast(str_res as integer);
            exception WHEN OTHERS 
                THEN RAISE 'Prices cmd=%^result=[%]', cmd, str_res; 
        END;
    ELSE price_section_id := loc_prop674;
    END IF; -- flag_prices_new
    RAISE NOTICE 'price_section_id=%', price_section_id;

    -- скопировано из ветки device
    -- cmd := 'ssh uploader@' || site || ' /usr/bin/php -f ./fin-info-update.php '|| res.out_model_name ;
    -- str_res := public.shell(cmd);
    strFinInfoUpdateArgs := ' ';
    IF (mods_section_id IS NOT NULL) THEN strFinInfoUpdateArgs := strFinInfoUpdateArgs || ' -m' || mods_section_id::VARCHAR; END IF;
    IF (price_section_id IS NOT NULL) THEN strFinInfoUpdateArgs := strFinInfoUpdateArgs || ' -p' || price_section_id::VARCHAR; END IF;
    RAISE NOTICE 'Price strFinInfoUpdateArgs=[%]', strFinInfoUpdateArgs;
    RAISE NOTICE 'Price res.out_model_name=[%]', res.out_model_name;
    -- cmd := '/usr/bin/ssh uploader@' || site || ' /usr/bin/php -f ./fin-info-update.php '|| res.out_model_name || strFinInfoUpdateArgs;
    cmd := '/usr/bin/php ./fin-info-update-params.php -n'|| res.out_model_name || strFinInfoUpdateArgs;
    res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
    IF res_exec.err_str <> '' THEN RAISE 'fin-info-update cmd=%^err_str=[%]', cmd, res_exec.err_str; 
    ELSE str_res := res_exec.out_str;
    END IF;
    BEGIN
        dev_xml_id := cast(str_res as integer);
        exception WHEN OTHERS 
            THEN RAISE 'fin-info-update cmd=%^result=[%]', cmd, str_res; 
    END;
    
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

    cmd := '/usr/bin/ssh uploader@' || site || ' sh ./run-import-profile.sh '|| devmod.ie_param('import_profile', flag_dev_new, device_mode);
    RAISE NOTICE 'Device import cmd=[%]', cmd;
    str_res := public.shell(cmd);
    if (str_res != '') then RAISE 'Device cmd=%^result=[%]', cmd, str_res; END IF;

    SELECT ' '|| bx_fld_value INTO strCatGroups FROM devmod.bx_export_csv WHERE exp_id = aexp_id AND bx_fld_name = 'bx_groups' ;
    cmd := '/usr/bin/ssh uploader@' || site || ' /usr/bin/php -f ./set-dev-groups.php '|| res.out_model_name || strCatGroups;
    str_res := public.shell(cmd);
    if position('ERROR' in str_res) > 0 then RAISE 'Device cmd=%^result=[%]', cmd, str_res; END IF;

    strFinInfoUpdateArgs := ' ';
    IF (mods_section_id IS NOT NULL) THEN strFinInfoUpdateArgs := strFinInfoUpdateArgs || ' -m' || mods_section_id::VARCHAR; END IF;
    IF (price_section_id IS NOT NULL) THEN strFinInfoUpdateArgs := strFinInfoUpdateArgs || ' -p' || price_section_id::VARCHAR; END IF;
    RAISE NOTICE 'Device strFinInfoUpdateArgs=[%]', strFinInfoUpdateArgs;
    RAISE NOTICE 'Device res.out_model_name=[%]', res.out_model_name;
    -- cmd := '/usr/bin/ssh uploader@' || site || ' /usr/bin/php -f ./fin-info-update.php '|| res.out_model_name || strFinInfoUpdateArgs;
    cmd := '/usr/bin/php ./fin-info-update-params.php -n'|| res.out_model_name || strFinInfoUpdateArgs;

    RAISE NOTICE 'Device fin-info-update-params cmd=[%]', cmd;
    -- str_res := public.shell(cmd);
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

    -- TODO single UPDATE
    IF flag_dev_new THEN
        UPDATE devmod.device SET  ie_xml_id = dev_xml_id, ie_xml_id_dt = now()
            WHERE exp.dev_id = dev_id AND exp.exp_version_num = version_num;
    END IF; -- flag_dev_new

    IF flag_mods_new THEN
        UPDATE devmod.device SET  ip_prop675 = mods_section_id
            WHERE exp.dev_id = dev_id AND exp.exp_version_num = version_num;
    END IF; -- flag_mods_new

    IF flag_prices_new THEN
        UPDATE devmod.device SET  ip_prop674 = price_section_id
            WHERE exp.dev_id = dev_id AND exp.exp_version_num = version_num;
    END IF; -- flag_dev_new
        
    exp.exp_csv_status := COALESCE( (exp.exp_csv_status::BIT(3) | device_mode)::INTEGER, device_mode::INTEGER);
    -- exp.exp_csv_status := COALESCE( (exp.exp_csv_status | device_mode), device_mode);
  END IF; -- device

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
