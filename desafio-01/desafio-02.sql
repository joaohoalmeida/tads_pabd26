drop table if exists point_adjusment_audit;
create table point_adjusment_audit(
    id serial primary key,
    year int not null,
    driver_id varchar(100) not null,
    old_points decimal(8,2),
    new_points decimal(8,2),
    change_at timestamptz default now();
)

create or replace function point_adjusment()
    returns trigger
    language plpgsql
as $$
begin
    insert into point_adjusment_audit(id, year, driver_id, old_points, new_points, change_at)
        values(OLD.id, OLD.year. OLD.old_points, NEW.new_points, NEW.change_at)
    return NEW;
end
$$;

drop trigger if exists trg_update_point;
create trigger trg_update_point
after update on season_driver_standing
execute function point_adjusment();