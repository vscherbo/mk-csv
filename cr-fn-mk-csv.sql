-- Function: devmod.fn_mk_csv(integer)

-- DROP FUNCTION devmod.fn_mk_csv(integer);

CREATE OR REPLACE FUNCTION devmod.fn_mk_csv(IN aexp_id INTEGER)
  RETURNS VOID AS
$BODY$DECLARE
  model_name VARCHAR;
  res record;
  exp RECORD;
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
  flag_new BOOLEAN;
  loc_xml_id INTEGER;
  strCatGroups VARCHAR;
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
    SELECT ie_xml_id INTO loc_xml_id FROM devmod.device d
    WHERE d.dev_id = exp.dev_id AND d.version_num = exp.exp_version_num;
    IF loc_xml_id IS NULL THEN flag_new := TRUE; ELSE flag_new := FALSE; END IF;
    RAISE NOTICE 'flag_new=%', flag_new;

    IF ((exp.exp_mod::BIT(3) & modificators_mode) = modificators_mode) THEN -- modificators
        res := devmod.mk_csv_modificators(exp.exp_id);
        RAISE NOTICE 'mods_out_file=%', res.out_csv;
        RAISE NOTICE 'mods_model_name=%', res.out_model_name;
        IF (res.out_res != '') THEN RAISE 'Modificators out_res=%', res.out_res; END IF;
        
        cmd := 'scp -q '|| res.out_csv || ' uploader@' || site || ':upload/' || devmod.ie_param('csv_file', flag_new, modificators_mode);
        str_res := public.shell(cmd);
        if (str_res != '') then RAISE 'Modificators cmd=%^result=[%]', cmd, str_res; END IF;

        -- TODO python paramiko.SSHClient()
        cmd := 'ssh uploader@' || site || ' sh ./run-import-profile.sh '|| devmod.ie_param('import_profile', flag_new, modificators_mode);
        str_res := public.shell(cmd);
        if (str_res != '') then RAISE 'Modificators cmd=%^result=[%]', cmd, str_res; END IF;

        -- только для новых товаров
        IF flag_new THEN
            cmd := 'ssh uploader@' || site || ' php -f ./get-modificators-ID.php '|| res.out_model_name;
            str_res := public.shell(cmd);
            BEGIN
                mods_section_id := cast(str_res as integer);
                exception WHEN OTHERS 
                    THEN RAISE 'Modificators cmd=%^result=[%]', cmd, str_res; 
                END;
            RAISE NOTICE 'mods_section_id=%', mods_section_id;
        END IF; -- flag_new

      exp.exp_csv_status := COALESCE( (exp.exp_csv_status::BIT(3) | modificators_mode)::INTEGER, modificators_mode::INTEGER);
    END IF;

  IF (exp.exp_mod::BIT(3) & price_mode = price_mode) THEN -- prices
    res := devmod.mk_csv_prices(exp.exp_id);
    RAISE NOTICE 'prices_out_file=%', res.out_csv;
    RAISE NOTICE 'prices_model_name=%', res.out_model_name;
    IF (res.out_res != '') THEN RAISE 'Prices out_res=%', res.out_res; END IF;

    cmd := 'ssh uploader@' || site || ' php -f ./del-prices-before-import.php '|| res.out_xml_id ;
    str_res := public.shell(cmd);
    if (str_res != '') then RAISE 'Prices cmd=%^result=[%]', cmd, str_res; END IF;

    cmd := 'scp -q '|| res.out_csv || ' uploader@' || site || ':upload/' || devmod.ie_param('csv_file', flag_new, price_mode);
    str_res := public.shell(cmd);
    if (str_res != '') then RAISE 'Prices cmd=%^result=[%]', cmd, str_res; END IF;

    cmd := 'ssh uploader@' || site || ' sh ./run-import-profile.sh '|| devmod.ie_param('import_profile', flag_new, price_mode);
    str_res := public.shell(cmd);
    if (str_res != '') then RAISE 'Prices cmd=%^result=[%]', cmd, str_res; END IF;

    -- только для новых товаров
    IF flag_new THEN
        -- fin-info-update будет вызвана в ветке device, т.к. для новых приборов цены должны экспортироваться вместе с прибором
        cmd := 'ssh uploader@' || site || ' php -f ./get-prices-ID.php '|| res.out_model_name;
        str_res := public.shell(cmd);
        BEGIN
            price_section_id := cast(str_res as integer);
            exception WHEN OTHERS 
                THEN RAISE 'Prices cmd=%^result=[%]', cmd, str_res; 
        END;
        RAISE NOTICE 'price_section_id=%', price_section_id;
    ELSE
        -- скопировано из ветки device
        cmd := 'ssh uploader@' || site || ' /usr/bin/php -f ./fin-info-update.php '|| res.out_model_name ;
        str_res := public.shell(cmd);
        BEGIN
            dev_xml_id := cast(str_res as integer);
            exception WHEN OTHERS 
                THEN RAISE 'fin-info-update cmd=%^result=[%]', cmd, str_res; 
        END;
    END IF; -- flag_new
    
    exp.exp_csv_status := COALESCE( (exp.exp_csv_status::BIT(3) | price_mode)::INTEGER, price_mode::INTEGER);
  END IF;

  IF (exp.exp_mod::BIT(3) & device_mode = device_mode) THEN -- device
    res := devmod.mk_csv_device(exp.exp_id);
    RAISE NOTICE 'dev_out_file=%', res.out_csv;
    RAISE NOTICE 'dev_model_name=%', res.out_model_name;
    IF (res.out_res != '') THEN RAISE 'Device out_res=%', res.out_res; END IF;

    cmd := '/usr/bin/scp -q '|| res.out_csv || ' uploader@' || site || ':upload/' || devmod.ie_param('csv_file', flag_new, device_mode);
    RAISE NOTICE 'Device upload cmd=[%]', cmd;
    str_res := public.shell(cmd);    
    if (str_res != '') then RAISE 'Device cmd=%^result=[%]', cmd, str_res; END IF;

    cmd := '/usr/bin/ssh uploader@' || site || ' sh ./run-import-profile.sh '|| devmod.ie_param('import_profile', flag_new, device_mode);
    RAISE NOTICE 'Device import cmd=[%]', cmd;
    str_res := public.shell(cmd);
    if (str_res != '') then RAISE 'Device cmd=%^result=[%]', cmd, str_res; END IF;

    SELECT ' '|| bx_fld_value INTO strCatGroups FROM devmod.bx_export_csv WHERE exp_id = aexp_id AND bx_fld_name = 'bx_groups' ;
    cmd := '/usr/bin/ssh uploader@' || site || ' /usr/bin/php -f ./set-dev-groups.php '|| res.out_model_name || strCatGroups;
    str_res := public.shell(cmd);
    if position('ERROR' in str_res) > 0 then RAISE 'Device cmd=%^result=[%]', cmd, str_res; END IF;

    IF flag_new THEN
        strFinInfoUpdateArgs := ' ';
        IF (mods_section_id IS NOT NULL) THEN strFinInfoUpdateArgs := strFinInfoUpdateArgs || ' ' || mods_section_id::VARCHAR; END IF;
        IF (price_section_id IS NOT NULL) THEN strFinInfoUpdateArgs := strFinInfoUpdateArgs || ' ' || price_section_id::VARCHAR; END IF;
        RAISE NOTICE 'Device strFinInfoUpdateArgs=[%]', strFinInfoUpdateArgs;
        RAISE NOTICE 'Device res.out_model_name=[%]', res.out_model_name;
        cmd := '/usr/bin/ssh uploader@' || site || ' /usr/bin/php -f ./fin-info-update.php '|| res.out_model_name || strFinInfoUpdateArgs;
    ELSE
        cmd := '/usr/bin/ssh uploader@' || site || ' /usr/bin/php -f ./fin-info-update.php '|| res.out_model_name ;
    END IF;

    RAISE NOTICE 'Device fin-info-update cmd=[%]', cmd;
    str_res := public.shell(cmd);

    BEGIN
        dev_xml_id := cast(str_res as integer);
        exception WHEN OTHERS 
            THEN RAISE 'Device cmd=%^result=[%]', cmd, str_res; 
    END;
    RAISE NOTICE 'dev_xml_id=%', dev_xml_id;

    IF flag_new THEN
        UPDATE devmod.device 
            SET  ie_xml_id = dev_xml_id, ie_xml_id_dt = now()
            WHERE exp.dev_id = dev_id
                AND exp.exp_version_num = version_num;
    END IF; -- flag_new

    exp.exp_csv_status := COALESCE( (exp.exp_csv_status::BIT(3) | device_mode)::INTEGER, device_mode::INTEGER);
    -- exp.exp_csv_status := COALESCE( (exp.exp_csv_status | device_mode), device_mode);
  END IF; -- device

  UPDATE devmod.bx_export_log SET exp_csv_status = exp.exp_csv_status WHERE exp_id = aexp_id;
    -- put an Article about finish of export
  WITH inserted AS (
        INSERT INTO "Статьи"("Содержание", "ДатаСтатьи", "Автор") 
        VALUES ('Завершён экспорт модели ' || res.out_model_name || ' на сайт ' || site || ' (exp_id='||aexp_id|| ')', clock_timestamp(), 0)
        RETURNING "НомерСтатьи"
  )
  SELECT "НомерСтатьи" INTO article_id FROM inserted;
  INSERT INTO "Задания"("НомерСтатей", "Кому", "Прочел") VALUES (article_id, exp.exp_creator, TRUE);
    
  RETURN;
END$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION devmod.fn_mk_csv(integer)
  OWNER TO arc_energo;
