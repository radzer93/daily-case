create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table private.cases (
  id          uuid primary key default gen_random_uuid(),
  case_date   date not null,
  status      text not null default 'pending'
              check (status in ('pending', 'approved', 'rejected')),
  kind        text not null default 'fictional'
              check (kind in ('fictional', 'inspired')),
  title       text not null,
  content     jsonb not null,
  secret      jsonb not null,
  meta        jsonb not null default '{}'::jsonb,
  model       text,
  created_at  timestamptz not null default now()
);

create unique index cases_one_live_per_day
  on private.cases (case_date)
  where status in ('pending', 'approved');

create table private.attempts (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  case_id     uuid not null references private.cases (id) on delete cascade,
  culprit     text not null,
  motive      text not null,
  evidence    text not null,
  result      boolean[] not null check (array_length(result, 1) = 3),
  correct     boolean generated always as (result[1] and result[2] and result[3]) stored,
  created_at  timestamptz not null default now()
);
create index attempts_user_case_idx on private.attempts (user_id, case_id);

create table private.hint_unlocks (
  user_id     uuid not null references auth.users (id) on delete cascade,
  case_id     uuid not null references private.cases (id) on delete cascade,
  evidence_id text not null,
  created_at  timestamptz not null default now(),
  primary key (user_id, case_id, evidence_id)
);

create table private.generation_log (
  id          bigint generated always as identity primary key,
  case_date   date,
  ok          boolean not null,
  stage       text not null,
  detail      jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);

alter table private.cases          enable row level security;
alter table private.attempts       enable row level security;
alter table private.hint_unlocks   enable row level security;
alter table private.generation_log enable row level security;

create or replace function private.today()
returns date language sql stable set search_path = '' as $$
  select (now() at time zone 'Europe/Warsaw')::date
$$;

create or replace function private.launch_date()
returns date language sql immutable set search_path = '' as $$
  select date '2026-10-07'
$$;

create or replace function private.closes_at(p_day date)
returns timestamptz language sql stable set search_path = '' as $$
  select ((p_day + 1)::timestamp at time zone 'Europe/Warsaw')
$$;

create or replace function private.public_case(c private.cases)
returns jsonb language sql stable set search_path = '' as $$
  select c.content || jsonb_build_object(
    'id', c.id,
    'title', c.title,
    'kind', c.kind,
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
                  then greatest(10, 100 - 20 * (v_n - 1) - 10 * coalesce(array_length(v_unlocked, 1), 0))
                  else 0 end,
    'solution', case when v_won or v_expired then c.secret -> 'solution' else null end
  );
end $$;

create or replace function public.get_today_case()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c       private.cases;
  v_uid   uuid := auth.uid();
  v_today date := private.today();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select * into c from private.cases
   where case_date = v_today and status = 'approved';

  if not found then
    return jsonb_build_object('case', null, 'progress', null, 'closes_at', private.closes_at(v_today));
  end if;

  return jsonb_build_object(
    'case',      private.public_case(c),
    'progress',  private.progress(c.id, v_uid),
    'closes_at', private.closes_at(v_today)
  );
end $$;

create or replace function public.get_case(p_case_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c     private.cases;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select * into c from private.cases
   where id = p_case_id and status = 'approved' and case_date <= private.today();
  if not found then
    raise exception 'case_not_found';
  end if;

  return jsonb_build_object(
    'case',     private.public_case(c),
    'progress', private.progress(c.id, v_uid)
  );
end $$;

create or replace function public.submit_accusation(
  p_case_id  uuid,
  p_culprit  text,
  p_motive   text,
  p_evidence text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c      private.cases;
  v_uid  uuid := auth.uid();
  v_prog jsonb;
  v_sol  jsonb;
  v_ev   jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':' || p_case_id::text, 0));

  select * into c from private.cases where id = p_case_id and status = 'approved';
  if not found then
    raise exception 'case_not_found';
  end if;
  if c.case_date <> private.today() then
    raise exception 'case_closed';
  end if;

  v_prog := private.progress(p_case_id, v_uid);
  if (v_prog ->> 'done')::boolean then
    raise exception 'case_finished';
  end if;

  if not exists (select 1 from jsonb_array_elements(c.content -> 'suspects') s where s ->> 'id' = p_culprit)
     or not exists (select 1 from jsonb_array_elements(c.content -> 'motives') m where m ->> 'id' = p_motive) then
    raise exception 'invalid_choice';
  end if;

  select e into v_ev from jsonb_array_elements(c.content -> 'evidence') e where e ->> 'id' = p_evidence;
  if v_ev is null then
    raise exception 'invalid_choice';
  end if;
  if coalesce((v_ev ->> 'hint')::boolean, false)
     and not exists (select 1 from private.hint_unlocks h
                      where h.user_id = v_uid and h.case_id = p_case_id and h.evidence_id = p_evidence) then
    raise exception 'invalid_choice';
  end if;

  v_sol := c.secret -> 'solution';

  insert into private.attempts (user_id, case_id, culprit, motive, evidence, result)
  values (
    v_uid, p_case_id, p_culprit, p_motive, p_evidence,
    array[
      p_culprit = (v_sol ->> 'culprit'),
      p_motive  = (v_sol ->> 'motive'),
      coalesce((v_sol -> 'evidence') ? p_evidence, false)
    ]
  );

  return private.progress(p_case_id, v_uid);
