create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

-- Configure the same dedicated token in Vault and the Edge function environment.
-- Missing configuration leaves the queue intact.
select cron.schedule('household-photo-cleanup', '*/5 * * * *', $job$
  select net.http_post(
    url := rtrim(project.decrypted_secret, '/') || '/functions/v1/household-photo-cleanup',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || token.decrypted_secret
    ),
    timeout_milliseconds := 120000
  )
  from vault.decrypted_secrets project, vault.decrypted_secrets token
  where project.name = 'household_photo_cleanup_url'
    and token.name = 'household_photo_cleanup_token'
    and length(token.decrypted_secret) >= 32
    and (exists (select 1 from private.household_join_photo_cleanup q where q.retry_at <= now())
      or exists (select 1 from private.household_join_staged_photos s
        where coalesce(s.cleanup_after, s.expires_at) <= now()));
$job$);
