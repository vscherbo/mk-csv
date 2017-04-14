CREATE OR REPLACE FUNCTION smtphost()
  RETURNS character varying AS
$BODY$
DECLARE
loc_production boolean;
BEGIN
loc_production := pg_production();

IF loc_production THEN
  RETURN 'smtp.kipspb.ru';
ELSE
  RETURN 'mail.arc.world';
END IF;

END;$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;
