-- 006a: lični podaci (ocene, profil ukusa) pripadaju osobi, ne domaćinstvu.

create table public.ratings (
  id text primary key check (char_length(id) between 1 and 64),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  recipe_id text not null references public.recipes (id) on delete cascade,
  stars int not null check (stars between 1 and 5),
  is_comfort_food boolean not null default false,
  comment text,
  cooked_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.taste_profiles (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  profile jsonb not null,
  updated_at timestamptz not null default now()
);

create index ratings_sync_idx on public.ratings (user_id, updated_at, id);
create index ratings_recipe_idx on public.ratings (recipe_id);

create trigger touch_updated_at before insert or update on public.ratings
  for each row execute function private.touch_updated_at();
create trigger touch_updated_at before insert or update on public.taste_profiles
  for each row execute function private.touch_updated_at();
