select cron.schedule(
  'daily-case-alerts',
  '5 * * * *',
  $$
  select net.http_post(
    url     := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
               || '/functions/v1/quality-alert',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
               ),
    body    := '{}'::jsonb,
    timeout_milliseconds := 10000
  );
  $$
);
