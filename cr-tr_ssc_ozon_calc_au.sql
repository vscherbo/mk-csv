\i cr-fntr_ozon_notify.sql

CREATE TRIGGER ssc_ozon_calc_au AFTER UPDATE ON
arc_energo.stock_status_changed FOR EACH ROW
WHEN (((new.ks IS NOT NULL)
    AND (new.change_status = 0)
        AND (old.dt_trans IS NULL)
            AND (new.dt_trans IS NOT NULL))) EXECUTE PROCEDURE fntr_ozon_notify();
