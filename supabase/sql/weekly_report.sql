select jsonb_pretty(public.admin_quality_report(7));

select case_date, difficulty, status, title,
       meta -> 'editor' -> 'scores'  as editor_scores,
       meta -> 'editor' -> 'issues'  as editor_issues
  from private.cases
 where case_date >= private.today()
 order by case_date, private.difficulty_order(difficulty);

select c.case_date, c.difficulty, c.title, f.rating, f.reason, f.comment, f.updated_at
  from private.case_feedback f
  join private.cases c on c.id = f.case_id
 where f.reason is not null
 order by f.updated_at desc
 limit 50;
