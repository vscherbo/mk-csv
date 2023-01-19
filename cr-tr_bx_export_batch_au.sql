drop trigger bx_export_batch_au on devmod.bx_export_bat;

create trigger bx_export_batch_au after
update
    of status
    on
    devmod.bx_export_bat for each row
    when ((new.status = 10)) execute procedure fntr_bx_export_batch_au();

