DO
$$
    BEGIN
        IF (SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'app_private')) THEN
            DROP SCHEMA app_private CASCADE;
        END IF;
        CREATE SCHEMA app_private;

        IF (SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'app_public')) THEN
            DROP SCHEMA app_public CASCADE;
        END IF;
        CREATE SCHEMA app_public;

    END
$$;

begin;


CREATE FUNCTION app_public.viewer_id() RETURNS int AS $$
SELECT nullif(current_setting('user.id', TRUE),'')::int;
$$ LANGUAGE sql STABLE;

create table app_public.todo_list (
 id serial primary key,
 user_id int4 not null default app_public.viewer_id(),
 name varchar not null
);

alter table app_public.todo_list enable row level security;
create policy select_own on app_public.todo_list
FOR ALL USING (user_id = app_public.viewer_id());

create table app_public.todo_item (
  id serial primary key,
  headline text not null,
  body text,
  user_id int4 not null default app_public.viewer_id(),
  list_id int4 references app_public.todo_list(id) ON UPDATE CASCADE ON DELETE RESTRICT
);
create index on app_public.todo_item (id);

alter table app_public.todo_item enable row level security;
create policy select_own on app_public.todo_item
FOR ALL USING (user_id = app_public.viewer_id());

commit;

begin;

-- CREATE VIEW app_public.my_todo_list AS
-- SELECT *
-- FROM app_public.todo_list
-- WHERE user_id = app_public.viewer_id();
--
-- CREATE VIEW app_public.my_todo_items AS
-- SELECT list.*
-- FROM app_public.todo_list list
-- JOIN app_public.todo_item items on list.id = items.list_id
-- WHERE user_id = app_public.viewer_id();
--
-- create function app_public.my_todo_list_like(name_like text) returns setof app_public.my_todo_list as $$
-- SELECT *
-- FROM app_public.my_todo_list
-- where name ilike ('%' || name_like || '%')
-- $$ language sql stable;

commit;

begin;


alter sequence app_public.todo_list_id_seq restart with 1;

insert into app_public.todo_list(id,user_id, name) values (nextval('app_public.todo_list_id_seq'), 1, 'list 1 user 1');
insert into app_public.todo_list(id,user_id, name) values (nextval('app_public.todo_list_id_seq'), 1, 'list 2 user 1');
insert into app_public.todo_list(id,user_id, name) values (nextval('app_public.todo_list_id_seq'), 2, 'list 1 user 2');
insert into app_public.todo_list(id,user_id, name) values (nextval('app_public.todo_list_id_seq'), 2, 'list 2 user 2');

insert into app_public.todo_item(headline, body, user_id, list_id) values ('h1', 'b1', 1, 1);
insert into app_public.todo_item(headline, body, user_id, list_id) values ('h2', 'b2', 1, 2);
insert into app_public.todo_item(headline, body, user_id, list_id) values ('h2', 'b2', 2, 3);
insert into app_public.todo_item(headline, body, user_id, list_id) values ('h2', 'b2', 2, 4);
commit;
