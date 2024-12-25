-- arc_energo.stock_status_changed определение

-- Drop table

-- DROP TABLE arc_energo.stock_status_changed;

CREATE TABLE arc_energo.stock_status_changed (
	id serial4 NOT NULL,
	dt_change timestamp DEFAULT clock_timestamp() NULL, -- дата-время изменения
	change_status int4 DEFAULT 0 NULL, -- 0 - изменено в arc_energo¶1 - успешно отправлено на сайт¶2 - ошибка¶-1 заблокированное изменение, не отправлять на сайт¶-2 не отправлять на сайт, т.к. есть более актуальная запись¶¶n (иное целое) - для повторной отправки через вызов resend_to_site_stock_status(n)
	dt_sent timestamp NULL, -- дата-время отправки на сайт
	sent_result varchar NULL, -- информация об обновлении
	ks int4 NULL, -- код содержания
	mod_id varchar(13) NULL, -- Код модификации для version_num=1
	mod_name varchar NULL,
	time_delivery varchar DEFAULT ''::character varying NOT NULL, -- Срок для сайта
	qnt numeric DEFAULT 0 NOT NULL, -- Количество в наличии
	dt_trans timestamp NULL, -- дата-время когда был выполнен расчет ssc_comppute
	dbl_cnt int4 DEFAULT 0 NOT NULL, -- Количество записей отвергнутых к добавлению, как дубли.
	retry_cnt int4 DEFAULT 0 NOT NULL,
	operations varchar(255) NULL,
	active bool DEFAULT true NOT NULL,
	CONSTRAINT "stock_status_change_PK" PRIMARY KEY (id)
);
CREATE INDEX ssc_mod_idx ON arc_energo.stock_status_changed USING btree (mod_id);
CREATE INDEX ssc_mod_upper_idx ON arc_energo.stock_status_changed USING btree (upper((mod_id)::text));
CREATE INDEX stock_status_changed_dt_sent_idx ON arc_energo.stock_status_changed USING btree (dt_sent);
CREATE INDEX stock_status_changed_dt_trans_idx ON arc_energo.stock_status_changed USING btree (dt_trans, time_delivery);
CREATE INDEX stock_status_changed_ks_idx ON arc_energo.stock_status_changed USING btree (ks);
COMMENT ON TABLE arc_energo.stock_status_changed IS 'для отправки пропущенных resend_to_site_stock_status(int)';

-- Column comments

COMMENT ON COLUMN arc_energo.stock_status_changed.dt_change IS 'дата-время изменения';
COMMENT ON COLUMN arc_energo.stock_status_changed.change_status IS '0 - изменено в arc_energo
1 - успешно отправлено на сайт
2 - ошибка
-1 заблокированное изменение, не отправлять на сайт
-2 не отправлять на сайт, т.к. есть более актуальная запись

n (иное целое) - для повторной отправки через вызов resend_to_site_stock_status(n)';
COMMENT ON COLUMN arc_energo.stock_status_changed.dt_sent IS 'дата-время отправки на сайт';
COMMENT ON COLUMN arc_energo.stock_status_changed.sent_result IS 'информация об обновлении';
COMMENT ON COLUMN arc_energo.stock_status_changed.ks IS 'код содержания';
COMMENT ON COLUMN arc_energo.stock_status_changed.mod_id IS 'Код модификации для version_num=1';
COMMENT ON COLUMN arc_energo.stock_status_changed.time_delivery IS 'Срок для сайта';
COMMENT ON COLUMN arc_energo.stock_status_changed.qnt IS 'Количество в наличии';
COMMENT ON COLUMN arc_energo.stock_status_changed.dt_trans IS 'дата-время когда был выполнен расчет ssc_comppute';
COMMENT ON COLUMN arc_energo.stock_status_changed.dbl_cnt IS 'Количество записей отвергнутых к добавлению, как дубли.';

-- Table Triggers

CREATE TRIGGER ssc_active BEFORE INSERT ON
arc_energo.stock_status_changed FOR EACH ROW EXECUTE PROCEDURE fntr_ssc_active();
CREATE TRIGGER ssc_ozon_calc_au AFTER UPDATE ON
arc_energo.stock_status_changed FOR EACH ROW
WHEN (((new.ks IS NOT NULL)
    AND (new.change_status = 0)
        AND (old.dt_trans IS NULL)
            AND (new.dt_trans IS NOT NULL))) EXECUTE PROCEDURE fntr_ozon_notify();
CREATE TRIGGER "stock_status_cahnged_AI" AFTER INSERT ON
arc_energo.stock_status_changed FOR EACH ROW EXECUTE PROCEDURE fntr_single_notify();
