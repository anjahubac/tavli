-- Shortlist current household recipes by Serbian search terms. The caller's
-- recipes SELECT policy is also applied because this function is invoker.
create function public.saved_recipe_question_candidates(p_question text)
returns table (id text, title text, content text)
language sql stable security invoker set search_path = ''
as $$
  with query_words as (
    select distinct left(word, greatest(4, length(word) - 1)) as stem
    from regexp_split_to_table(
      translate(lower(left(p_question, 500)), 'čćšžđ', 'ccszd'),
      '[^a-z0-9]+'
    ) as terms(word)
    where length(word) >= 4 and word not in (
      'recept', 'recepti', 'receptima', 'kuvara', 'sacuvanih', 'predlozi',
      'predlog', 'koji', 'koja', 'imam', 'mogu', 'napravim', 'spremim'
    )
  ), candidates as (
    select r.id, r.title, r.updated_at,
      left(r.title || E'\nSastojci: ' || r.ingredients::text ||
        E'\nPriprema: ' || r.steps::text, 3500) as content
    from public.recipes r
  )
  select c.id, c.title, c.content
  from candidates c
  order by (
    select coalesce(sum(
      case when translate(lower(c.title), 'čćšžđ', 'ccszd') like '%' || stem || '%'
        then 3
        when translate(lower(c.content), 'čćšžđ', 'ccszd') like '%' || stem || '%'
        then 1 else 0 end
    ), 0) from query_words
  ) desc, c.updated_at desc, c.id
  limit 24;
$$;

revoke execute on function public.saved_recipe_question_candidates(text)
  from public, anon;
grant execute on function public.saved_recipe_question_candidates(text)
  to authenticated;
