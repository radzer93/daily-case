alter table private.cases drop constraint if exists cases_status_check;
alter table private.cases
  add constraint cases_status_check check (status in ('draft', 'pending', 'approved', 'rejected'));

alter table private.cases
  add column difficulty text not null default 'medium'
  check (difficulty in ('easy', 'medium', 'hard'));

drop index if exists private.cases_one_live_per_day;
create unique index cases_one_live_per_day_level
  on private.cases (case_date, difficulty)
  where status in ('draft', 'pending', 'approved');

create or replace function private.difficulty_multiplier(p_difficulty text)
returns numeric language sql immutable set search_path = '' as $$
  select case p_difficulty when 'easy' then 1.0 when 'hard' then 2.0 else 1.5 end
$$;

create or replace function private.difficulty_order(p_difficulty text)
returns int language sql immutable set search_path = '' as $$
  select case p_difficulty when 'easy' then 1 when 'medium' then 2 else 3 end
$$;

create or replace function private.public_case(c private.cases)
returns jsonb language sql stable set search_path = '' as $$
  select c.content || jsonb_build_object(
    'id', c.id,
    'title', c.title,
    'kind', c.kind,
    'difficulty', c.difficulty,
    'case_date', c.case_date,
    'day_number', (c.case_date - private.launch_date()) + 1
  )
$$;

create or replace function private.progress(p_case_id uuid, p_uid uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c          private.cases;
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

  v_expired := c.case_date < v_today;
  v_done    := v_won or v_n >= 3 or v_expired;
  v_base    := greatest(10, 100 - 20 * (v_n - 1) - 10 * coalesce(array_length(v_unlocked, 1), 0));

  select coalesce(jsonb_object_agg(h.key, h.value), '{}'::jsonb)
    into v_hints
    from jsonb_each_text(coalesce(c.secret -> 'hints', '{}'::jsonb)) as h(key, value)
   where v_done or h.key = any (v_unlocked);

  return jsonb_build_object(
    'attempts', v_attempts,
    'unlocked', to_jsonb(v_unlocked),
    'hints',    v_hints,
    'done',     v_done,
    'won',      v_won,
    'expired',  v_expired,
    'score',    case when v_won
                  then round(v_base * private.difficulty_multiplier(c.difficulty))::int
                  else 0 end,
    'solution', case when v_won or v_expired then c.secret -> 'solution' else null end
  );
end $$;

create or replace function private.today_levels(p_uid uuid, p_day date)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(x.difficulty, jsonb_build_object('won', x.won, 'done', x.won or x.n >= 3)), '{}'::jsonb)
    from (
      select c.difficulty,
             coalesce(bool_or(a.correct), false) as won,
             count(a.id) as n
        from private.cases c
        left join private.attempts a on a.case_id = c.id and a.user_id = p_uid
       where c.case_date = p_day and c.status = 'approved'
       group by c.difficulty
    ) x
$$;

drop function if exists public.get_today_case();

create or replace function public.get_today_case(p_difficulty text default 'medium')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c       private.cases;
  v_uid   uuid := auth.uid();
  v_today date := private.today();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_difficulty is null or p_difficulty not in ('easy', 'medium', 'hard') then
    raise exception 'invalid_choice';
  end if;

  select * into c from private.cases
   where case_date = v_today and difficulty = p_difficulty and status = 'approved';

  if not found then
    return jsonb_build_object(
      'case', null,
      'progress', null,
      'levels', private.today_levels(v_uid, v_today),
      'closes_at', private.closes_at(v_today)
    );
  end if;

  return jsonb_build_object(
    'case',      private.public_case(c),
    'progress',  private.progress(c.id, v_uid),
    'levels',    private.today_levels(v_uid, v_today),
    'closes_at', private.closes_at(v_today)
  );
end $$;

