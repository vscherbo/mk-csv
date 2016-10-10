SELECT 
Case WHEN bx.ie_active AND d.ie_xml_id Is Null THEN 'Не выгружен' WHEN bx.ie_active AND Not d.ie_xml_id Is Null THEN 'Изменен, не выгружен' ELSE 'Нет на сайте' END Выгрузка,
d.dev_name_long, 
d.dev_name ИмяДляСайта, 
d.arc_name ИмяВБазе,
v.ie_name "Пост(НаСайте)", 
p.Предприятие "Пост(ВБазе)", 
CASE WHEN d.mod_single Then 'Да' ELSE 'Нет' END  ОднаМод, 
timedelivery Срок,
dm_discount_vendor СкидкаПоставщика,
dm_discount_diler СкидкаДилерам,
basic_price_rur БазЦена,
dm_valuta Валюта
FROM devmod.device d JOIN devmod.bx_vendor v ON d.vendor_id = v.ie_xml_id
LEFT JOIN Предприятия p ON d.Поставщик = p.Код
Left Join (SELECT ie_name, ie_active FROM devmod.bx_dev GROUP BY ie_name, ie_active) bx ON d.dev_name = bx.ie_name
WHERE (d.ie_xml_id Is Null Or d.ie_xml_id_dt Is Null) AND version_num = 1 AND coalesce(bx.ie_active,'t');
--WHERE ie_active Is true
--(bx.ie_active Is True Or bx.ie_active Is Null)