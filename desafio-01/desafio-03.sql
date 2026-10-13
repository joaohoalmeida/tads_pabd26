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