end $$;

create or replace function public.unlock_hint(p_case_id uuid, p_evidence_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c      private.cases;
  v_uid  uuid := auth.uid();
  v_prog jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select * into c from private.cases where id = p_case_id and status = 'approved';
  if not found then
    raise exception 'case_not_found';
  end if;
  if c.case_date <> private.today() then
    raise exception 'case_closed';
  end if;

  v_prog := private.progress(p_case_id, v_uid);
  if (v_prog ->> 'done')::boolean then
    raise exception 'case_finished';
  end if;

  if not exists (select 1 from jsonb_array_elements(c.content -> 'evidence') e
                  where e ->> 'id' = p_evidence_id and coalesce((e ->> 'hint')::boolean, false)) then
    raise exception 'invalid_choice';
  end if;

  insert into private.hint_unlocks (user_id, case_id, evidence_id)
  values (v_uid, p_case_id, p_evidence_id)
  on conflict do nothing;

  return private.progress(p_case_id, v_uid);
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

  with mine as (
    select c.case_date, bool_or(a.correct) as won, count(*) as n
      from private.attempts a
      join private.cases c on c.id = a.case_id
     where a.user_id = v_uid
     group by c.case_date
  ),
  wins as (
    select case_date, case_date - (row_number() over (order by case_date))::int as grp
      from mine where won
  ),
  islands as (
    select count(*)::int as len, max(case_date) as last_day from wins group by grp
  )
  select jsonb_build_object(
    'played', (select count(*) from mine where won or n >= 3 or case_date < v_today),
    'won',    (select count(*) from mine where won),
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

  select coalesce(jsonb_agg(x.item order by x.case_date desc), '[]'::jsonb) into r
    from (
      select c.case_date,
             jsonb_build_object(
               'id', c.id,
               'title', c.title,
               'kind', c.kind,
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
       order by c.case_date desc
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
    'missing', coalesce((
      select jsonb_agg(d::date order by d)
        from generate_series(v_today::timestamp, (v_today + p_days_ahead)::timestamp, interval '1 day') d
       where not exists (
         select 1 from private.cases c
          where c.case_date = d::date and c.status in ('pending', 'approved'))
    ), '[]'::jsonb),
    'recent', coalesce((
      select jsonb_agg(jsonb_build_object(
               'title', r.title,
               'place', r.content ->> 'place',
               'seed',  r.meta -> 'seed'
             ) order by r.case_date desc)
        from (select * from private.cases
               where status <> 'rejected'
               order by case_date desc limit 40) r
    ), '[]'::jsonb)
  );
end $$;

create or replace function public.admin_insert_case(
  p_case_date date,
  p_status    text,
  p_kind      text,
  p_title     text,
  p_content   jsonb,
  p_secret    jsonb,
  p_meta      jsonb default '{}'::jsonb,
  p_model     text default null
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  insert into private.cases (case_date, status, kind, title, content, secret, meta, model)
  values (p_case_date, p_status, p_kind, p_title, p_content, p_secret, coalesce(p_meta, '{}'::jsonb), p_model)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.admin_log(
  p_case_date date,
  p_ok        boolean,
  p_stage     text,
  p_detail    jsonb default '{}'::jsonb
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into private.generation_log (case_date, ok, stage, detail)
  values (p_case_date, p_ok, p_stage, coalesce(p_detail, '{}'::jsonb));
end $$;

revoke all on all tables in schema private from public, anon, authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;

revoke execute on function public.get_today_case()                      from public, anon;
revoke execute on function public.get_case(uuid)                        from public, anon;
revoke execute on function public.submit_accusation(uuid, text, text, text) from public, anon;
revoke execute on function public.unlock_hint(uuid, text)               from public, anon;
revoke execute on function public.get_my_stats()                        from public, anon;
revoke execute on function public.get_archive(int)                      from public, anon;

grant execute on function public.get_today_case()                       to authenticated;
grant execute on function public.get_case(uuid)                         to authenticated;
grant execute on function public.submit_accusation(uuid, text, text, text) to authenticated;
grant execute on function public.unlock_hint(uuid, text)                to authenticated;
grant execute on function public.get_my_stats()                         to authenticated;
grant execute on function public.get_archive(int)                       to authenticated;

revoke execute on function public.admin_generation_plan(int)            from public, anon, authenticated;
revoke execute on function public.admin_insert_case(date, text, text, text, jsonb, jsonb, jsonb, text) from public, anon, authenticated;
revoke execute on function public.admin_log(date, boolean, text, jsonb) from public, anon, authenticated;

grant execute on function public.admin_generation_plan(int)             to service_role;
grant execute on function public.admin_insert_case(date, text, text, text, jsonb, jsonb, jsonb, text) to service_role;
grant execute on function public.admin_log(date, boolean, text, jsonb)  to service_role;
