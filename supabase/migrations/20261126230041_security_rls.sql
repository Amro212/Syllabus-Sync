-- Security tightening: row-level security and least-privilege social access.

create or replace function public.is_blocked_between(lhs uuid, rhs uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() in (lhs, rhs) and exists (
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
  select auth.uid() in (lhs, rhs) and exists (
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

revoke execute on function public.is_blocked_between(uuid, uuid),
  public.are_friends(uuid, uuid), public.can_view_schedule(uuid) from public, anon;
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
  user_id uuid not null references auth.users(id) on delete cascade,
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
  elsif old.status is distinct from new.status then
    if old.status <> 'pending' or not (
      (auth.uid() = old.from_user_id and new.status = 'cancelled')
      or (auth.uid() = old.to_user_id and new.status in ('accepted', 'declined'))
    ) then
      raise exception 'Invalid friend request transition' using errcode = '42501';
    end if;
    perform public.check_social_action_rate_limit(auth.uid(), 'friend_request_status_update', 60, 3600);
  end if;
  return new;
end;
$$;

create or replace function public.create_accepted_friendship()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.is_blocked_between(new.from_user_id, new.to_user_id) then
    raise exception 'Friend request is unavailable' using errcode = '42501';
  end if;
  insert into public.friends (user_a_id, user_b_id)
  values (least(new.from_user_id, new.to_user_id), greatest(new.from_user_id, new.to_user_id))
  on conflict (user_a_id, user_b_id) do nothing;
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

drop trigger if exists friend_request_create_friendship on public.friend_requests;
create trigger friend_request_create_friendship
after update of status on public.friend_requests
for each row when (old.status = 'pending' and new.status = 'accepted')
execute function public.create_accepted_friendship();

drop trigger if exists blocked_users_rate_limit on public.blocked_users;
create trigger blocked_users_rate_limit
before insert on public.blocked_users
for each row execute function public.enforce_block_rate_limit();

revoke execute on function public.check_social_action_rate_limit(uuid, text, integer, integer),
  public.enforce_friend_request_rate_limit(), public.create_accepted_friendship(),
  public.enforce_block_rate_limit() from public, anon, authenticated;

-- Remove the permissive policies installed before migrations were tracked.
drop policy if exists "Users can view all usernames" on public.users;
drop policy if exists "Friends can view each other events" on public.events;
drop policy if exists "Users can send friend requests" on public.friend_requests;
drop policy if exists "Users can update own friend requests" on public.friend_requests;
drop policy if exists "Users can create friendships" on public.friends;

revoke all on public.users, public.courses, public.events, public.grading_entries,
  public.friend_requests, public.friends, public.blocked_users, public.user_preferences from anon;
revoke insert on public.friends from public, authenticated;
revoke update on public.friend_requests from public, authenticated;
grant update (status, updated_at) on public.friend_requests to authenticated;

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
  and status = 'pending'
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
