-- Table: devmod.bx_export_log

-- DROP TABLE devmod.bx_export_log;

CREATE TABLE devmod.bx_export_log
(
  exp_id serial NOT NULL,
  exp_version_num integer NOT NULL,
  dev_id integer,
  exp_mod integer, -- мод выгрузки:1 - прибор; 2 - модификаторы; 4 - сроки и цены, ...
  exp_csv_status integer, -- флаг завершения этапов выгрузки:1 - прибор; 2 - модификаторы; 4 - сроки и цены, ...
  exp_dt timestamp without time zone,
  exp_finish_dt timestamp without time zone,
  exp_creator integer,
  exp_status integer, -- 0 - создан...
  exp_site character varying(100) NOT NULL,
  exp_result character varying,
  CONSTRAINT exp_id_pk PRIMARY KEY (exp_id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE devmod.bx_export_log
  OWNER TO arc_energo;
COMMENT ON TABLE devmod.bx_export_log
  IS 'Журнал выгрузки прибора на сайт';
COMMENT ON COLUMN devmod.bx_export_log.exp_mod IS 'мод выгрузки:1 - прибор; 2 - модификаторы; 4 - сроки и цены, 
exp_mod выставляется суммированием модов';
COMMENT ON COLUMN devmod.bx_export_log.exp_csv_status IS 'флаг завершения этапов выгрузки:1 - прибор; 2 - модификаторы; 4 - сроки и цены, 
exp_csv_mod выставляется суммированием модов';
COMMENT ON COLUMN devmod.bx_export_log.exp_status IS '0 - создан
1 - готов к выгрузке в CSV
2 - выгружен в CSV';


-- Index: devmod."fki_bx_export_log_dev_id_FK"

-- DROP INDEX devmod."fki_bx_export_log_dev_id_FK";

CREATE INDEX "fki_bx_export_log_dev_id_FK"
  ON devmod.bx_export_log
  USING btree
  (dev_id);


-- Trigger: bx_export_log_BU on devmod.bx_export_log

-- DROP TRIGGER "bx_export_log_BU" ON devmod.bx_export_log;

CREATE TRIGGER "bx_export_log_BU"
  BEFORE UPDATE OF exp_status
  ON devmod.bx_export_log
  FOR EACH ROW
  WHEN (((new.exp_status <> old.exp_status) AND (new.exp_status = 1)))
  EXECUTE PROCEDURE devmod.fntr_export_notify();

