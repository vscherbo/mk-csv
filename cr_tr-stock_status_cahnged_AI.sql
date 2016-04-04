-- Trigger: stock_status_cahnged_AI on stock_status_changed

-- DROP TRIGGER "stock_status_cahnged_AI" ON stock_status_changed;

CREATE TRIGGER "stock_status_cahnged_AI"
  AFTER INSERT
  ON stock_status_changed
  FOR EACH ROW
  EXECUTE PROCEDURE fntr_single_notify();
