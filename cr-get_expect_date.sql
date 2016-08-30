-- Function: get_expect_date(integer)

-- DROP FUNCTION get_expect_date(integer);

CREATE OR REPLACE FUNCTION get_expect_date(ks integer)
  RETURNS character varying AS
$BODY$SELECT coalesce(min(to_char(ДатаОжидания, 'YYYY-MM-DD')), 'Ожидается на склад') AS result
	FROM arc_energo."Заказ" z
	JOIN arc_energo."СписокЗаказа" sz ON z."Заказ" = sz."Заказ"
	WHERE not coalesce(sz."Отменен",false) 
		AND  not coalesce(sz."Выполнен",false) 
		AND sz."Счет" IS NULL 
		AND  not coalesce(z."Отменен",false) 
		AND not coalesce(z."Выполнен",false) AND sz."Получен" IS NULL AND (z."Код" <> ALL (ARRAY[210463, 225073]))
		AND sz.КодСодержания = ks;
		
$BODY$
  LANGUAGE sql VOLATILE
  COST 100;
ALTER FUNCTION get_expect_date(integer)
  OWNER TO arc_energo;
COMMENT ON FUNCTION get_expect_date(integer) IS 'Возвращает ожидаемую дату прихода или фразу Ожидается на склад';
