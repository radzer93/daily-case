create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net  with schema extensions;

select vault.create_secret('https://YOUR-PROJECT.supabase.co', 'project_url');
select vault.create_secret('YOUR_CRON_SECRET', 'cron_secret');

select cron.schedule(
  'daily-case-generate',
  '7 * * * *',
  $$
  select net.http_post(
    url     := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
               || '/functions/v1/generate-case',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
               ),
    body    := '{}'::jsonb,
    timeout_milliseconds := 10000
  );
  $$
);

