-- DROP TRIGGER tgrashod ON arc_energo."Расход";

CREATE TRIGGER tgoplata
   AFTER INSERT OR UPDATE  OF "Счет", "Сумма" OR DELETE
  ON arc_energo."ОплатыНТУ"
  FOR EACH ROW
  EXECUTE PROCEDURE arc_energo."fntr_Счет_Резерв_Склад"();

-- Function: arc_energo."fntr_Счет_Статус_10"()

-- DROP FUNCTION arc_energo."fntr_Счет_Статус_10"();

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
     FOR rs IN SELECT КодСодержания FROM "Содержание счета" WHERE "№ счета" = invoice
  
     LOOP
        PERFORM fn_set_stock_status(rs.КодСодержания,'t');
     END LOOP;              

  RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION arc_energo."fntr_Счет_Резерв_Склад"()
  OWNER TO arc_energo;