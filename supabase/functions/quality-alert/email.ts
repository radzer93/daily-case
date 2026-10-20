export const AlertFlag = {
  inappropriate: 'inappropriate',
  manyReports: 'many_reports',
  lowRating: 'low_rating',
  missingCase: 'missing_case',
  missingTomorrow: 'missing_tomorrow',
} as const;
export type AlertFlag = (typeof AlertFlag)[keyof typeof AlertFlag];

export interface QualityAlert {
  key: string;
  flag: AlertFlag;
  date: string;
  difficulty: string;
  title: string | null;
  detail: {
    reports?: Record<string, number>;
    report_count?: number;
    ratings?: number;
    avg_rating?: number | null;
    slot_statuses?: Record<string, number>;
    last_run?: string | null;
    last_success?: string | null;
    recent_log?: { stage: string; ok: boolean; date: string | null; at: string }[];
  };
}

const STALE_HOURS = 2;
const QUOTA_STAGE = 'quota';

const hoursSince = (iso: string | null | undefined, now: Date): number | null =>
  iso ? (now.getTime() - new Date(iso).getTime()) / 3_600_000 : null;

const FLAG_TEXT: Record<AlertFlag, string> = {
  [AlertFlag.inappropriate]: 'Reported as inappropriate content',
  [AlertFlag.manyReports]: 'Many player reports',
  [AlertFlag.lowRating]: 'Low player rating',
  [AlertFlag.missingCase]: 'No published case today',
  [AlertFlag.missingTomorrow]: 'No case ready for tomorrow',
};

const SLOT_FLAGS: AlertFlag[] = [AlertFlag.missingCase, AlertFlag.missingTomorrow];

const URGENT: AlertFlag[] = [AlertFlag.inappropriate, AlertFlag.missingCase];

const escape = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function describeMissing(a: QualityAlert, now: Date): string {
  const d = a.detail ?? {};
  const parts = [
    a.flag === AlertFlag.missingCase
      ? 'Players see no case for this level.'
      : 'Players will see no case at midnight unless the generator finishes it overnight.',
  ];
  const sinceRun = hoursSince(d.last_run, now);
  const quota = (d.recent_log ?? [])[0]?.stage === QUOTA_STAGE;
  if (quota) {
    parts.push('The AI provider quota is exhausted; generation resumes automatically when it resets.');
  } else if (sinceRun === null) {
    parts.push('The generator has never logged a run: check the cron job and the function secrets.');
  } else if (sinceRun > STALE_HOURS) {
    parts.push(`The generator has not logged anything for ${Math.round(sinceRun)} h: check the cron job (net._http_response).`);
  } else {
    parts.push(`Generator last active ${Math.round(sinceRun * 60)} min ago.`);
  }
  const statuses = Object.entries(d.slot_statuses ?? {}).map(([k, n]) => `${k} ×${n}`).join(', ');
  parts.push(`Cases in this slot: ${statuses || 'none'}.`);
  const log = (d.recent_log ?? []).map((l) => `${l.stage}${l.ok ? '' : ' (failed)'} ${l.date ?? ''}`.trim()).join('; ');
  if (log) parts.push(`Recent log: ${log}.`);
  return parts.join(' ');
}

function describe(a: QualityAlert, now: Date): string {
  const d = a.detail ?? {};
  if (SLOT_FLAGS.includes(a.flag)) return describeMissing(a, now);
  const reports = Object.entries(d.reports ?? {}).map(([k, n]) => `${k} ×${n}`).join(', ');
  return `Reports: ${reports || 'none'}. Ratings: ${d.ratings ?? 0}, average ${d.avg_rating ?? '-'}.`;
}

function headline(a: QualityAlert): string {
  const title = a.title ? ` "${a.title}"` : '';
  return `${FLAG_TEXT[a.flag] ?? a.flag}: ${a.date} ${a.difficulty}${title}`;
}

export function buildAlertEmail(
  alerts: QualityAlert[],
  now: Date = new Date(),
): { subject: string; text: string; html: string } {
  const urgent = alerts.some((a) => URGENT.includes(a.flag));
  const subject = `${urgent ? '[URGENT] ' : ''}Sprawa Dnia: ${alerts.length} quality alert${alerts.length === 1 ? '' : 's'}`;
  const killSwitch = (a: QualityAlert) =>
    `update private.cases set status = 'rejected' where case_date = date '${a.date}' and difficulty = '${a.difficulty}' and status = 'approved';`;

  const text = [
    ...alerts.map((a) =>
      [headline(a), describe(a, now), SLOT_FLAGS.includes(a.flag) ? '' : `Kill switch: ${killSwitch(a)}`]
        .filter(Boolean)
        .join('\n')
    ),
    'Details: run supabase/sql/weekly_report.sql in the Supabase SQL Editor.',
  ].join('\n\n');

  const html = `<div style="font-family:sans-serif;font-size:14px;line-height:1.5">
${alerts
  .map(
    (a) => `<p><strong>${escape(headline(a))}</strong><br>${escape(describe(a, now))}${
      SLOT_FLAGS.includes(a.flag) ? '' : `<br><code style="font-size:12px">${escape(killSwitch(a))}</code>`
    }</p>`
  )
  .join('\n')}
<p style="color:#666">Details: run <code>supabase/sql/weekly_report.sql</code> in the Supabase SQL Editor.</p>
</div>`;

  return { subject, text, html };
}
