import { createClient } from 'jsr:@supabase/supabase-js@2';
import { buildAlertEmail, type QualityAlert } from './email.ts';

const env = (name: string, fallback?: string): string => {
  const v = Deno.env.get(name) ?? fallback;
  if (v === undefined || v === '') throw new Error(`Missing environment variable ${name}.`);
  return v;
};

const RESEND_URL = 'https://api.resend.com/emails';

const CONFIG = {
  to: () => env('ALERT_EMAIL'),
  from: () => env('ALERT_FROM', 'Sprawa Dnia <onboarding@resend.dev>'),
  resendKey: () => env('RESEND_API_KEY'),
  minReports: () => Number(env('ALERT_MIN_REPORTS', '3')),
  minRatings: () => Number(env('ALERT_MIN_RATINGS', '5')),
  lowRating: () => Number(env('ALERT_LOW_RATING', '2.5')),
  tomorrowCheckHour: () => Number(env('ALERT_TOMORROW_HOUR', '18')),
};

const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), {
  auth: { persistSession: false },
});

async function sendEmail(alerts: QualityAlert[]): Promise<void> {
  const { subject, text, html } = buildAlertEmail(alerts);
  const res = await fetch(RESEND_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${CONFIG.resendKey()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from: CONFIG.from(), to: [CONFIG.to()], subject, text, html }),
  });
  if (!res.ok) throw new Error(`Resend ${res.status}: ${await res.text()}`);
}

async function run(dryRun: boolean): Promise<Record<string, unknown>> {
  const { data, error } = await db.rpc('admin_quality_alerts', {
    p_min_reports: CONFIG.minReports(),
    p_min_ratings: CONFIG.minRatings(),
    p_low_rating: CONFIG.lowRating(),
    p_tomorrow_check_hour: CONFIG.tomorrowCheckHour(),
  });
  if (error) throw new Error(`admin_quality_alerts: ${error.message}`);

  const alerts = (data ?? []) as QualityAlert[];
  if (alerts.length === 0) return { status: 'ok', alerts: 0 };
  if (dryRun) return { status: 'dry_run', alerts };

  await sendEmail(alerts);
  const { error: markError } = await db.rpc('admin_mark_alerts_sent', { p_alerts: alerts });
  if (markError) throw new Error(`admin_mark_alerts_sent: ${markError.message}`);
  return { status: 'sent', alerts: alerts.length };
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  if (req.headers.get('x-cron-secret') !== Deno.env.get('CRON_SECRET')) {
    return json({ error: 'forbidden' }, 403);
  }
  const body = await req.json().catch(() => ({}));
  try {
    return json(await run(body?.dry_run === true));
  } catch (e) {
    console.error(e);
    return json({ status: 'error', detail: String(e) }, 500);
  }
});
