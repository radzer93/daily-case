create or replace function public.admin_quota_until()
returns timestamptz language sql stable security definer set search_path = '' as $$
  select max((l.detail ->> 'retry_at')::timestamptz)
    from private.generation_log l
   where l.stage = 'quota'
     and l.created_at > now() - interval '2 days'
$$;

revoke execute on function public.admin_quota_until() from public, anon, authenticated;
grant execute on function public.admin_quota_until() to service_role;
