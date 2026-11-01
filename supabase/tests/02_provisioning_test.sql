-- Novi nalog dobija tačno jedan profil, "Moje domaćinstvo" i članstvo vlasnika.
begin;
select plan(9);

select tests.create_user('Ana@Mail.com') as uid \gset

select is((select count(*) from public.profiles where id = :'uid'), 1::bigint, 'jedan profil');
select is((select email from public.profiles where id = :'uid'), 'ana@mail.com', 'e-pošta malim slovima');
select is((select display_name from public.profiles where id = :'uid'), null, 'ime još nije uneto');
select is((select count(*) from public.household_members where user_id = :'uid'), 1::bigint, 'jedno članstvo');
select is((select role from public.household_members where user_id = :'uid'), 'owner', 'uloga vlasnik');
select is(
  (select h.name from public.households h join public.household_members m on m.household_id = h.id
   where m.user_id = :'uid'),
  'Moje domaćinstvo',
  'domaćinstvo "Moje domaćinstvo"'
);

select tests.authenticate_as(:'uid');
select throws_ok(
  format('update public.profiles set display_name = %L where id = %L', '   ', :'uid'),
  '23514', null, 'prazno ime se odbija'
);
select throws_ok(
  format('update public.profiles set display_name = %L where id = %L', repeat('a', 41), :'uid'),
  '23514', null, 'ime od 41 znaka se odbija'
);
select is(
  tests.affected(format('update public.profiles set display_name = %L where id = %L', 'Ana Petrović', :'uid')),
  1::bigint,
  'ispravno ime se čuva'
);

select * from finish();
rollback;
