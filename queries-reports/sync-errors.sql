-- CONNECTION: name=PROD
\echo 'Синхронизованные приборы со снятым флагом активности на сайте'
\echo
-- SELECT b.ie_xml_id id,b.ip_prop474 Название,b.ie_name Модель,ip_prop657 Изменен
-- FROM devmod.bx_dev b JOIN devmod.device d ON b.ie_xml_id = d.ie_xml_id
-- WHERE d.version_num = 1 AND NOT b.ie_active;

SELECT * FROM vrf_sync_site_noactive();

\echo 'Расхождения в сроках поставки и количестве'
\echo
SELECT * FROM vrf_sync();

\echo 'Расхождения в ожидаемых поставках'
\echo
SELECT * FROM vrf_sync_shipments();

\echo 'ОШИБКА: текущая версия, прошла синхронизацию, не найдена на сайте'
\echo
SELECT * FROM vrf_sync_site_failure();

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
		Содержание.Цена::NUMERIC AS "Цена(сод.)", 
		vwЦены.ОтпускнаяЦена::NUMERIC AS "Цена(Цены)", 
		modifications.mod_price::NUMERIC AS "Цена(devmod)",
		modifications.dev_id
       FROM arc_energo.Содержание
       JOIN arc_energo.vwЦены ON Содержание.КодСодержания = vwЦены.КодСодержания
       JOIN devmod.modifications ON Содержание.КодСодержания = modifications.КодСодержания
       JOIN devmod.device ON modifications.dev_id = device.dev_id
	WHERE modifications.version_num=1 AND device.version_num=1
	AND Not device.ie_xml_id Is Null) AS t1
LEFT JOIN devmod.bx_price ON t1.modname = bx_price.ie_name
WHERE NOT (round(t1."Цена(сод.)"::NUMERIC,2) = round(t1."Цена(Цены)"::numeric,2) AND round(t1."Цена(сод.)"::NUMERIC,2) =round(t1."Цена(devmod)"::NUMERIC,2) AND round(t1."Цена(сод.)"::NUMERIC,2) =round(cv_price::numeric,2))
AND t1.dev_id Not IN (SELECT d.dev_id
       FROM devmod.bx_dev b JOIN devmod.device d ON b.ie_xml_id = d.ie_xml_id
       WHERE d.version_num = 1 AND NOT b.ie_active);
