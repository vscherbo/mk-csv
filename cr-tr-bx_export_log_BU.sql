-- Trigger: bx_export_log_BU on devmod.bx_export_log

-- DROP TRIGGER "bx_export_log_BU" ON devmod.bx_export_log;

CREATE TRIGGER "bx_export_log_BU"
  BEFORE UPDATE OF exp_status
  ON devmod.bx_export_log
  FOR EACH ROW
  WHEN (((new.exp_status <> old.exp_status) AND (new.exp_status = 1)))
  EXECUTE PROCEDURE devmod.fntr_export_notify();
