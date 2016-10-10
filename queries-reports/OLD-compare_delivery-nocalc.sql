--OLD-compare_delivery-nocalc.sql
SELECT
	arc.КодСодержания,
	arc.mod_name, site.ie_name,
	CASE WHEN wh=2 THEN 'Со Склада' WHEN wh=1 THEN get_expect_date(arc.КодСодержания) ELSE arc.delivery END ВБазе,
	site.ip_prop110 НаСайте
FROM
(SELECT
	coalesce(m.mod_delivery_time,d.timedelivery) delivery,
	m.КодСодержания,
	dev_name ||': '|| m.mod_id as mod_name,
	m.dev_id,
	m.mod_id,
	s.stock_status wh,
	d.ie_xml_id
		--(Select clc FROM arc_energo.fn_set_stock_status(m.КодСодержания, 'f') f(cur integer, clc integer )) wh
FROM devmod.modifications m 
JOIN Содержание s ON m.КодСодержания=s.КодСодержания
JOIN devmod.device d on d.dev_id = m.dev_id AND d.version_num = m.version_num
WHERE Not m.КодСодержания Is Null AND m.version_num=1 AND Not d.ie_xml_id Is Null
) arc 
-- Выбрать вариант
--1 JOIN devmod.bx_price site ON to_number(arc.mod_id,'000000000000') = site.ip_prop109
JOIN devmod.bx_price site ON to_number(arc.mod_id,'000000000000') = site.ip_prop109
JOIN devmod.bx_dev ON site.ic_xml_id0 =to_number(bx_dev.ip_prop674,'000000')  AND bx_dev.ie_xml_id =arc.ie_xml_id
--2 JOIN devmod.bx_price site ON arc.mod_name = site.ie_name
WHERE 
NOT (
site.ip_prop110 = CASE WHEN wh=2 THEN 'Со Склада' WHEN wh=1 THEN get_expect_date(arc.КодСодержания) ELSE arc.delivery END
Or site.ip_prop110 = CASE WHEN wh=2 THEN 'Со Склада' WHEN wh=1 THEN 'Ожидается на склад' ELSE arc.delivery END
)

 AND arc.dev_id Not IN (SELECT d.dev_id
	FROM devmod.bx_dev b JOIN devmod.device d ON b.ie_xml_id = d.ie_xml_id 
	WHERE d.version_num = 1 AND NOT b.ie_active) ;
--SELECT get_expect_date(100000551)	