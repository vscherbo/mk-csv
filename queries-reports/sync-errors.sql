\echo 'Синхронизованные приборы со снятым флагом активности на сайте'
\echo
SELECT b.ie_xml_id id, 
b.ip_prop474 Название,
b.ie_name Модель,
ip_prop657 Изменен 
FROM devmod.bx_dev b JOIN devmod.device d ON b.ie_xml_id = d.ie_xml_id 
WHERE d.version_num = 1 AND NOT b.ie_active;

\echo 'Расхождения в сроках поставки и количестве'
\echo
SELECT * FROM vrf_sync();

\echo 'Расхождения в ожидаемых поставках'
\echo
SELECT * FROM vrf_sync_shipments();

\echo 'Расхождения в ценах'
\echo
SELECT 
	t1.КодСодержания, 
	-- t1.mod_id, 
	t1.modname, 
	t1."Цена(сод.)", 
	t1."Цена(Цены)", 
	t1."Цена(devmod)", 
	bx_price.cv_price "На сайте"
FROM 
	(SELECT Содержание.КодСодержания, 
		modifications.mod_id, 
		dev_name ||': '|| mod_id AS modname, 
		Содержание.Цена AS "Цена(сод.)", 
		vwЦены.ОтпускнаяЦена AS "Цена(Цены)", 
		modifications.mod_price AS "Цена(devmod)",
		modifications.dev_id
	FROM arc_energo.Содержание 
	JOIN arc_energo.vwЦены ON Содержание.КодСодержания = vwЦены.КодСодержания 
	JOIN devmod.modifications ON Содержание.КодСодержания = modifications.КодСодержания 
	JOIN devmod.device ON modifications.dev_id = device.dev_id
	WHERE modifications.version_num=1 AND device.version_num=1 
	AND Not device.ie_xml_id Is Null) AS t1 
LEFT JOIN devmod.bx_price ON t1.modname = bx_price.ie_name
WHERE NOT (t1."Цена(сод.)" = t1."Цена(Цены)" AND t1."Цена(сод.)" =t1."Цена(devmod)" AND t1."Цена(сод.)" =cv_price)
AND t1.dev_id Not IN (SELECT d.dev_id
	FROM devmod.bx_dev b JOIN devmod.device d ON b.ie_xml_id = d.ie_xml_id 
	WHERE d.version_num = 1 AND NOT b.ie_active);
