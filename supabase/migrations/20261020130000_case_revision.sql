create or replace function public.admin_generation_plan(p_days_ahead int default 7)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_today date := private.today();
begin
  return jsonb_build_object(
    'today', v_today,
    'draft', (
      select jsonb_build_object(
               'id', d.id,
               'status', d.status,
               'case_date', d.case_date,
               'difficulty', d.difficulty,
               'case', d.secret -> 'draft',
               'seed', d.meta -> 'seed',
               'revisions', coalesce((d.meta ->> 'revisions')::int, 0),
               'revision_request', d.meta -> 'revision_request'
             )
        from private.cases d
       where d.status in ('draft', 'verified')
       order by d.case_date, private.difficulty_order(d.difficulty)
       limit 1
    ),
    'missing', coalesce((
      select jsonb_agg(jsonb_build_object(
               'date', g.day,
               'difficulty', g.level,
               'recent_failures', (
                 select count(*) from private.generation_log l
                  where l.case_date = g.day
                    and l.detail ->> 'difficulty' = g.level
                    and not l.ok
                    and l.stage in ('generation', 'validation', 'insert')
                    and l.created_at > now() - interval '6 hours'))
             order by g.day, private.difficulty_order(g.level))
        from (
          select d::date as day, l.level
            from generate_series(v_today::timestamp, (v_today + p_days_ahead)::timestamp, interval '1 day') d
           cross join unnest(array['easy', 'medium', 'hard']) as l(level)
        ) g
       where not exists (
         select 1 from private.cases c
          where c.case_date = g.day
            and c.difficulty = g.level
            and c.status in ('draft', 'verified', 'pending', 'approved'))
    ), '[]'::jsonb),
    'recent', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', r.id,
               'title', r.title,
               'place', r.content ->> 'place',
               'seed',  r.meta -> 'seed'
             ) order by r.case_date desc)
        from (select * from private.cases
               where status <> 'rejected'
               order by case_date desc, created_at desc limit 60) r
    ), '[]'::jsonb)
  );
end $$;

create or replace function public.admin_revise_case(
  p_id      uuid,
  p_title   text,
  p_content jsonb,
  p_secret  jsonb,
  p_meta    jsonb default '{}'::jsonb
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update private.cases
     set status  = 'draft',
         title   = p_title,
         content = p_content,
         secret  = p_secret,
         meta    = (meta - 'revision_request') || coalesce(p_meta, '{}'::jsonb)
   where id = p_id and status in ('draft', 'verified');

  if not found then
    raise exception 'draft_not_found';
  end if;
end $$;

revoke execute on function public.admin_revise_case(uuid, text, jsonb, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.admin_revise_case(uuid, text, jsonb, jsonb, jsonb) to service_role;
