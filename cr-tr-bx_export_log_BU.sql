-- Trigger: bx_export_log_BU on devmod.bx_export_log

DROP TRIGGER "bx_export_log_BU" ON devmod.bx_export_log;

CREATE TRIGGER "bx_export_log_BU"
  BEFORE UPDATE
  ON devmod.bx_export_log
  FOR EACH ROW
  EXECUTE PROCEDURE devmod.fntr_export_log_BU();
