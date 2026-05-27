-- Security tightening: row-level security and least-privilege social access.

create or replace function public.is_blocked_between(lhs uuid, rhs uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.blocked_users b
    where (b.blocker_id = lhs and b.blocked_id = rhs)
       or (b.blocker_id = rhs and b.blocked_id = lhs)
  );
$$;

create or replace function public.are_friends(lhs uuid, rhs uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.friends f
    where (f.user_a_id = lhs and f.user_b_id = rhs)
       or (f.user_a_id = rhs and f.user_b_id = lhs)
  );
$$;

create or replace function public.can_view_schedule(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() = target_user_id
    or (
      auth.uid() is not null
      and not public.is_blocked_between(auth.uid(), target_user_id)
      and exists (
        select 1
        from public.users u
        where u.id = target_user_id
          and (
            u.schedule_visibility = 'public'
            or (u.schedule_visibility = 'friends_only' and public.are_friends(auth.uid(), target_user_id))
          )
      )
    );
$$;

grant execute on function public.is_blocked_between(uuid, uuid) to authenticated;
grant execute on function public.are_friends(uuid, uuid) to authenticated;
grant execute on function public.can_view_schedule(uuid) to authenticated;

alter table public.users enable row level security;
alter table public.courses enable row level security;
alter table public.events enable row level security;
alter table public.grading_entries enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friends enable row level security;
alter table public.blocked_users enable row level security;
alter table public.user_preferences enable row level security;

create table if not exists public.social_action_rate_limits (
  user_id uuid not null,
  action text not null,
  window_start timestamptz not null,
  count integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, action, window_start)
);

alter table public.social_action_rate_limits enable row level security;

