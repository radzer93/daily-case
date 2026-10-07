select case_date, status, kind, title, content ->> 'place' as place, meta -> 'seed' ->> 'setting' as setting
  from private.cases
 where case_date >= private.today()
 order by case_date;

select case_date, title, content, secret
  from private.cases
 where case_date = date '2026-10-15';

select created_at, case_date, ok, stage, detail
  from private.generation_log
 order by created_at desc
 limit 30;

select c.case_date, c.title,
       count(distinct a.user_id)                                as players,
       count(distinct a.user_id) filter (where a.correct)       as solved,
       round(avg(a.result[1]::int) * 100)                       as culprit_hit_pct
  from private.cases c
  left join private.attempts a on a.case_id = c.id
 where c.case_date >= private.today() - 14 and c.case_date <= private.today()
 group by c.case_date, c.title
 order by c.case_date desc;
