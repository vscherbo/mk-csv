-- Table: devmod.bx_dict_ib34

-- DROP TABLE devmod.bx_dict_ib34;

CREATE TABLE devmod.bx_dict_ib34
(
  dict_name character varying(16) NOT NULL,
  dict_comment character varying(40) NOT NULL,
  prop_code character varying(15) NOT NULL,
  dict_order integer,
  data_type character varying,
  mod_id integer,
  val_id integer,
  CONSTRAINT "bx_dict_ib34_new_PK" PRIMARY KEY (dict_name)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE devmod.bx_dict_ib34
  OWNER TO arc_energo;
COMMENT ON TABLE devmod.bx_dict_ib34
  IS 'Справочник для экспорта модификаторов прибора, списков значений и их исключений';

-- Trigger: tr_bx_dict_ib34_new on devmod.bx_dict_ib34

-- DROP TRIGGER tr_bx_dict_ib34_new ON devmod.bx_dict_ib34;

CREATE TRIGGER tr_bx_dict_ib34_new
  BEFORE INSERT OR UPDATE OF prop_code, mod_id, val_id
  ON devmod.bx_dict_ib34
  FOR EACH ROW
  EXECUTE PROCEDURE devmod.fntr_ib34_parse();

