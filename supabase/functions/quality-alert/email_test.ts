import { assert, assertEquals } from 'jsr:@std/assert@1';
import { AlertFlag, buildAlertEmail, type QualityAlert } from './email.ts';

const caseAlert = (flag: AlertFlag): QualityAlert => ({
  key: `case:1:${flag}`,
  flag,
  date: '2026-10-15',
  difficulty: 'medium',
  title: 'Martwy <sezon>',
  detail: { reports: { contradiction: 3 }, report_count: 3, ratings: 4, avg_rating: 3.5 },
});

Deno.test('report alerts are not urgent and include the kill switch', () => {
  const e = buildAlertEmail([caseAlert(AlertFlag.manyReports)]);
  assertEquals(e.subject, 'Sprawa Dnia: 1 quality alert');
  assert(e.text.includes("case_date = date '2026-10-15' and difficulty = 'medium'"));
  assert(e.text.includes('contradiction ×3'));
});

Deno.test('inappropriate content and missing cases are urgent', () => {
  const missing: QualityAlert = {
    key: 'slot:2026-10-15:hard:missing',
    flag: AlertFlag.missingCase,
    date: '2026-10-15',
    difficulty: 'hard',
    title: null,
    detail: {
      slot_statuses: { rejected: 2 },
      last_run: '2026-10-15T01:00:00Z',
      recent_log: [{ stage: 'validation', ok: false, date: '2026-10-15', at: '2026-10-15T01:00:00Z' }],
    },
  };
  const e = buildAlertEmail([caseAlert(AlertFlag.inappropriate), missing], new Date('2026-10-15T01:30:00Z'));
  assert(e.subject.startsWith('[URGENT]'));
  assert(e.subject.includes('2 quality alerts'));
  assert(e.text.includes('validation (failed)'));
  assert(e.text.includes('rejected ×2'));
  assert(e.text.includes('last active 30 min ago'));
  assert(!e.text.includes("difficulty = 'hard'"));
});

Deno.test('html escapes case titles', () => {
  const e = buildAlertEmail([caseAlert(AlertFlag.lowRating)]);
  assert(e.html.includes('Martwy &lt;sezon&gt;'));
  assert(!e.html.includes('<sezon>'));
});

Deno.test('missing case reports a silent generator', () => {
  const missing = (lastRun: string | null): QualityAlert => ({
    key: 'slot:2026-10-11:easy:missing',
    flag: AlertFlag.missingCase,
    date: '2026-10-11',
    difficulty: 'easy',
    title: null,
    detail: { last_run: lastRun, recent_log: [] },
  });
  const now = new Date('2026-10-11T12:00:00Z');
  assert(buildAlertEmail([missing(null)], now).text.includes('never logged a run'));
  assert(buildAlertEmail([missing('2026-10-10T12:00:00Z')], now).text.includes('has not logged anything for 24 h'));
});

Deno.test('missing case explains an exhausted quota', () => {
  const e = buildAlertEmail([{
    key: 'slot:2026-10-12:easy:missing',
    flag: AlertFlag.missingCase,
    date: '2026-10-12',
    difficulty: 'easy',
    title: null,
    detail: { last_run: '2026-10-12T06:00:00Z', recent_log: [{ stage: 'quota', ok: false, date: '2026-10-12', at: '2026-10-12T06:00:00Z' }] },
  }], new Date('2026-10-12T12:00:00Z'));
  assert(e.text.includes('quota is exhausted'));
  assert(!e.text.includes('check the cron job'));
});
