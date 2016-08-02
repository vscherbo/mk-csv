-- Function: arc_energo.fntr_order()

-- DROP FUNCTION arc_energo.fntr_order();

CREATE OR REPLACE FUNCTION arc_energo.fntr_order()
  RETURNS trigger AS
$BODY$
DECLARE 
post integer;
BEGIN

-- SELECT Код INTO post FROM Заказ z JOIN СписокЗаказа sz ON s.Заказ=sz.Заказ WHERE КодСпискаЗаказа=NEW.КодСпискаЗаказа;

PERFORM 1 FROM "Заказ" 
WHERE "Заказ"."Заказ" = NEW."Заказ"
      AND "Заказ"."Код" NOT IN (203463, 225073);

RAISE NOTICE 'Состояние склада для %',NEW."КодСодержания";

IF FOUND THEN
    PERFORM arc_energo.fn_set_stock_status(NEW."КодСодержания",'t');
END IF;

RETURN NEW;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION arc_energo.fntr_order()
  OWNER TO arc_energo;