create or replace function public.check_social_action_rate_limit(
  actor_id uuid,
  action_name text,
  max_actions integer,
  window_seconds integer default 3600
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_window timestamptz;
  next_count integer;
begin
  if actor_id is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  current_window := to_timestamp(floor(extract(epoch from now()) / window_seconds) * window_seconds);

  insert into public.social_action_rate_limits (user_id, action, window_start, count, updated_at)
  values (actor_id, action_name, current_window, 1, now())
  on conflict (user_id, action, window_start)
  do update
    set count = public.social_action_rate_limits.count + 1,
        updated_at = now()
  returning count into next_count;

  if next_count > max_actions then
    raise exception 'Social action rate limit exceeded for %', action_name using errcode = 'P0001';
  end if;
end;
$$;

create or replace function public.enforce_friend_request_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.check_social_action_rate_limit(new.from_user_id, 'friend_request_create', 20, 3600);
  elsif tg_op = 'UPDATE' and old.status is distinct from new.status then
    perform public.check_social_action_rate_limit(auth.uid(), 'friend_request_status_update', 60, 3600);
  end if;
  return new;
end;
$$;

create or replace function public.enforce_friendship_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.check_social_action_rate_limit(auth.uid(), 'friendship_create', 30, 3600);
  return new;
end;
$$;

create or replace function public.enforce_block_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.check_social_action_rate_limit(new.blocker_id, 'block_create', 30, 3600);
  return new;
end;
$$;

drop trigger if exists friend_requests_rate_limit on public.friend_requests;
create trigger friend_requests_rate_limit
before insert or update on public.friend_requests
for each row execute function public.enforce_friend_request_rate_limit();

drop trigger if exists friends_rate_limit on public.friends;
create trigger friends_rate_limit
before insert on public.friends
for each row execute function public.enforce_friendship_rate_limit();

drop trigger if exists blocked_users_rate_limit on public.blocked_users;
create trigger blocked_users_rate_limit
before insert on public.blocked_users
for each row execute function public.enforce_block_rate_limit();

grant execute on function public.check_social_action_rate_limit(uuid, text, integer, integer) to authenticated;

drop policy if exists users_select_safe_profiles on public.users;
create policy users_select_safe_profiles
on public.users for select
to authenticated
using (
  id = auth.uid()
  or (auth.uid() is not null and not public.is_blocked_between(auth.uid(), id))
);

drop policy if exists users_insert_self on public.users;
create policy users_insert_self
on public.users for insert
to authenticated
with check (id = auth.uid());

drop policy if exists users_update_self on public.users;
create policy users_update_self
on public.users for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists courses_select_owned_or_visible_schedule on public.courses;
create policy courses_select_owned_or_visible_schedule
on public.courses for select
to authenticated
using (user_id = auth.uid() or public.can_view_schedule(user_id));

drop policy if exists courses_insert_self on public.courses;
create policy courses_insert_self
on public.courses for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists courses_update_self on public.courses;
create policy courses_update_self
on public.courses for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists courses_delete_self on public.courses;
create policy courses_delete_self
on public.courses for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists events_select_owned_or_visible_schedule on public.events;
create policy events_select_owned_or_visible_schedule
on public.events for select
to authenticated
using (user_id = auth.uid() or public.can_view_schedule(user_id));

drop policy if exists events_insert_self on public.events;
create policy events_insert_self
on public.events for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists events_update_self on public.events;
create policy events_update_self
on public.events for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists events_delete_self on public.events;
create policy events_delete_self
on public.events for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists grading_entries_select_self on public.grading_entries;
create policy grading_entries_select_self
on public.grading_entries for select
to authenticated
using (user_id = auth.uid());

drop policy if exists grading_entries_insert_self on public.grading_entries;
create policy grading_entries_insert_self
on public.grading_entries for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists grading_entries_update_self on public.grading_entries;
create policy grading_entries_update_self
on public.grading_entries for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists grading_entries_delete_self on public.grading_entries;
create policy grading_entries_delete_self
on public.grading_entries for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists friend_requests_select_participant on public.friend_requests;
create policy friend_requests_select_participant
on public.friend_requests for select
to authenticated
using (from_user_id = auth.uid() or to_user_id = auth.uid());

drop policy if exists friend_requests_insert_self on public.friend_requests;
create policy friend_requests_insert_self
on public.friend_requests for insert
to authenticated
with check (
  from_user_id = auth.uid()
  and to_user_id <> auth.uid()
  and not public.is_blocked_between(from_user_id, to_user_id)
);

drop policy if exists friend_requests_update_participant on public.friend_requests;
create policy friend_requests_update_participant
on public.friend_requests for update
to authenticated
using (from_user_id = auth.uid() or to_user_id = auth.uid())
with check (from_user_id = auth.uid() or to_user_id = auth.uid());

drop policy if exists friends_select_participant on public.friends;
create policy friends_select_participant
on public.friends for select
to authenticated
using (user_a_id = auth.uid() or user_b_id = auth.uid());

drop policy if exists friends_insert_participant on public.friends;
create policy friends_insert_participant
on public.friends for insert
to authenticated
with check (
  (user_a_id = auth.uid() or user_b_id = auth.uid())
  and user_a_id <> user_b_id
  and not public.is_blocked_between(user_a_id, user_b_id)
);

drop policy if exists friends_delete_participant on public.friends;
create policy friends_delete_participant
on public.friends for delete
to authenticated
using (user_a_id = auth.uid() or user_b_id = auth.uid());

drop policy if exists blocked_users_select_self on public.blocked_users;
create policy blocked_users_select_self
on public.blocked_users for select
to authenticated
using (blocker_id = auth.uid());

drop policy if exists blocked_users_insert_self on public.blocked_users;
create policy blocked_users_insert_self
on public.blocked_users for insert
to authenticated
with check (blocker_id = auth.uid() and blocked_id <> auth.uid());

drop policy if exists blocked_users_delete_self on public.blocked_users;
create policy blocked_users_delete_self
on public.blocked_users for delete
to authenticated
using (blocker_id = auth.uid());

drop policy if exists user_preferences_select_self on public.user_preferences;
create policy user_preferences_select_self
on public.user_preferences for select
to authenticated
using (user_id = auth.uid());

drop policy if exists user_preferences_insert_self on public.user_preferences;
create policy user_preferences_insert_self
on public.user_preferences for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists user_preferences_update_self on public.user_preferences;
create policy user_preferences_update_self
on public.user_preferences for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
