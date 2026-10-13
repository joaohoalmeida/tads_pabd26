create or replace function prevent_driver_deletion()
    returns trigger
    language plpgsql
as $$
begin
    if exists (select 1 from race_data where driver_id = OLD.driver_id) then
        raise exception 'Não permitido pilotos com registro', OLD.driver_id;
    end if;
    return old;
end;
$$;

drop trigger if exists trg_prevent_driver_del on driver;
create trigger trg_prevent_driver_del
before delete on driver
for each row
execute function prevent_driver_deletion();