-- Function: devmod.fntr_export_notify()

-- DROP FUNCTION devmod.fntr_export_notify();

CREATE OR REPLACE FUNCTION devmod.fntr_export_log_BU()
  RETURNS trigger AS
$BODY$
DECLARE
  dev RECORD;
BEGIN
  -- экспорт на боевой сайт завершён успешно
  IF (OLD.exp_mod = OLD.exp_csv_status) AND (OLD.exp_site = 'kipspb.ru') AND (OLD.exp_status >= 1)
  THEN 
     RAISE E'Запрещено редактировать историю синхронизации.';
  ELSE
    SELECT * INTO dev FROM devmod.device WHERE dev_id = NEW.dev_id AND version_num = NEW.exp_version_num;
    IF NOT FOUND THEN 
       RAISE E'Не найден прибор dev_id=%, version_num=%.', NEW.dev_id, NEW.exp_version_num;
    ELSIF dev.ie_xml_id IS NULL AND NEW.exp_mod IN (1, 7) THEN
        NULL; -- permited combination, just pass
    ELSIF dev.ie_xml_id IS NOT NULL AND NEW.exp_mod IN (1, 4, 6, 7) THEN
        NULL; -- permited combination, just pass
    ELSE
       RAISE E'Этот режим экспорта не реализован ie_xml_id=%, exp_mod=%.', dev.ie_xml_id, NEW.exp_mod;
    END IF; -- NOT FOUND
  END IF;

  IF (OLD.exp_status <> NEW.exp_status) AND (NEW.exp_status = 1) -- смена статуса на 1
  THEN
     EXECUTE pg_notify('do_export', NEW.exp_id::VARCHAR);
  END IF;
  RETURN NEW;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
