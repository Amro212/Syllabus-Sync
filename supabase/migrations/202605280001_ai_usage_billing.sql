create extension if not exists pgcrypto;

create table if not exists public.ai_usage_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  free_used_count integer not null default 0 check (free_used_count >= 0),
  paid_remaining integer not null default 0 check (paid_remaining >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (event_type in ('parse', 'purchase')),
  status text not null check (status in ('reserved', 'consumed', 'refunded', 'credited')),
  credit_source text check (credit_source in ('free', 'paid')),
  units integer not null default 1 check (units > 0),
  request_key text,
  transaction_id text,
  original_transaction_id text,
  app_transaction_id text,
  product_id text,
  environment text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists ai_usage_events_request_key_unique
on public.ai_usage_events (user_id, request_key)
where request_key is not null;

create unique index if not exists ai_usage_events_transaction_id_unique
on public.ai_usage_events (transaction_id)
where transaction_id is not null;

alter table public.ai_usage_accounts enable row level security;
alter table public.ai_usage_events enable row level security;

create or replace function public.get_ai_usage_balance(target_user_id uuid)
returns table (
  free_used_count integer,
  free_remaining integer,
  free_allowance integer,
  paid_remaining integer,
  total_remaining integer,
  can_scan boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  allowance constant integer := 2;
  account_row public.ai_usage_accounts%rowtype;
begin
  select *
  into account_row
  from public.ai_usage_accounts
  where user_id = target_user_id;

  return query
  select
    coalesce(account_row.free_used_count, 0) as free_used_count,
    greatest(0, allowance - coalesce(account_row.free_used_count, 0)) as free_remaining,
    allowance as free_allowance,
    coalesce(account_row.paid_remaining, 0) as paid_remaining,
    greatest(0, allowance - coalesce(account_row.free_used_count, 0)) + coalesce(account_row.paid_remaining, 0) as total_remaining,
    (
      greatest(0, allowance - coalesce(account_row.free_used_count, 0)) + coalesce(account_row.paid_remaining, 0)
    ) > 0 as can_scan;
end;
$$;

create or replace function public.reserve_ai_parse_credit(target_user_id uuid, target_request_key text default null)
returns table (
  event_id uuid,
  credit_source text,
  reused boolean,
  free_used_count integer,
  free_remaining integer,
  free_allowance integer,
  paid_remaining integer,
  total_remaining integer,
  can_scan boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  allowance constant integer := 2;
  account_row public.ai_usage_accounts%rowtype;
  existing_event public.ai_usage_events%rowtype;
  inserted_event public.ai_usage_events%rowtype;
  remaining_free integer;
begin
  if target_request_key is not null then
    select *
    into existing_event
    from public.ai_usage_events
    where user_id = target_user_id
      and request_key = target_request_key
    order by created_at desc
    limit 1;

    if found and existing_event.status in ('reserved', 'consumed') then
      select *
      into account_row
      from public.ai_usage_accounts
      where user_id = target_user_id;

      remaining_free := greatest(0, allowance - coalesce(account_row.free_used_count, 0));

      return query
      select
        existing_event.id,
        coalesce(existing_event.credit_source, 'free'),
        true,
        coalesce(account_row.free_used_count, 0),
        remaining_free,
        allowance,
        coalesce(account_row.paid_remaining, 0),
        remaining_free + coalesce(account_row.paid_remaining, 0),
        (remaining_free + coalesce(account_row.paid_remaining, 0)) > 0;
      return;
    end if;
  end if;

  insert into public.ai_usage_accounts (user_id)
  values (target_user_id)
  on conflict (user_id) do nothing;

  select *
  into account_row
  from public.ai_usage_accounts
  where user_id = target_user_id
  for update;

  if account_row.free_used_count < allowance then
    update public.ai_usage_accounts
    set free_used_count = free_used_count + 1,
        updated_at = now()
    where user_id = target_user_id
    returning * into account_row;

    insert into public.ai_usage_events (
      user_id,
      event_type,
      status,
      credit_source,
      units,
      request_key,
      updated_at
    )
    values (
      target_user_id,
      'parse',
      'reserved',
      'free',
      1,
      target_request_key,
      now()
    )
    returning * into inserted_event;
  elsif account_row.paid_remaining > 0 then
    update public.ai_usage_accounts
    set paid_remaining = paid_remaining - 1,
        updated_at = now()
    where user_id = target_user_id
    returning * into account_row;

    insert into public.ai_usage_events (
      user_id,
      event_type,
      status,
      credit_source,
      units,
      request_key,
      updated_at
    )
    values (
      target_user_id,
      'parse',
      'reserved',
      'paid',
      1,
      target_request_key,
      now()
    )
    returning * into inserted_event;
  else
    remaining_free := greatest(0, allowance - account_row.free_used_count);

    return query
    select
      null::uuid,
      null::text,
      false,
      account_row.free_used_count,
      remaining_free,
      allowance,
      account_row.paid_remaining,
      remaining_free + account_row.paid_remaining,
      false;
    return;
  end if;

  remaining_free := greatest(0, allowance - account_row.free_used_count);

  return query
  select
    inserted_event.id,
    inserted_event.credit_source,
    false,
    account_row.free_used_count,
    remaining_free,
    allowance,
    account_row.paid_remaining,
    remaining_free + account_row.paid_remaining,
    true;
end;
$$;

create or replace function public.finalize_ai_parse_credit(target_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.ai_usage_events
  set status = 'consumed',
      updated_at = now()
  where id = target_event_id
    and status = 'reserved';
end;
$$;

create or replace function public.refund_ai_parse_credit(target_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  usage_event public.ai_usage_events%rowtype;
begin
  select *
  into usage_event
  from public.ai_usage_events
  where id = target_event_id
  for update;

  if not found or usage_event.status <> 'reserved' then
    return;
  end if;

  if usage_event.credit_source = 'free' then
    update public.ai_usage_accounts
    set free_used_count = greatest(0, free_used_count - usage_event.units),
        updated_at = now()
    where user_id = usage_event.user_id;
  elsif usage_event.credit_source = 'paid' then
    update public.ai_usage_accounts
    set paid_remaining = paid_remaining + usage_event.units,
        updated_at = now()
    where user_id = usage_event.user_id;
  end if;

  update public.ai_usage_events
  set status = 'refunded',
      updated_at = now()
  where id = target_event_id;
end;
$$;

create or replace function public.credit_ai_purchase(
  target_user_id uuid,
  purchase_transaction_id text,
  purchase_original_transaction_id text,
  purchase_app_transaction_id text,
  purchase_product_id text,
  purchase_environment text,
  purchased_units integer,
  purchase_metadata jsonb default '{}'::jsonb
)
returns table (
  free_used_count integer,
  free_remaining integer,
  free_allowance integer,
  paid_remaining integer,
  total_remaining integer,
  can_scan boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  allowance constant integer := 2;
  account_row public.ai_usage_accounts%rowtype;
  remaining_free integer;
begin
  insert into public.ai_usage_accounts (user_id)
  values (target_user_id)
  on conflict (user_id) do nothing;

  update public.ai_usage_accounts
  set paid_remaining = paid_remaining + greatest(1, purchased_units),
      updated_at = now()
  where user_id = target_user_id
  returning * into account_row;

  insert into public.ai_usage_events (
    user_id,
    event_type,
    status,
    credit_source,
    units,
    transaction_id,
    original_transaction_id,
    app_transaction_id,
    product_id,
    environment,
    metadata,
    updated_at
  )
  values (
    target_user_id,
    'purchase',
    'credited',
    'paid',
    greatest(1, purchased_units),
    purchase_transaction_id,
    purchase_original_transaction_id,
    purchase_app_transaction_id,
    purchase_product_id,
    purchase_environment,
    coalesce(purchase_metadata, '{}'::jsonb),
    now()
  );

  remaining_free := greatest(0, allowance - account_row.free_used_count);

  return query
  select
    account_row.free_used_count,
    remaining_free,
    allowance,
    account_row.paid_remaining,
    remaining_free + account_row.paid_remaining,
    (remaining_free + account_row.paid_remaining) > 0;
end;
$$;

grant execute on function public.get_ai_usage_balance(uuid) to authenticated;
grant execute on function public.reserve_ai_parse_credit(uuid, text) to authenticated;
grant execute on function public.finalize_ai_parse_credit(uuid) to authenticated;
grant execute on function public.refund_ai_parse_credit(uuid) to authenticated;
grant execute on function public.credit_ai_purchase(uuid, text, text, text, text, text, integer, jsonb) to authenticated;

drop policy if exists ai_usage_accounts_select_self on public.ai_usage_accounts;
create policy ai_usage_accounts_select_self
on public.ai_usage_accounts for select
to authenticated
using (user_id = auth.uid());

drop policy if exists ai_usage_accounts_insert_self on public.ai_usage_accounts;
create policy ai_usage_accounts_insert_self
on public.ai_usage_accounts for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists ai_usage_accounts_update_self on public.ai_usage_accounts;
create policy ai_usage_accounts_update_self
on public.ai_usage_accounts for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists ai_usage_events_select_self on public.ai_usage_events;
create policy ai_usage_events_select_self
on public.ai_usage_events for select
to authenticated
using (user_id = auth.uid());
