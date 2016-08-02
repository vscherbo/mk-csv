-- Function: arc_energo."fntr_Счет_Резерв_Склад"()

-- DROP FUNCTION arc_energo."fntr_Счет_Резерв_Склад"();

CREATE OR REPLACE FUNCTION arc_energo."fntr_Счет_Резерв_Склад"()
  RETURNS trigger AS
$BODY$
  DECLARE
  rs record;
  invoice INTEGER;
  suminvoice numeric;

BEGIN
   If TG_OP ='DELETE' THEN
   invoice:= OLD.Счет;
   ELSE
   invoice:=NEW.Счет;
   END IF;
     FOR rs IN 
	SELECT КодСодержания FROM "Содержание счета" WHERE "№ счета" = invoice
  
     LOOP
        PERFORM fn_set_stock_status(rs.КодСодержания,'t');
     END LOOP;              
  If TG_OP ='UPDATE' THEN
	IF NEW.Счет <> OLD.Счет THEN
	invoice:= OLD.Счет;
	     FOR rs IN 
		SELECT КодСодержания FROM "Содержание счета" WHERE "№ счета" = invoice
  
	     LOOP
		PERFORM fn_set_stock_status(rs.КодСодержания,'t');
             END LOOP;              
	END IF;
  END IF;
  RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION arc_energo."fntr_Счет_Резерв_Склад"()
  OWNER TO arc_energo;

-- Trigger: tgoplata on arc_energo."ОплатыНТУ"

-- DROP TRIGGER tgoplata ON arc_energo."ОплатыНТУ";

CREATE TRIGGER tgoplata
  AFTER INSERT OR UPDATE OF "Счет", "Сумма" OR DELETE
  ON arc_energo."ОплатыНТУ"
  FOR EACH ROW
  EXECUTE PROCEDURE arc_energo."fntr_Счет_Резерв_Склад"();

