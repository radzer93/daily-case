alter table private.cases drop constraint if exists cases_status_check;
alter table private.cases
  add constraint cases_status_check check (status in ('draft', 'verified', 'pending', 'approved', 'rejected'));

drop index if exists private.cases_one_live_per_day_level;
create unique index cases_one_live_per_day_level
  on private.cases (case_date, difficulty)
  where status in ('draft', 'verified', 'pending', 'approved');

create table private.case_feedback (
  user_id    uuid not null references auth.users (id) on delete cascade,
  case_id    uuid not null references private.cases (id) on delete cascade,
  rating     smallint check (rating between 1 and 5),
  reason     text check (reason in ('unfair', 'contradiction', 'language', 'inappropriate', 'other')),
  comment    text check (char_length(comment) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, case_id)
);
create index case_feedback_case_idx on private.case_feedback (case_id);
alter table private.case_feedback enable row level security;
revoke all on table private.case_feedback from public, anon, authenticated;

create or replace function private.progress(p_case_id uuid, p_uid uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c          private.cases;
  f          private.case_feedback;
  v_today    date := private.today();
  v_attempts jsonb;
  v_n        int;
  v_won      boolean;
  v_unlocked text[];
  v_hints    jsonb;
  v_expired  boolean;
  v_done     boolean;
  v_base     int;
begin
  select * into c from private.cases where id = p_case_id;
  if not found then
    raise exception 'case_not_found';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'c', a.culprit, 'm', a.motive, 'e', a.evidence, 'r', to_jsonb(a.result)
         ) order by a.id), '[]'::jsonb),
         count(*)::int,
         coalesce(bool_or(a.correct), false)
    into v_attempts, v_n, v_won
    from private.attempts a
   where a.case_id = p_case_id and a.user_id = p_uid;

  select coalesce(array_agg(h.evidence_id order by h.created_at), '{}'::text[])
    into v_unlocked
    from private.hint_unlocks h
   where h.case_id = p_case_id and h.user_id = p_uid;

  select * into f from private.case_feedback where case_id = p_case_id and user_id = p_uid;

  v_expired := c.case_date < v_today;
  v_done    := v_won or v_n >= 3 or v_expired;
  v_base    := greatest(10, 100 - 20 * (v_n - 1) - 10 * coalesce(array_length(v_unlocked, 1), 0));

  select coalesce(jsonb_object_agg(h.key, h.value), '{}'::jsonb)
    into v_hints
    from jsonb_each_text(coalesce(c.secret -> 'hints', '{}'::jsonb)) as h(key, value)
   where v_done or h.key = any (v_unlocked);

  return jsonb_build_object(
    'attempts',  v_attempts,
    'unlocked',  to_jsonb(v_unlocked),
    'hints',     v_hints,
    'done',      v_done,
    'won',       v_won,
    'expired',   v_expired,
    'score',     case when v_won
                   then round(v_base * private.difficulty_multiplier(c.difficulty))::int
                   else 0 end,
    'solution',  case when v_won or v_expired then c.secret -> 'solution' else null end,
    'my_rating', f.rating,
    'reported',  f.reason is not null
  );
end $$;

