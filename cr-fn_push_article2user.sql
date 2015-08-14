-- Function: fn_push_article2user(integer, text, integer)

-- DROP FUNCTION fn_push_article2user(integer, text, integer);

CREATE OR REPLACE FUNCTION fn_push_article2user(
    emp_id integer,
    article text,
    author_id integer DEFAULT 0)
  RETURNS integer AS
$BODY$ DECLARE
  a_id INTEGER;
BEGIN
    WITH inserted AS (
        INSERT INTO "Статьи"("Содержание", "Автор") VALUES (article, author_id)
        RETURNING "НомерСтатьи"
    )
 
    SELECT "НомерСтатьи" INTO a_id FROM inserted;
    INSERT INTO "Задания"("НомерСтатей", "Кому") VALUES (a_id, emp_id);
    
    RETURN a_id;

END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_push_article2user(integer, text, integer)
  OWNER TO arc_energo;
