-- Function: devmod.set_mod_timedelivery(character varying, bigint, character varying)

-- DROP FUNCTION devmod.set_mod_timedelivery(character varying, bigint, character varying);

CREATE OR REPLACE FUNCTION devmod.set_mod_timedelivery(
    site character varying,
    mod_code bigint,
    mod_timedelivery character varying)
  RETURNS character varying AS
$BODY$
DECLARE cmd character varying;
  res_exec RECORD;
BEGIN
    cmd := E'php $ARC_PATH/update-single-modification.php';
    cmd := cmd ||  ' -m'|| mod_code::VARCHAR;
    cmd := cmd ||  ' -t ''' || mod_timedelivery || '''' ;
    
    IF cmd IS NULL 
    THEN 
       res_exec.err_str := 'update-single-modification cmd IS NULL';
       RAISE '%', res_exec.err_str ; 
    END IF;
    --
     RAISE NOTICE 'update-single-modification cmd=[%]', cmd;
    res_exec := public.exec_paramiko(site, 22, 'uploader'::VARCHAR, cmd);
    
    IF res_exec.err_str <> ''
    THEN 
       RAISE 'update-single-modification cmd=%^err_str=[%]', cmd, res_exec.err_str; 
    END IF;
    
    return res_exec.err_str;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION devmod.set_mod_timedelivery(character varying, bigint, character varying)
  OWNER TO arc_energo;