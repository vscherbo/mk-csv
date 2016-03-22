-- Function: "getFirm"(integer)

-- DROP FUNCTION "getFirm"(integer);

CREATE OR REPLACE FUNCTION "getFirm"(acode integer)
  RETURNS character varying AS
$BODY$
DECLARE
  ourFirm VARCHAR;
  flgDealer BOOLEAN;
BEGIN
/**/
IF "КодПредприятия" = 223719 THEN
   ourFirm = 'АРКОМ';
   RETURN ourFirm;
END IF;
   
select INTO flgDealer exists(select 1 from vwДилеры WHERE "Код"= aCode);
IF flgDealer THEN
   ourFirm = 'КИПСПБ';
ELSE
   ourFirm = 'ЭТК';
END IF;      
/**/
RETURN ourFirm;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION "getFirm"(integer)
  OWNER TO arc_energo;
COMMENT ON FUNCTION "getFirm"(integer) IS 'Возвращает аббревиатуру нашей компании, от которой будет сформирован счёт';
