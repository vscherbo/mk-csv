-- Table: devmod.bx_dict_ib30

-- DROP TABLE devmod.bx_dict_ib30;

CREATE TABLE devmod.bx_dict_ib30
(
  dict_name character varying(16) NOT NULL,
  dict_comment character varying,
  dict_order integer,
  data_type character varying,
  CONSTRAINT "bx_dict_ib30_new_PK" PRIMARY KEY (dict_name)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE devmod.bx_dict_ib30
  OWNER TO arc_energo;
COMMENT ON TABLE devmod.bx_dict_ib30
  IS 'Справочник полей для экспорта цен и сроков модификаций';

