-- Function: mk_csv(character varying, character varying)

-- DROP FUNCTION mk_csv(character varying, character varying);

CREATE OR REPLACE FUNCTION mk_csv(select_stmt character varying, file_name character varying)
  RETURNS void AS
$BODY$
BEGIN
  EXECUTE('COPY (' || select_stmt || ') TO ' || QUOTE_LITERAL(file_name) || ' WITH (FORMAT CSV, DELIMITER ''^'', HEADER true )' ); 
  PERFORM public.shell('chmod g+w ' || QUOTE_LITERAL(file_name) );
END;
$BODY$
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER
  COST 100;
ALTER FUNCTION mk_csv(character varying, character varying)
  OWNER TO postgres;
