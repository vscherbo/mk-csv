-- Function: devmod.fntr_off_device_update()

-- DROP FUNCTION devmod.fntr_off_device_update();

CREATE OR REPLACE FUNCTION devmod.fntr_off_device_update()
  RETURNS trigger AS
$BODY$
DECLARE
  wrong_op VARCHAR;
BEGIN
   wrong_op := E'\nie_xml_id(OLD/NEW)=' || COALESCE(OLD.ie_xml_id::VARCHAR, 'NULL') || '/' || COALESCE(NEW.ie_xml_id::VARCHAR, 'NULL')
               || E'\nie_xml_id_dt(OLD/NEW)=' || COALESCE(OLD.ie_xml_id_dt::VARCHAR, 'NULL') || '/' || COALESCE(NEW.ie_xml_id_dt::VARCHAR, 'NULL')
               || E'\nip_prop674(OLD/NEW)=' || COALESCE(OLD.ip_prop674::VARCHAR, 'NULL') || '/' || COALESCE(NEW.ip_prop674::VARCHAR, 'NULL')
               || E'\nip_prop675(OLD/NEW)=' || COALESCE(OLD.ip_prop675::VARCHAR, 'NULL') || '/' || COALESCE(NEW.ip_prop675::VARCHAR, 'NULL') 
               ;
   RAISE EXCEPTION E'Попытка обновить версию не ''в разработке'' %',  wrong_op;
   RETURN NEW;   
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION devmod.fntr_off_device_update()
  OWNER TO arc_energo;
COMMENT ON FUNCTION devmod.fntr_off_device_update() IS 'Возвращает ошибку при попытке изменить поля ie_xml_id, ie_xml_id_dt, ip_prop674, ip_prop675 для версий отличных от "в разработке"';
