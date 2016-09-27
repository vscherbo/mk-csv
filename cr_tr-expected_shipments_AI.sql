CREATE TRIGGER "expected_shipments_AI"
  AFTER INSERT
  ON expected_shipments
  FOR EACH ROW
  EXECUTE PROCEDURE fntr_expected_shipments_notify();
