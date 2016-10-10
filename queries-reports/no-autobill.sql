SELECT "bx_order_Номер" AS "Заказ на сайте"
, dt_insert AS "Записан в БД"
-- , "Наименование"
, split_part("Наименование", ':', 1) AS "Модель"
, substring("Наименование" from ': *?([0-9]+)$') AS "Сайт_mod_id"
, mod_id
  FROM bx_order_item
  LEFT JOIN vwsyncdev ON trim(substring("Наименование" from ': *?([0-9]+)$')) = mod_id
  WHERE "bx_order_Номер" IN 
  (SELECT "Номер" FROM bx_order WHERE billcreated IN (2) AND dt_insert > now() - '1day'::INTERVAL)
  ORDER BY "bx_order_Номер";
