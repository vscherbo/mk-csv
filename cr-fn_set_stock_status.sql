--Select * FROM arc_energo.fn_set_stock_status(117101002, 't') f(cur integer, clc integer )
-- Function: fn_set_stock_status(integer)

-- DROP FUNCTION fn_set_stock_status(integer, boolean);

-- Пример вызова: Select * FROM arc_energo.fn_set_stock_status(110022036, 'f') f(cur integer, clc integer )

CREATE OR REPLACE FUNCTION arc_energo.fn_set_stock_status(ks integer, bmode boolean )
  RETURNS record AS 
$BODY$DECLARE
  rs RECORD;
  loc_stock_status INTEGER;
  clc_stock_status INTEGER;
  wh_free double precision;
  wh_reserve  double precision;
  go_free NUMERIC;
  go_reserve double precision;
  ie_name_modification character varying;
  -- dev_sinc boolean; 
BEGIN
   -- RAISE NOTICE  'Код Содержания =%', ks;
   
   -- получаем текущий статус склада
SELECT d.dev_name ||': '|| m.mod_id::character varying INTO ie_name_modification FROM devmod.device d JOIN devmod.modifications m 
ON (d.dev_id = m.dev_id  AND d.version_num = m.version_num)
WHERE m.КодСодержания = ks AND m.version_num =1;
--SELECT s.КодПрибора Is Null INTO dev_sinc FROM arc_energo.Содержание s 
--WHERE КодСодержания = ks;

IF FOUND THEN 	
	-- RAISE NOTICE  'Прибор синхронизирован';
   
	SELECT coalesce(s.stock_status,-1) INTO loc_stock_status FROM arc_energo.Содержание s 
	WHERE КодСодержания = ks;
   RAISE NOTICE  'Текущее состояние на складе=%', loc_stock_status;
   -- Обсчитать наличие Ясная, Выставка
   SELECT coalesce(Sum(k.Свободно),0) INTO  wh_free FROM arc_energo.Количество k 
   WHERE not Свободно =0 AND КодСклада IN (2,5)  AND КодСодержания = ks;
   
   -- RAISE NOTICE  'наличие на складе =%', wh_free;
	
   -- Считаем резервы по оплаченным счетам
   SELECT coalesce(Sum(Резерв),0) INTO wh_reserve FROM arc_energo.Резерв r WHERE КодСодержания = ks And КогдаСнял Is Null AND (SELECT coalesce(Sum(Сумма),0) FROM arc_energo.ОплатыНТУ s WHERE r.Счет=s.Счет )>0;
   -- RAISE NOTICE  'Оплаченные резервы=%', wh_reserve;
   
   IF wh_free - wh_reserve > 0 THEN
	-- устанавливаем состояние "Со склада"
	clc_stock_status =2;
	-- RAISE NOTICE  'Срок поставки = Со склада';
   ELSE 
	-- если товара на складе нет, проверяем заказы	
	SELECT coalesce(sum(sz."Количество"),0) INTO go_free
        FROM arc_energo."Заказ" z
        JOIN arc_energo."СписокЗаказа" sz ON z."Заказ" = sz."Заказ"
        WHERE not coalesce(sz."Отменен",false) 
		AND  not coalesce(sz."Выполнен",false) 
		AND sz."Счет" IS NULL 
		AND  not coalesce(z."Отменен",false) 
		AND not coalesce(z."Выполнен",false) AND sz."Получен" IS NULL AND (z."Код" <> ALL (ARRAY[210463, 225073]))
		AND sz.КодСодержания = ks;
	-- RAISE NOTICE  'Заказано =%', go_free;
	
	-- Считаем идущие резервы по оплаченным счетам
	SELECT coalesce(Sum(Резерв),0) INTO go_reserve FROM arc_energo.РезервИдущий r 
	WHERE КодСодержания = ks And КогдаСнял Is Null AND (SELECT coalesce(Sum(Сумма),0) FROM arc_energo.ОплатыНТУ s WHERE r.Счет=s.Счет )>0;
	-- RAISE NOTICE  'Оплаченные идущие резервы=%', go_reserve;

	IF go_free - go_reserve > 0 THEN
		-- устанавливаем состояние "Ожидается на склад"
	-- 	RAISE NOTICE  'Срок поставки = Ожидается на склад';
		clc_stock_status =1;
	ELSE
		-- товара нет в наличии, товар не заказан
		-- читаем срок поставки указанный для этого прибора
	-- 	RAISE NOTICE  'Товар отсутствует на складе';
		clc_stock_status =0;
	END IF;
   END IF;
   -- если stock_status изменился, обновить "Содержание"
   -- UPDATE "Содержание" SET 

   -- Ну и, собственно, обновляем статус состояния прибора на складе 
   IF bmode then
	IF Not loc_stock_status = clc_stock_status THEN
		UPDATE arc_energo.Содержание SET stock_status = clc_stock_status  WHERE КодСодержания =ks;
		-- INSERT INTO arc_energo.logerror (num, desript, Дата) VALUES (Cast(ks as character varying(10)),ie_name_modification, now());
	else 
		RAISE NOTICE  'Обновления не произошло.';
	END IF;
   INSERT INTO arc_energo.logerror (num, desript, operation, Дата) VALUES (Cast(ks as character varying(10)),ie_name_modification,loc_stock_status||'->'||clc_stock_status::character varying(50), now());	
   END IF;   
   RAISE NOTICE  'Обновление=% Cтатусы %->%  % ', bmode, loc_stock_status, clc_stock_status, ie_name_modification;
ELSE
   RAISE NOTICE  'Обновления не произошло. Прибор не синхронизирован';
END IF;

SELECT * INTO rs FROM (SELECT loc_stock_status, clc_stock_status) as t1;

RETURN rs;
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION arc_energo.fn_set_stock_status(integer, boolean)
  OWNER TO arc_energo;
COMMENT ON FUNCTION arc_energo.fn_set_stock_status(integer, boolean) IS 'Изменяет Содержание.stock_status, если изменился';
