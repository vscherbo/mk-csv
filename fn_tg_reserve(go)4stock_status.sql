-- Триггер и триггерная функция состояния склада для постановки резервов

CREATE OR REPLACE FUNCTION arc_energo."fn_tgreserve4stock_status"()
  RETURNS trigger AS
$BODY$
  DECLARE
  rs record;
  ks INTEGER;
  suminvoice numeric;

BEGIN
   If TG_OP ='DELETE' THEN
	ks:= OLD.КодСодержания;
   ELSE
	ks:=NEW.КодСодержания;
   END IF;

        PERFORM fn_set_stock_status(ks,'t');

  RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION arc_energo."fn_tgreserve4stock_status"()
  OWNER TO arc_energo;

-- ----------------------------------------------------
CREATE TRIGGER tgreserve4stock_status
  AFTER INSERT OR UPDATE OF "Счет", "КогдаСнял" OR DELETE
  ON arc_energo."Резерв"
  FOR EACH ROW
  EXECUTE PROCEDURE arc_energo."fn_tgreserve4stock_status"();

  -- Триггер состояния склада для постановки ИДУЩИХ резервов
  -- Использует триггерную функцию  fn_tgreserve4stock_status (для таблицы резерв)

-- ----------------------------------------------------
CREATE TRIGGER tgreservego4stock_status
  AFTER INSERT OR UPDATE OF "Счет", "КогдаСнял" OR DELETE
  ON arc_energo."РезервИдущий"
  FOR EACH ROW
  EXECUTE PROCEDURE arc_energo."fn_tgreserve4stock_status"();