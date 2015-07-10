-- Function: devmod.mk_csv_general(integer, regclass, integer)

-- DROP FUNCTION devmod.mk_csv_general(integer, regclass, integer);

CREATE OR REPLACE FUNCTION devmod.mk_csv_general(
    IN alogid integer,
    IN adict regclass,
    IN mode_csv integer,
    OUT out_csv character varying,
    OUT out_res character varying,
    OUT out_model_name character varying,
    OUT out_xml_id character varying)
  RETURNS record AS
$BODY$DECLARE
  val RECORD;
  col RECORD;
  cr1 VARCHAR;
  fld_count INTEGER;
  val_count INTEGER;
  ins_fld VARCHAR;
  ins_val VARCHAR;
  curr_val VARCHAR;
  select_cmd VARCHAR;
  debug_rec RECORD;
BEGIN
  cr1 := 'CREATE TEMPORARY TABLE IF NOT EXISTS csv_tmp (';
  FOR col IN EXECUTE format('SELECT dict_name, data_type FROM %s ORDER BY dict_order', adict) LOOP
      cr1 := cr1 || col.dict_name || ' ' || col.data_type || ',';
  END LOOP;
  cr1 := regexp_replace(cr1::text, ',$'::text, ');');
  --
  RAISE NOTICE 'cr1=%', cr1;
  EXECUTE cr1;
  EXECUTE 'TRUNCATE csv_tmp';
  
  ins_fld := 'INSERT INTO csv_tmp (';
  ins_val := 'VALUES (';
  SELECT COUNT(DISTINCT bx_fld_name) INTO fld_count FROM  devmod.bx_export_csv c WHERE c.mod_csv=mode_csv AND c.exp_id=aLogID;
  val_count := 0;
  -- не нужно, т.к. используем XML_ID
  --SELECT quote_ident(bx_fld_value) INTO out_model_name FROM  devmod.bx_exp_model_name c WHERE c.mod_csv=mode_csv AND c.exp_id=aLogID;
  SELECT d.ie_xml_id, quote_literal(d.dev_name) INTO out_xml_id, out_model_name
    FROM devmod.device d, devmod.bx_export_log l
    WHERE 
        l.exp_id = alogid
        AND l.dev_id = d.dev_id;
  --  
  RAISE NOTICE 'mk_csv_general: out_model_name=%', out_model_name;

  -- FOR val in EXECUTE format('SELECT dict_name,data_type,bx_fld_value FROM %s JOIN devmod.bx_export_csv c ON bx_fld_name = dict_name WHERE c.mod_csv=%s AND c.exp_id=%s AND c.bx_fld_value IS NOT NULL ORDER BY c.csv_id', adict, mode_csv, alogid) LOOP
  -- select_cmd := format('SELECT dict_name,data_type,bx_fld_value FROM %s JOIN devmod.bx_export_csv c ON bx_fld_name = dict_name WHERE c.mod_csv=%s AND c.exp_id=%s AND c.bx_fld_value IS NOT NULL ORDER BY c.csv_id', adict, mode_csv, alogid);
  select_cmd := format('SELECT dict_name,data_type, COALESCE(bx_fld_value, '''') AS bx_fld_value FROM %s JOIN devmod.bx_export_csv c ON bx_fld_name = dict_name WHERE c.mod_csv=%s AND c.exp_id=%s ORDER BY c.csv_id', adict, mode_csv, alogid);
  RAISE NOTICE 'select_cmd=%', select_cmd;
  FOR val in EXECUTE select_cmd LOOP
  
    IF val_count < fld_count THEN
       --
       RAISE NOTICE ' val_count=%, fld_count=%',  val_count, fld_count;
       val_count := val_count + 1;
    ELSE
       --
       RAISE NOTICE ' EXEC val_count=%',  val_count;
       ins_fld := regexp_replace(ins_fld, ',$', ') ');
       ins_val := regexp_replace(ins_val, ',$', ');');
       -- 
       RAISE NOTICE ' EXEC insert=%',  ins_fld || ins_val;
       EXECUTE ins_fld || ins_val ;
       ins_fld := 'INSERT INTO csv_tmp (';
       ins_val := 'VALUES (';
       val_count := 1;
    END IF; -- fld_count
    ins_fld := ins_fld || val.dict_name || ',' ;
    
    --IF val.data_type = 'character varying' OR val.data_type = 'timestamp without time zone' 
    --THEN
          --curr_val := quote_literal(val.bx_fld_value);
    --ELSE
          --curr_val := val.bx_fld_value;
    --END IF;   
    curr_val := quote_literal(val.bx_fld_value);
    RAISE NOTICE '   ###curr_val=%',  curr_val;
    ins_val := ins_val || curr_val || ',' ;
    --
    RAISE NOTICE '   current ins_fld=%',  ins_fld;
    --
    RAISE NOTICE '   current ins_val=%',  ins_val;
  END LOOP;

  ins_fld := regexp_replace(ins_fld, ',$', ') ');
  ins_val := regexp_replace(ins_val, ',$', ');');
  --
  RAISE NOTICE ' FIN_EXEC insert=%',  ins_fld || ins_val;
  EXECUTE ins_fld || ins_val ;

  out_csv = '/tmp/' || REPLACE(replace(adict::VARCHAR, 'bx_dict_', ''), 'devmod.', '') || '.csv';
  -- SELECT * INTO debug_rec FROM csv_tmp;
  -- RAise NOTICE 'csv_tmp=%', debug_rec ;
  SELECT mk_csv('SELECT * FROM csv_tmp', out_csv) INTO out_res;
  
  EXECUTE 'DROP TABLE csv_tmp';
END$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION devmod.mk_csv_general(integer, regclass, integer)
  OWNER TO arc_energo;
