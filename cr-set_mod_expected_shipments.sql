-- Function: arc_energo.set_mod_expected_shipments(character varying, character varying, character varying)

-- DROP FUNCTION arc_energo.set_mod_expected_shipments(character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION arc_energo.set_mod_expected_shipments(
    site character varying,
    mod_code character varying,
    mod_expected_shipments character varying)
  RETURNS character varying AS
$BODY$
DECLARE cmd character varying;
  res_exec RECORD;
  ret_str VARCHAR := '';
BEGIN
    cmd := E'php $ARC_PATH/update-expected-shipments.php';
    cmd := cmd ||  ' -m'|| mod_code::VARCHAR;
    cmd := cmd ||  ' -e''' || mod_expected_shipments || '''' ;
    
    IF cmd IS NULL 
    THEN 
       res_exec.err_str := 'update-expected-shipments cmd IS NULL';
       RAISE '%', res_exec.err_str ; 
    END IF;
    --
     RAISE NOTICE 'update-expected-shipments cmd=[%]', cmd;
    res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
    
    IF res_exec.err_str <> ''
    THEN 
       RAISE 'update-expected-shipments cmd=%^err_str=[%]', cmd, res_exec.err_str; 
       ret_str := res_exec.err_str;
    ELSE
       res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, '/usr/bin/php $ARC_PATH/test-flush-memcache.php');
       IF res_exec.err_str <> '' THEN 
          RAISE 'flush-memcache cmd=%^err_str=[%]', cmd, res_exec.err_str; 
          ret_str := res_exec.err_str;
       ELSE 
          ret_str := res_exec.out_str;
       END IF;
    END IF;
    
    return ret_str;
    -- res_exec.err_str;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION arc_energo.set_mod_expected_shipments(character varying, character varying, character varying)
  OWNER TO arc_energo;
