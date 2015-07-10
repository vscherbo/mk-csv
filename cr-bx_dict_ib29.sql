-- Table: devmod.bx_dict_ib29

-- DROP TABLE devmod.bx_dict_ib29;

CREATE TABLE devmod.bx_dict_ib29
(
  dict_name character varying(16) NOT NULL,
  dict_comment character varying,
  dict_order integer,
  data_type character varying,
  CONSTRAINT "bx_dict_ib29_new_PK" PRIMARY KEY (dict_name)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE devmod.bx_dict_ib29
  OWNER TO arc_energo;

