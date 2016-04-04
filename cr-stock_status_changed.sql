-- Table: stock_status_changed

-- DROP TABLE stock_status_changed;

CREATE TABLE stock_status_changed
(
  id serial NOT NULL,
  stock_status_old integer, -- до изменения
  stock_status_new integer, -- после изменения
  dt_change timestamp without time zone DEFAULT now(), -- дата-время изменения
  change_status integer DEFAULT 0, -- 0 - изменено в arc_energo...
  dt_sent timestamp without time zone, -- дата-время отправки на сайт
  sent_error character varying, -- информация об ошибке
  ks integer NOT NULL, -- код содержания
  CONSTRAINT "stock_status_change_PK" PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE stock_status_changed
  OWNER TO arc_energo;
COMMENT ON COLUMN stock_status_changed.stock_status_old IS 'до изменения';
COMMENT ON COLUMN stock_status_changed.stock_status_new IS 'после изменения';
COMMENT ON COLUMN stock_status_changed.dt_change IS 'дата-время изменения';
COMMENT ON COLUMN stock_status_changed.change_status IS '0 - изменено в arc_energo
1 - успешно отправлено на сайт
2 - ошибка';
COMMENT ON COLUMN stock_status_changed.dt_sent IS 'дата-время отправки на сайт';
COMMENT ON COLUMN stock_status_changed.sent_error IS 'информация об ошибке';
COMMENT ON COLUMN stock_status_changed.ks IS 'код содержания';


-- Trigger: stock_status_cahnged_AI on stock_status_changed

-- DROP TRIGGER "stock_status_cahnged_AI" ON stock_status_changed;

CREATE TRIGGER "stock_status_cahnged_AI"
  AFTER INSERT
  ON stock_status_changed
  FOR EACH ROW
  EXECUTE PROCEDURE fntr_single_notify();
ALTER TABLE stock_status_changed DISABLE TRIGGER "stock_status_cahnged_AI";

