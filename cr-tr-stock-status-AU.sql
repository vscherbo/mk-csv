-- Trigger: tr_stock_status_AU on "Содержание"

-- DROP TRIGGER "tr_stock_status_AU" ON "Содержание";

CREATE TRIGGER "tr_stock_status_AU"
  AFTER UPDATE OF stock_status
  ON "Содержание"
  FOR EACH ROW
  WHEN (((new.stock_status <> old.stock_status) OR (old.stock_status IS NULL)))
  EXECUTE PROCEDURE fntr_stock_status_changed();
ALTER TABLE "Содержание" DISABLE TRIGGER "tr_stock_status_AU";
COMMENT ON TRIGGER "tr_stock_status_AU" ON "Содержание" IS 'Записывает изменения в таблицу stock_status_changed';