create or replace function public.get_my_stats()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid   uuid := auth.uid();
  v_today date := private.today();
  r       jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  with per_case as (
    select c.id, c.case_date, bool_or(a.correct) as won, count(*) as n
      from private.attempts a
      join private.cases c on c.id = a.case_id
     where a.user_id = v_uid
     group by c.id, c.case_date
  ),
  win_days as (
    select distinct case_date from per_case where won
  ),
  wins as (
    select case_date, case_date - (row_number() over (order by case_date))::int as grp
      from win_days
  ),
  islands as (
    select count(*)::int as len, max(case_date) as last_day from wins group by grp
  )
  select jsonb_build_object(
    'played', (select count(*) from per_case where won or n >= 3 or case_date < v_today),
    'won',    (select count(*) from per_case where won),
    'best',   coalesce((select max(len) from islands), 0),
    'streak', coalesce((select len from islands where last_day >= v_today - 1
                         order by last_day desc limit 1), 0)
  ) into r;

  return r;
end $$;

create or replace function public.get_archive(p_limit int default 60)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid   uuid := auth.uid();
  v_today date := private.today();
  r       jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select coalesce(jsonb_agg(x.item order by x.case_date desc, x.ord), '[]'::jsonb) into r
    from (
      select c.case_date,
             private.difficulty_order(c.difficulty) as ord,
             jsonb_build_object(
               'id', c.id,
               'title', c.title,
               'kind', c.kind,
               'difficulty', c.difficulty,
               'docket', c.content ->> 'docket',
               'place', c.content ->> 'place',
               'case_date', c.case_date,
               'day_number', (c.case_date - private.launch_date()) + 1,
               'won', coalesce(m.won, false),
               'attempts', coalesce(m.n, 0)
             ) as item
        from private.cases c
        left join (
          select a.case_id, bool_or(a.correct) as won, count(*)::int as n
            from private.attempts a
           where a.user_id = v_uid
           group by a.case_id
        ) m on m.case_id = c.id
       where c.status = 'approved' and c.case_date < v_today
       order by c.case_date desc, private.difficulty_order(c.difficulty)
       limit greatest(1, least(coalesce(p_limit, 60), 365))
    ) x;

  return r;
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
               'case_date', d.case_date,
               'difficulty', d.difficulty,
               'case', d.secret -> 'draft',
               'seed', d.meta -> 'seed'
             )
        from private.cases d
       where d.status = 'draft'
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
            and c.status in ('draft', 'pending', 'approved'))
    ), '[]'::jsonb),
    'recent', coalesce((
      select jsonb_agg(jsonb_build_object(
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

drop function if exists public.admin_insert_case(date, text, text, text, jsonb, jsonb, jsonb, text);

create or replace function public.admin_insert_case(
  p_case_date  date,
  p_difficulty text,
  p_status     text,
  p_kind       text,
  p_title      text,
  p_content    jsonb,
  p_secret     jsonb,
  p_meta       jsonb default '{}'::jsonb,
  p_model      text default null
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  insert into private.cases (case_date, difficulty, status, kind, title, content, secret, meta, model)
  values (p_case_date, p_difficulty, p_status, p_kind, p_title, p_content, p_secret,
          coalesce(p_meta, '{}'::jsonb), p_model)
  returning id into v_id;
  return v_id;
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
  if p_status not in ('pending', 'approved', 'rejected') then
    raise exception 'invalid_status';
  end if;

  update private.cases
     set status  = p_status,
         content = coalesce(p_content, content),
         secret  = coalesce(p_secret, secret),
         meta    = meta || coalesce(p_meta, '{}'::jsonb)
   where id = p_id and status = 'draft';

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
   where id = p_id and status = 'draft'
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

revoke execute on all functions in schema private from public, anon, authenticated;

revoke execute on function public.get_today_case(text) from public, anon;
grant execute on function public.get_today_case(text) to authenticated;

revoke execute on function public.admin_insert_case(date, text, text, text, text, jsonb, jsonb, jsonb, text) from public, anon, authenticated;
grant execute on function public.admin_insert_case(date, text, text, text, text, jsonb, jsonb, jsonb, text) to service_role;

revoke execute on function public.admin_finalize_case(uuid, text, jsonb, jsonb, jsonb) from public, anon, authenticated;
revoke execute on function public.admin_note_draft_failure(uuid, text, int) from public, anon, authenticated;
grant execute on function public.admin_note_draft_failure(uuid, text, int) to service_role;
grant execute on function public.admin_finalize_case(uuid, text, jsonb, jsonb, jsonb) to service_role;
