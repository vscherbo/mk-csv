-- Function: eq_last_sent(character varying, character varying, numeric)

-- DROP FUNCTION eq_last_sent(character varying, character varying, numeric);

CREATE OR REPLACE FUNCTION eq_last_sent(
    a_mod_id character varying,
    a_time_delivery character varying,
    a_qnt numeric)
  RETURNS boolean AS
$BODY$
DECLARE
loc_time_delivery VARCHAR;
loc_qnt NUMERIC;
loc_equal BOOLEAN default false;
loc_id INTEGER;
loc_cnt INTEGER;


BEGIN
-- есть ли неотправленные
PERFORM * FROM arc_energo.stock_status_changed WHERE mod_id=a_mod_id AND change_status=0;
if found then
    loc_equal := false;
else 
    SELECT time_delivery, qnt, id, dbl_cnt INTO loc_time_delivery, loc_qnt, loc_id, loc_cnt
    FROM arc_energo.stock_status_changed
    WHERE mod_id=a_mod_id
        AND change_status=1
    ORDER BY dt_sent DESC LIMIT 1;

    loc_equal = (FOUND AND (loc_qnt=a_qnt) AND (loc_time_delivery=a_time_delivery));

    IF loc_equal THEN
        UPDATE stock_status_changed SET dbl_cnt = (loc_cnt + 1) WHERE id=loc_id; 
    END IF;
end if;

RETURN loc_equal;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION eq_last_sent(character varying, character varying, numeric)
  OWNER TO arc_energo;

