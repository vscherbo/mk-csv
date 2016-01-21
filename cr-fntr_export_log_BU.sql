-- Function: devmod.fntr_export_notify()

-- DROP FUNCTION devmod.fntr_export_notify();

CREATE OR REPLACE FUNCTION devmod.fntr_export_log_BU()
  RETURNS trigger AS
$BODY$BEGIN
  -- экспорт на боевой сайт завершён успешно
  IF (OLD.exp_mod = OLD.exp_csv_status) AND (OLD.exp_site = 'kipspb.ru') AND (OLD.exp_status >= 1)
  THEN 
     RAISE E'Запрещено редактировать историю синхронизации.';
  ELSIF (OLD.exp_status <> NEW.exp_status) AND (NEW.exp_status = 1) -- смена статуса на 1
  THEN
     EXECUTE pg_notify('do_export', NEW.exp_id::VARCHAR);
  END IF;
  RETURN NEW;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
