-- Function: devmod.mk_csv_device(integer)

-- DROP FUNCTION devmod.mk_csv_device(integer);

CREATE OR REPLACE FUNCTION devmod.mk_csv_device(
    IN alogid integer,
    OUT out_csv character varying,
    OUT out_res character varying,
    OUT out_model_name character varying,
    OUT out_xml_id character varying)
  RETURNS record AS
$BODY$DECLARE
  res RECORD;
BEGIN
  res := devmod.mk_csv_general(alogid, 'devmod.bx_dict_ib29', 1);
  out_csv := res.out_csv;
  out_res := res.out_res;
  out_model_name := res.out_model_name;
  out_xml_id := res.out_xml_id;
END$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION devmod.mk_csv_device(integer)
  OWNER TO arc_energo;
