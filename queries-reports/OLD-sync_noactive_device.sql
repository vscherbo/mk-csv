SELECT b.ie_xml_id id, 
b.ip_prop474 Название,
b.ie_name Модель,
ip_prop657 Изменен 
FROM devmod.bx_dev b JOIN devmod.device d ON b.ie_xml_id = d.ie_xml_id 
WHERE d.version_num = 1 AND NOT b.ie_active;
