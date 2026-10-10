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
    detail: { last_errors: [{ stage: 'validation', at: '2026-10-15T01:00:00Z' }] },
  };
  const e = buildAlertEmail([caseAlert(AlertFlag.inappropriate), missing]);
  assert(e.subject.startsWith('[URGENT]'));
  assert(e.subject.includes('2 quality alerts'));
  assert(e.text.includes('validation'));
  assert(!e.text.includes("difficulty = 'hard'"));
});

Deno.test('html escapes case titles', () => {
  const e = buildAlertEmail([caseAlert(AlertFlag.lowRating)]);
  assert(e.html.includes('Martwy &lt;sezon&gt;'));
  assert(!e.html.includes('<sezon>'));
});