create or replace function public.submit_case_feedback(
  p_case_id uuid,
  p_rating  int default null,
  p_reason  text default null,
  p_comment text default null
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid  uuid := auth.uid();
  v_prog jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_rating is null and p_reason is null then
    raise exception 'invalid_choice';
  end if;
  if p_rating is not null and (p_rating < 1 or p_rating > 5) then
    raise exception 'invalid_choice';
  end if;
  if p_reason is not null and p_reason not in ('unfair', 'contradiction', 'language', 'inappropriate', 'other') then
    raise exception 'invalid_choice';
  end if;
  if not exists (select 1 from private.cases where id = p_case_id and status = 'approved') then
    raise exception 'case_not_found';
  end if;

  v_prog := private.progress(p_case_id, v_uid);
  if not (v_prog ->> 'done')::boolean or jsonb_array_length(v_prog -> 'attempts') = 0 then
    raise exception 'case_not_finished';
  end if;

  insert into private.case_feedback (user_id, case_id, rating, reason, comment)
  values (v_uid, p_case_id, p_rating, p_reason, left(p_comment, 500))
  on conflict (user_id, case_id) do update
     set rating     = coalesce(excluded.rating, private.case_feedback.rating),
         reason     = coalesce(excluded.reason, private.case_feedback.reason),
         comment    = coalesce(excluded.comment, private.case_feedback.comment),
         updated_at = now();

  return private.progress(p_case_id, v_uid);
end $$;

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
               'seed', d.meta -> 'seed'
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

create or replace function public.admin_finalize_case(
  p_id      uuid,
  p_status  text,
  p_content jsonb default null,
  p_secret  jsonb default null,
  p_meta    jsonb default '{}'::jsonb
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_status not in ('verified', 'pending', 'approved', 'rejected') then
    raise exception 'invalid_status';
  end if;

  update private.cases
     set status  = p_status,
         content = coalesce(p_content, content),
         secret  = coalesce(p_secret, secret),
         meta    = meta || coalesce(p_meta, '{}'::jsonb)
   where id = p_id and status in ('draft', 'verified');

  if not found then
    raise exception 'draft_not_found';
  end if;
end $$;

create or replace function public.admin_note_draft_failure(p_id uuid, p_error text, p_max_failures int default 3)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_failures int;
begin
  update private.cases
     set meta = jsonb_set(meta, '{verify_failures}', to_jsonb(coalesce((meta ->> 'verify_failures')::int, 0) + 1))
               || jsonb_build_object('last_verify_error', p_error)
   where id = p_id and status in ('draft', 'verified')
  returning (meta ->> 'verify_failures')::int into v_failures;

  if v_failures is null then
    return 'not_found';
  end if;
  if v_failures >= p_max_failures then
    update private.cases set status = 'rejected' where id = p_id;
    return 'rejected';
  end if;
  return 'kept';
end $$;

create or replace function public.admin_quality_report(p_days int default 7)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_today date := private.today();
  v_from  date := private.today() - greatest(1, p_days);
begin
  return jsonb_build_object(
    'period', jsonb_build_object('from', v_from, 'to', v_today),
    'generation', coalesce((
      select jsonb_object_agg(s.stage, s.n)
        from (select l.stage, count(*) as n
                from private.generation_log l
               where l.created_at >= v_from
               group by l.stage) s
    ), '{}'::jsonb),
    'editor_rejections', coalesce((
      select jsonb_agg(jsonb_build_object(
               'date', c.case_date,
               'difficulty', c.difficulty,
               'title', c.title,
               'scores', c.meta -> 'editor' -> 'scores',
               'issues', c.meta -> 'editor' -> 'issues'
             ) order by c.created_at desc)
        from private.cases c
       where c.created_at >= v_from
         and c.status = 'rejected'
         and c.meta ? 'editor'
    ), '[]'::jsonb),
    'cases', coalesce((
      select jsonb_agg(x.item order by x.case_date desc, x.ord)
        from (
          select c.case_date,
                 private.difficulty_order(c.difficulty) as ord,
                 jsonb_build_object(
                   'date', c.case_date,
                   'difficulty', c.difficulty,
                   'title', c.title,
                   'place', c.content ->> 'place',
                   'editor', c.meta -> 'editor' -> 'scores',
                   'players', coalesce(p.players, 0),
                   'solved_pct', p.solved_pct,
                   'avg_rating', fb.avg_rating,
                   'ratings', coalesce(fb.ratings, 0),
                   'reports', coalesce(fb.reports, '{}'::jsonb),
                   'flags', to_jsonb(array_remove(array[
                     case when coalesce(p.players, 0) >= 10 and c.difficulty = 'easy' and p.solved_pct < 30 then 'easy_too_hard' end,
                     case when coalesce(p.players, 0) >= 10 and c.difficulty = 'medium' and p.solved_pct < 15 then 'medium_too_hard' end,
                     case when coalesce(p.players, 0) >= 10 and c.difficulty <> 'easy' and p.solved_pct > 90 then 'too_easy' end,
                     case when coalesce(fb.ratings, 0) >= 5 and fb.avg_rating < 3 then 'low_rating' end,
                     case when coalesce(fb.report_count, 0) >= 3 then 'many_reports' end
                   ], null))
                 ) as item
            from private.cases c
            left join (
              select a.case_id,
                     count(distinct a.user_id) as players,
                     round(100.0 * count(distinct a.user_id) filter (where a.correct)
                           / nullif(count(distinct a.user_id), 0)) as solved_pct
                from private.attempts a
               group by a.case_id
            ) p on p.case_id = c.id
            left join (
              select f.case_id,
                     round(avg(f.rating), 2) as avg_rating,
                     count(f.rating) as ratings,
                     count(f.reason) as report_count,
                     (select jsonb_object_agg(r.reason, r.n)
                        from (select f2.reason, count(*) as n
                                from private.case_feedback f2
                               where f2.case_id = f.case_id and f2.reason is not null
                               group by f2.reason) r) as reports
                from private.case_feedback f
               group by f.case_id
            ) fb on fb.case_id = c.id
           where c.status = 'approved'
             and c.case_date between v_from and v_today
        ) x
    ), '[]'::jsonb)
  );
end $$;

revoke execute on all functions in schema private from public, anon, authenticated;

revoke execute on function public.submit_case_feedback(uuid, int, text, text) from public, anon;
grant execute on function public.submit_case_feedback(uuid, int, text, text) to authenticated;

revoke execute on function public.admin_quality_report(int) from public, anon, authenticated;
grant execute on function public.admin_quality_report(int) to service_role;
