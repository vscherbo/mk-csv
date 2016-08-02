-- Function: "fntr_Счет_Резерв_Склад"()

-- DROP FUNCTION "fntr_Счет_Резерв_Склад"();

CREATE OR REPLACE FUNCTION "fntr_Счет_Резерв_Склад"()
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
	-- SELECT КодСодержания FROM "Содержание счета" WHERE "№ счета" = invoice
	 SELECT КодСодержания FROM 
	(
	SELECT КодСодержания FROM "Содержание счета" WHERE "№ счета" = invoice AND Not КодСодержания Is Null
	Union
	SELECT КодСодержания FROM Резерв WHERE "Счет" = invoice AND КогдаСнял Is Null
	Union
	SELECT КодСодержания FROM РезервИдущий WHERE "Счет" = invoice AND КогдаСнял Is Null
	 ) t0
  
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
ALTER FUNCTION "fntr_Счет_Резерв_Склад"()
  OWNER TO arc_energo;
