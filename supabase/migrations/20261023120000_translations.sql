alter table private.cases add column if not exists translations jsonb not null default '{}'::jsonb;

create or replace function private.lang()
returns text language sql stable set search_path = '' as $$
  select coalesce(
    nullif(lower(left(coalesce(nullif(current_setting('request.headers', true), ''), '{}')::json ->> 'x-lang', 2)), ''),
    'pl'
  )
$$;

create or replace function private.tr(c private.cases, p_part text)
returns jsonb language sql stable set search_path = '' as $$
  select coalesce(
    c.translations -> private.lang() -> p_part,
    case p_part
      when 'title' then to_jsonb(c.title)
      when 'content' then c.content
      when 'secret' then c.secret
    end
  )
$$;

create or replace function private.public_case(c private.cases)
returns jsonb language sql stable set search_path = '' as $$
  select private.tr(c, 'content') || jsonb_build_object(
    'id', c.id,
    'title', private.tr(c, 'title') #>> '{}',
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
    from jsonb_each_text(coalesce(private.tr(c, 'secret') -> 'hints', '{}'::jsonb)) as h(key, value)
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
    'solution',  case when v_won or v_expired then private.tr(c, 'secret') -> 'solution' else null end,
    'my_rating', f.rating,
    'reported',  f.reason is not null
  );
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
               'title', private.tr(c, 'title') #>> '{}',
               'kind', c.kind,
               'difficulty', c.difficulty,
               'docket', c.content ->> 'docket',
               'place', private.tr(c, 'content') ->> 'place',
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

create or replace function public.get_tomorrow_teaser(p_difficulty text default 'medium')
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
           'title', private.tr(c, 'title') #>> '{}',
           'place', private.tr(c, 'content') ->> 'place',
           'date', private.tr(c, 'content') ->> 'date'
         )
    from private.cases c
   where c.case_date = private.today() + 1
     and c.difficulty = p_difficulty
     and c.status = 'approved'
   limit 1
$$;

create or replace function public.admin_untranslated(p_langs text[], p_limit int default 3)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x.item order by x.case_date, x.ord), '[]'::jsonb)
    from (
      select c.case_date,
             private.difficulty_order(c.difficulty) as ord,
             jsonb_build_object(
               'id', c.id,
               'case_date', c.case_date,
               'difficulty', c.difficulty,
               'title', c.title,
               'content', c.content,
               'secret', c.secret,
               'missing', to_jsonb(array(select l from unnest(p_langs) l where not c.translations ? l))
             ) as item
        from private.cases c
       where c.status = 'approved'
         and c.case_date >= private.today()
         and exists (select 1 from unnest(p_langs) l where not c.translations ? l)
         and (select count(*) from private.generation_log l
               where l.stage = 'translation'
                 and not l.ok
                 and l.detail ->> 'id' = c.id::text
                 and l.created_at > now() - interval '6 hours') < 3
       order by c.case_date, private.difficulty_order(c.difficulty)
       limit greatest(1, coalesce(p_limit, 3))
    ) x
$$;

create or replace function public.admin_set_translation(p_id uuid, p_lang text, p_value jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_lang is null or p_lang !~ '^[a-z]{2}$' or p_lang = 'pl' then
    raise exception 'invalid_language';
  end if;
  update private.cases
     set translations = translations || jsonb_build_object(p_lang, p_value)
   where id = p_id and status = 'approved';
  if not found then
    raise exception 'case_not_found';
  end if;
end $$;

revoke execute on all functions in schema private from public, anon, authenticated;

revoke execute on function public.admin_untranslated(text[], int) from public, anon, authenticated;
grant execute on function public.admin_untranslated(text[], int) to service_role;

revoke execute on function public.admin_set_translation(uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.admin_set_translation(uuid, text, jsonb) to service_role;
