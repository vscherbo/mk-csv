-- View: vwsyncdev

-- DROP VIEW vwsyncdev;

CREATE OR REPLACE VIEW vwsyncdev AS 
 SELECT m."КодСодержания",
    d.dev_name,
    d."Поставщик",
    m.mod_id
   FROM devmod.modifications m,
    devmod.device d
  WHERE d.dev_id = m.dev_id AND d.version_num = m.version_num AND d.ie_xml_id IS NOT NULL AND m."КодСодержания" IS NOT NULL AND m.version_num = 1
UNION
 SELECT s."КодСодержания",
    d.ie_name AS dev_name,
    ( SELECT NULL::integer AS int4) AS "Поставщик",
    ( SELECT NULL::character varying AS "varchar") AS mod_id
   FROM dev_sinccat_arcbx s,
    devmod.bx_dev d
  WHERE s."Разбор" = 1 AND d.ie_xml_id = s.ie_xml_id AND d.ie_active = true;

ALTER TABLE vwsyncdev
  OWNER TO arc_energo;
