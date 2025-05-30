-- CONNECTION: name=PROD
\echo 'Синхронизованные приборы со снятым флагом активности на сайте'
\echo

SELECT b.ie_xml_id id,b.ip_prop474 Название,b.ie_name Модель,ip_prop657 Изменен
 FROM devmod.bx_dev b JOIN devmod.device d ON b.ie_xml_id = d.ie_xml_id
 WHERE d.version_num = 1 AND NOT b.ie_active;

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
	(SELECT ct.КодСодержания, 
		m.mod_id, 
		dev_name ||': '|| mod_id AS modname, 
		ct.Цена AS "Цена(сод.)", 
		vwЦены.ОтпускнаяЦена AS "Цена(Цены)", 
		m.mod_price::NUMERIC AS "Цена(devmod)",
		m.dev_id
       FROM arc_energo.Содержание ct
       JOIN arc_energo.vwЦены ON ct.КодСодержания = vwЦены.КодСодержания
       JOIN devmod.modifications m ON ct.КодСодержания = m.КодСодержания
       JOIN devmod.device d ON m.dev_id = d.dev_id
       JOIN bx_dev WHERE  
	WHERE m.version_num=1 AND d.version_num=1
	AND Not d.ie_xml_id Is Null) AS t1
LEFT JOIN devmod.bx_price ON t1.modname = bx_price.ie_name
WHERE NOT (t1."Цена(сод.)" = t1."Цена(Цены)" AND t1."Цена(сод.)" =t1."Цена(devmod)"::NUMERIC AND t1."Цена(сод.)" =cv_price::numeric)
AND t1.dev_id Not IN (SELECT d.dev_id
       FROM devmod.bx_dev b JOIN devmod.device d ON b.ie_xml_id = d.ie_xml_id
       WHERE d.version_num = 1 AND NOT b.ie_active);

