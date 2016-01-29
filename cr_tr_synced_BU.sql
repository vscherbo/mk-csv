-- Trigger: tr_synced_BU on devmod.device

DROP TRIGGER "tr_synced_BU" ON devmod.device;

CREATE TRIGGER "tr_synced_BU"
  BEFORE UPDATE OF ie_xml_id, ie_xml_id_dt, ip_prop674, ip_prop675
  ON devmod.device
  FOR EACH ROW
  WHEN ((old.version_num > 0) 
        AND ((old.ie_xml_id IS NOT NULL)
             OR (old.ie_xml_id_dt IS NOT NULL)
             OR (old.ip_prop674 IS NOT NULL)
             OR (old.ip_prop675 IS NOT NULL)
            )
       )
  EXECUTE PROCEDURE devmod.fntr_off_device_update();
COMMENT ON TRIGGER "tr_synced_BU" ON devmod.device IS 'Предотвращает изменение полей, заполненных в результате синхронизации, для версий, отличных от ''в разработке''';
