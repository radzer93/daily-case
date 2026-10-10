export const AlertFlag = {
  inappropriate: 'inappropriate',
  manyReports: 'many_reports',
  lowRating: 'low_rating',
  missingCase: 'missing_case',
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
    last_errors?: { stage: string; at: string }[];
  };
}

const FLAG_TEXT: Record<AlertFlag, string> = {
  [AlertFlag.inappropriate]: 'Reported as inappropriate content',
  [AlertFlag.manyReports]: 'Many player reports',
  [AlertFlag.lowRating]: 'Low player rating',
  [AlertFlag.missingCase]: 'No published case',
};

const URGENT: AlertFlag[] = [AlertFlag.inappropriate, AlertFlag.missingCase];

const escape = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function describe(a: QualityAlert): string {
  const d = a.detail ?? {};
  if (a.flag === AlertFlag.missingCase) {
    const errors = (d.last_errors ?? []).map((e) => e.stage).join(', ');
    return `Players see no case for this level. Recent generator errors: ${errors || 'none'}.`;
  }
  const reports = Object.entries(d.reports ?? {}).map(([k, n]) => `${k} ×${n}`).join(', ');
  return `Reports: ${reports || 'none'}. Ratings: ${d.ratings ?? 0}, average ${d.avg_rating ?? '-'}.`;
}

function headline(a: QualityAlert): string {
  const title = a.title ? ` "${a.title}"` : '';
  return `${FLAG_TEXT[a.flag] ?? a.flag}: ${a.date} ${a.difficulty}${title}`;
}

export function buildAlertEmail(alerts: QualityAlert[]): { subject: string; text: string; html: string } {
  const urgent = alerts.some((a) => URGENT.includes(a.flag));
  const subject = `${urgent ? '[URGENT] ' : ''}Sprawa Dnia: ${alerts.length} quality alert${alerts.length === 1 ? '' : 's'}`;
  const killSwitch = (a: QualityAlert) =>
    `update private.cases set status = 'rejected' where case_date = date '${a.date}' and difficulty = '${a.difficulty}' and status = 'approved';`;

  const text = [
    ...alerts.map((a) =>
      [headline(a), describe(a), a.flag === AlertFlag.missingCase ? '' : `Kill switch: ${killSwitch(a)}`]
        .filter(Boolean)
        .join('\n')
    ),
    'Details: run supabase/sql/weekly_report.sql in the Supabase SQL Editor.',
  ].join('\n\n');

  const html = `<div style="font-family:sans-serif;font-size:14px;line-height:1.5">
${alerts
  .map(
    (a) => `<p><strong>${escape(headline(a))}</strong><br>${escape(describe(a))}${
      a.flag === AlertFlag.missingCase ? '' : `<br><code style="font-size:12px">${escape(killSwitch(a))}</code>`
    }</p>`
  )
  .join('\n')}
<p style="color:#666">Details: run <code>supabase/sql/weekly_report.sql</code> in the Supabase SQL Editor.</p>
</div>`;

  return { subject, text, html };
}
