SELECT l.id, l.desript, l.operation, l."Дата", s.*
FROM logerror l, stock_status_changed s
WHERE 
l.desript LIKE '%ТТПД%' AND
l.num::INTEGER = s.ks
ORDER BY l.id DESC, s.dt_change DESC