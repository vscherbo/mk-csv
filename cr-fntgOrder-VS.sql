-- Function: fntr_order()

-- DROP FUNCTION fntr_order();

CREATE OR REPLACE FUNCTION fntr_order()
  RETURNS trigger AS
$BODY$
BEGIN

raise notice 'inside fntr_order()';

PERFORM 1 FROM "Заказ" 
WHERE "Заказ"."Заказ" = NEW."Заказ"
      AND "Заказ"."Код" NOT IN (203463, 225073);



IF FOUND THEN
    raise notice 'The order is found';
    PERFORM arc_energo.fn_set_stock_status(NEW."КодСодержания",'t');
END IF;

RETURN NEW;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fntr_order()
  OWNER TO arc_energo;
