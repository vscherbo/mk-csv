-- Function: set_mod_timedelivery(character varying, character varying, character varying, character varying)

-- DROP FUNCTION set_mod_timedelivery(character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION set_mod_timedelivery(
    site character varying,
    mod_code character varying,
    mod_timedelivery character varying,
    mod_qnt character varying)
  RETURNS character varying AS
$BODY$
DECLARE cmd character varying;
  res_exec RECORD;
  ret_str VARCHAR := '';
BEGIN
    cmd := E'php $ARC_PATH/update-single-modification.php';
    cmd := cmd ||  ' -m'|| mod_code::VARCHAR;
    cmd := cmd ||  ' -t''' || mod_timedelivery || '''' ;
    cmd := cmd ||  ' -q''' || COALESCE(mod_qnt, '') || '''' ;
    
    IF cmd IS NULL 
    THEN 
       res_exec.err_str := 'update-single-modification cmd IS NULL';
       RAISE '%', res_exec.err_str ; 
    END IF;
    -- RAISE NOTICE 'update-single-modification cmd=[%]', cmd;
    res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
    
    IF res_exec.err_str <> ''
    THEN 
       RAISE 'update-single-modification cmd=%^err_str=[%]', cmd, res_exec.err_str; 
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
ALTER FUNCTION set_mod_timedelivery(character varying, character varying, character varying, character varying)
  OWNER TO arc_energo;
