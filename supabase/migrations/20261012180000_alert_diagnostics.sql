create or replace function public.admin_quality_alerts(
  p_min_reports         int default 3,
  p_min_ratings         int default 5,
  p_low_rating          numeric default 2.5,
  p_tomorrow_check_hour int default 18
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_today date := private.today();
  v_hour  int  := extract(hour from now() at time zone 'Europe/Warsaw')::int;
begin
  return coalesce((
    select jsonb_agg(a.item order by a.item ->> 'key')
      from (
        select jsonb_build_object(
                 'key', 'case:' || c.id || ':' || f.flag,
                 'flag', f.flag,
                 'date', c.case_date,
                 'difficulty', c.difficulty,
                 'title', c.title,
                 'detail', jsonb_build_object(
                   'reports', coalesce(s.reports, '{}'::jsonb),
                   'report_count', coalesce(s.report_count, 0),
                   'ratings', coalesce(s.ratings, 0),
                   'avg_rating', s.avg_rating
                 )
               ) as item
          from private.cases c
          join (
            select fb.case_id,
                   count(fb.reason) as report_count,
                   count(fb.reason) filter (where fb.reason = 'inappropriate') as inappropriate,
                   count(fb.rating) as ratings,
                   round(avg(fb.rating), 2) as avg_rating,
                   (select jsonb_object_agg(r.reason, r.n)
                      from (select f2.reason, count(*) as n
                              from private.case_feedback f2
                             where f2.case_id = fb.case_id and f2.reason is not null
                             group by f2.reason) r) as reports
              from private.case_feedback fb
             group by fb.case_id
          ) s on s.case_id = c.id
          cross join lateral (
            select unnest(array_remove(array[
              case when s.inappropriate > 0 then 'inappropriate' end,
              case when s.report_count >= p_min_reports then 'many_reports' end,
              case when s.ratings >= p_min_ratings and s.avg_rating < p_low_rating then 'low_rating' end
            ], null)) as flag
          ) f
         where c.status = 'approved'
           and c.case_date between v_today - 1 and v_today

        union all

        select jsonb_build_object(
                 'key', 'slot:' || g.day || ':' || g.level || ':missing',
                 'flag', 'missing_case',
                 'date', g.day,
                 'difficulty', g.level,
                 'title', null,
                 'detail', jsonb_build_object(
                   'slot_statuses', coalesce((
                     select jsonb_object_agg(x.status, x.n)
                       from (select c2.status, count(*) as n
                               from private.cases c2
                              where c2.case_date = g.day and c2.difficulty = g.level
                              group by c2.status) x
                   ), '{}'::jsonb),
                   'last_run', (select max(l.created_at) from private.generation_log l),
                   'last_success', (select max(l.created_at) from private.generation_log l where l.ok),
                   'recent_log', coalesce((
                     select jsonb_agg(jsonb_build_object(
                              'stage', l.stage, 'ok', l.ok, 'date', l.case_date, 'at', l.created_at
                            ) order by l.created_at desc)
                       from (select * from private.generation_log l2
                              order by l2.created_at desc limit 5) l
                   ), '[]'::jsonb)
                 )
               )
          from (
            select v_today as day, l.level
              from unnest(array['easy', 'medium', 'hard']) as l(level)
            union all
            select v_today + 1, l.level
              from unnest(array['easy', 'medium', 'hard']) as l(level)
             where v_hour >= p_tomorrow_check_hour
          ) g
         where not exists (
           select 1 from private.cases c
            where c.case_date = g.day
              and c.difficulty = g.level
              and c.status = 'approved')
      ) a
     where not exists (select 1 from private.alerts x where x.key = a.item ->> 'key')
  ), '[]'::jsonb);
end $$;
