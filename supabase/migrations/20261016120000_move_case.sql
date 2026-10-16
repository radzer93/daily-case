create or replace function public.admin_move_case(p_id uuid, p_case_date date, p_difficulty text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_difficulty is null or p_difficulty not in ('easy', 'medium', 'hard') then
    raise exception 'invalid_difficulty';
  end if;

  update private.cases
     set case_date  = p_case_date,
         difficulty = p_difficulty,
         meta       = meta || jsonb_build_object(
                        'moved_from', jsonb_build_object('date', case_date, 'difficulty', difficulty))
   where id = p_id and status in ('draft', 'verified');

  if not found then
    raise exception 'draft_not_found';
  end if;
end $$;

revoke execute on function public.admin_move_case(uuid, date, text) from public, anon, authenticated;
grant execute on function public.admin_move_case(uuid, date, text) to service_role;
