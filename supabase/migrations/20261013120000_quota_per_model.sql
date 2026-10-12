drop function if exists public.admin_quota_until();

create or replace function public.admin_quota_until(p_model text)
returns timestamptz language sql stable security definer set search_path = '' as $$
  select max((l.detail ->> 'retry_at')::timestamptz)
    from private.generation_log l
   where l.stage = 'quota'
     and coalesce(l.detail ->> 'model', p_model) = p_model
     and l.created_at > now() - interval '2 days'
$$;

revoke execute on function public.admin_quota_until(text) from public, anon, authenticated;
grant execute on function public.admin_quota_until(text) to service_role;
