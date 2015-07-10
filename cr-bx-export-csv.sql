-- Table: devmod.bx_export_csv

-- DROP TABLE devmod.bx_export_csv;

CREATE TABLE devmod.bx_export_csv
(
  csv_id serial NOT NULL,
  exp_id integer,
  mod_csv integer, -- 1-прибор; 2-модификаторы;4-сроки и цены
  bx_fld_name character varying(15), -- наименование поля в базе bitrix
  bx_fld_value character varying(4096),
  CONSTRAINT csv_id_pk PRIMARY KEY (csv_id),
  CONSTRAINT exp_id_fk FOREIGN KEY (exp_id)
      REFERENCES devmod.bx_export_log (exp_id) MATCH SIMPLE
      ON UPDATE CASCADE ON DELETE CASCADE
)
WITH (
  OIDS=FALSE
);
ALTER TABLE devmod.bx_export_csv
  OWNER TO arc_energo;
COMMENT ON COLUMN devmod.bx_export_csv.mod_csv IS '1-прибор; 2-модификаторы;4-сроки и цены';
COMMENT ON COLUMN devmod.bx_export_csv.bx_fld_name IS 'наименование поля в базе bitrix';


-- Index: devmod.bx_export_csv_fld_name_ux

-- DROP INDEX devmod.bx_export_csv_fld_name_ux;

CREATE UNIQUE INDEX bx_export_csv_fld_name_ux
  ON devmod.bx_export_csv
  USING btree
  (exp_id, mod_csv, bx_fld_name COLLATE pg_catalog."default")
  WHERE mod_csv = ANY (ARRAY[1, 2]);

