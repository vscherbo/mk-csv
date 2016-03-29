-- Trigger: tr_stock_status_BU on "Содержание"

-- DROP TRIGGER "tr_stock_status_BU" ON "Содержание";

CREATE TRIGGER "tr_stock_status_BU"
  BEFORE UPDATE OF stock_status
  ON "Содержание"
  FOR EACH ROW
  EXECUTE PROCEDURE fntr_single_notify();
COMMENT ON TRIGGER "tr_stock_status_BU" ON "Содержание" IS 'Посылает сообщение do_single, если изменился stock_status';
