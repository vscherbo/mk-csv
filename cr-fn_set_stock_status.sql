-- Function: fn_set_stock_status(integer, boolean)

-- DROP FUNCTION fn_set_stock_status(integer, boolean);

CREATE OR REPLACE FUNCTION fn_set_stock_status(ks integer, bmode boolean)
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
	--Select * FROM arc_energo.fn_set_stock_status(117101002, 't') f(cur integer, clc integer )
	-- RAISE NOTICE  'Код Содержания =%', ks;
   
   -- получаем текущий статус склада
-- Отключено в День Космонавтики. Функция работает по всей таблице Код содержания-------------------------
-- SELECT d.dev_name ||': '|| m.mod_id::character varying INTO ie_name_modification FROM devmod.device d JOIN devmod.modifications m 
-- ON (d.dev_id = m.dev_id  AND d.version_num = m.version_num)
-- WHERE m.КодСодержания = ks AND m.version_num =1;
--SELECT s.КодПрибора Is Null INTO dev_sinc FROM arc_energo.Содержание s 
--WHERE КодСодержания = ks;

-- IF FOUND THEN -- Отключено в День Космонавтики --------------------------------------------------
-- RAISE NOTICE  'Прибор синхронизирован';

-- Предыдущий статус склада    
SELECT coalesce(s.stock_status,-1) INTO loc_stock_status FROM arc_energo.Содержание s 
WHERE КодСодержания = ks;
-- RAISE NOTICE  'Текущее состояние на складе=%', loc_stock_status;

-- Обсчитать наличие на складе
SELECT coalesce(Sum(k.Свободно),0) INTO  wh_free FROM arc_energo.Количество k
WHERE not Свободно =0 AND NOT КодСклада IN (1,3,8,9,10)  AND КодСодержания = ks;
-- исключаем 1 политех, 3 Москва, 8 Казахстан, 9 Нестандарт, 10  ремонт
-- RAISE NOTICE  'наличие на складе =%', wh_free;
	
-- Считаем резервы по оплаченным счетам
SELECT coalesce(Sum(Резерв),0) INTO wh_reserve FROM arc_energo.Резерв r 
WHERE Not СтатусРезерва=3 
AND КодСодержания = ks 
And КогдаСнял Is Null 
AND (SELECT coalesce(Sum(Сумма),0) FROM arc_energo.ОплатыНТУ s WHERE r.Счет=s.Счет )>0;
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
		-- RAISE NOTICE  'Срок поставки = Ожидается на склад';
		clc_stock_status =1;
	ELSE
		-- товара нет в наличии, товар не заказан
		-- RAISE NOTICE  'Товар отсутствует на складе';
		clc_stock_status =0;
	END IF;
	-- END IF; -- отключено в День Космонавтики
	-- если stock_status изменился, обновить "Содержание"
	-- UPDATE "Содержание" SET 
END IF;

-- Ну и, собственно, обновляем статус состояния прибора на складе 
IF bmode ='t' then
	IF Not loc_stock_status = clc_stock_status THEN
		UPDATE arc_energo.Содержание SET stock_status = clc_stock_status  WHERE КодСодержания =ks;
		RAISE NOTICE  'Обновление=% Cтатусы %->%  % ', bmode, loc_stock_status, clc_stock_status, ie_name_modification;
		-- INSERT INTO arc_energo.logerror (num, desript, Дата) VALUES (Cast(ks as character varying(10)),ie_name_modification, now());

		--INSERT INTO arc_energo.logerror (num, desript, operation, Дата) VALUES (Cast(ks as character varying(10)),ie_name_modification,loc_stock_status||'->'||clc_stock_status::character varying(50), now());	
	ELSE
		-- RAISE NOTICE  'Обновления не произошло.';
	END IF; 
END IF;

INSERT INTO arc_energo.logerror (num, operation, Дата) VALUES (Cast(ks as character varying(10)),loc_stock_status||'->'||clc_stock_status::character varying(50), now());			  



SELECT * INTO rs FROM (SELECT loc_stock_status, clc_stock_status) as t1;

RETURN rs;
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_set_stock_status(integer, boolean)
  OWNER TO arc_energo;
COMMENT ON FUNCTION fn_set_stock_status(integer, boolean) IS 'Изменяет Содержание.stock_status, если изменился';
