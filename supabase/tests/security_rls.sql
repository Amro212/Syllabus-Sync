do $$
declare
  table_name text;
  required_tables text[] := array[
    'users',
    'courses',
    'events',
    'grading_entries',
    'friend_requests',
    'friends',
    'blocked_users',
    'user_preferences',
    'social_action_rate_limits'
  ];
begin
  foreach table_name in array required_tables loop
    if not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = table_name
        and c.relrowsecurity
    ) then
      raise exception 'RLS is not enabled for public.%', table_name;
    end if;
  end loop;

  foreach table_name in array required_tables[1:8] loop
    if not exists (
      select 1
      from pg_policies
      where schemaname = 'public'
        and tablename = table_name
    ) then
      raise exception 'No RLS policies found for public.%', table_name;
    end if;
  end loop;

  if not exists (
    select 1
    from pg_trigger
    where tgname = 'friend_requests_rate_limit'
      and not tgisinternal
  ) then
    raise exception 'friend_requests rate-limit trigger missing';
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgname = 'friend_request_create_friendship'
      and not tgisinternal
  ) then
    raise exception 'friendship creation trigger missing';
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgname = 'blocked_users_rate_limit'
      and not tgisinternal
  ) then
    raise exception 'blocked_users rate-limit trigger missing';
  end if;
  if has_function_privilege('authenticated', 'public.credit_ai_purchase(uuid,text,text,text,text,text,integer,jsonb)', 'execute')
    or has_function_privilege('anon', 'public.reserve_ai_parse_credit(uuid,text)', 'execute')
    or has_table_privilege('authenticated', 'public.ai_usage_accounts', 'update')
    or has_table_privilege('authenticated', 'public.friends', 'insert') then
    raise exception 'A client role can write application-managed data';
  end if;
end $$;
