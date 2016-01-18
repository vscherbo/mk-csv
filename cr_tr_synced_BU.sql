-- Trigger: tr_synced_BU on devmod.device

-- DROP TRIGGER "tr_synced_BU" ON devmod.device;

CREATE TRIGGER "tr_synced_BU"
  BEFORE UPDATE OF ie_xml_id, ie_xml_id_dt, ip_prop674, ip_prop675
  ON devmod.device
  FOR EACH ROW
  WHEN ((old.version_num > 0))
  EXECUTE PROCEDURE devmod.fntr_off_device_update();
COMMENT ON TRIGGER "tr_synced_BU" ON devmod.device IS 'Предотвращает изменение полей, заполненных в результате синхронизации, для версий, отличных от ''в разработке''';
