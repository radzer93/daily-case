create or replace function public.get_case_stats(p_case_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  c_min_players constant int := 10;
  v_uid     uuid := auth.uid();
  v_case    private.cases;
  v_prog    jsonb;
  v_players int;
  v_solvers int;
  v_avg     numeric;
  v_top     jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  select * into v_case from private.cases where id = p_case_id and status = 'approved';
  if not found then
    raise exception 'case_not_found';
  end if;

  v_prog := private.progress(p_case_id, v_uid);
  if not (v_prog ->> 'done')::boolean then
    raise exception 'case_not_finished';
  end if;

  select count(*),
         count(*) filter (where p.won),
         round(avg(p.n) filter (where p.won), 1)
    into v_players, v_solvers, v_avg
    from (select a.user_id, count(*) as n, bool_or(a.correct) as won
            from private.attempts a
           where a.case_id = p_case_id
           group by a.user_id) p
   where p.won or p.n >= 3 or v_case.case_date < private.today();

  if v_players < c_min_players then
    return jsonb_build_object('players', v_players, 'enough', false);
  end if;

  if jsonb_typeof(v_prog -> 'solution') = 'object' then
    select jsonb_build_object('suspect_id', f.culprit, 'pct', round(100.0 * count(*) / sum(count(*)) over ()))
      into v_top
      from (select distinct on (a.user_id) a.culprit
              from private.attempts a
             where a.case_id = p_case_id
             order by a.user_id, a.id) f
     group by f.culprit
     order by count(*) desc, f.culprit
     limit 1;
  end if;

  return jsonb_build_object(
    'players', v_players,
    'enough', true,
    'solved_pct', round(100.0 * v_solvers / v_players),
    'avg_attempts', v_avg,
    'top_first_culprit', v_top
  );
end $$;

create or replace function public.get_tomorrow_teaser(p_difficulty text default 'medium')
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
           'title', c.title,
           'place', c.content ->> 'place',
           'date', c.content ->> 'date'
         )
    from private.cases c
   where c.case_date = private.today() + 1
     and c.difficulty = p_difficulty
     and c.status = 'approved'
   limit 1
$$;

revoke execute on function public.get_case_stats(uuid) from public, anon;
grant execute on function public.get_case_stats(uuid) to authenticated;

revoke execute on function public.get_tomorrow_teaser(text) from public, anon;
grant execute on function public.get_tomorrow_teaser(text) to authenticated;
