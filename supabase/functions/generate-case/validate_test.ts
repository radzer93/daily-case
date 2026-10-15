import { assert, assertEquals } from 'jsr:@std/assert@1';
import { EXAMPLE_CASE } from './example_case.ts';
import { LOCALES, pickSeed, SETTINGS } from './seeds.ts';
import { EditorDecision, type EditorScores, type GeneratedCase, type SolverAnswer } from './types.ts';
import { decideEditorial, evaluateSolverRuns, splitCase, validateCase } from './validate.ts';
import { parseRetryDelayMs, QuotaExceededError, quotaError } from './llm.ts';

const base = (): GeneratedCase => structuredClone(EXAMPLE_CASE) as GeneratedCase;

const answer = (over: Partial<SolverAnswer> = {}): SolverAnswer => ({
  culprit: 'pawel',
  motive: 'dlugi',
  evidence: 'e1',
  other_possible_culprits: [],
  confidence: 'certain',
  reasoning: '',
  ...over,
});

Deno.test('reference case passes validation', () => {
  assertEquals(validateCase(base(), 'easy'), []);
});

Deno.test('detects wrong number of hints', () => {
  const c = base();
  c.evidence[0].hint = true;
  assert(validateCase(c, 'easy').some((e) => e.includes('exactly 2 hints')));
});

Deno.test('key evidence must be public', () => {
  const c = base();
  c.solution.evidence = ['e5'];
  assert(validateCase(c, 'easy').some((e) => e.includes('must be public')));
});

Deno.test('every innocent suspect must be excluded by public material', () => {
  const c = base();
  c.innocence_check = [{ suspect_id: 'kinga', excluded_by: ['e6'], reason: 'hint only' }];
  const errors = validateCase(c, 'easy');
  assert(errors.some((e) => e.includes('"igor"')));
  assert(errors.some((e) => e.includes('innocence_check[kinga]')));
});

Deno.test('split keeps solution and hint texts out of public content', () => {
  const { content, secret } = splitCase(base());
  const text = JSON.stringify(content);
  assert(!text.includes('solution'));
  for (const hintText of Object.values(secret.hints as Record<string, string>)) {
    assert(!text.includes(hintText));
  }
  const hint = (content.evidence as { id: string; text?: string }[]).find((e) => e.id === 'e5');
  assertEquals(hint?.text, undefined);
  assert((secret.hints as Record<string, string>).e5.length > 0);
});

Deno.test('solver: consistent hits are accepted', () => {
  const v = evaluateSolverRuns(base(), [answer(), answer({ evidence: 'e4' }), answer()]);
  assert(v.ok, v.reasons.join('; '));
});

Deno.test('solver: other culprit or doubt is rejected', () => {
  assertEquals(evaluateSolverRuns(base(), [answer(), answer({ culprit: 'igor' })]).ok, false);
  assertEquals(evaluateSolverRuns(base(), [answer({ other_possible_culprits: ['kinga'] })]).ok, false);
  assertEquals(evaluateSolverRuns(base(), [answer({ confidence: 'guess' })]).ok, false);
});

Deno.test('solver: unanimous other public evidence is added', () => {
  const v = evaluateSolverRuns(base(), [answer({ evidence: 'e2' }), answer({ evidence: 'e2' })]);
  assert(v.ok);
  assertEquals(v.extraEvidence, 'e2');
});

Deno.test('difficulty profile is enforced', () => {
  const errors = validateCase(base(), 'medium');
  assert(errors.some((e) => e.includes('exactly 4 required for medium')));
  const hard = validateCase(base(), 'hard');
  assert(hard.some((e) => e.includes('exactly 7 items required for hard')));
});

Deno.test('suspects must be adults', () => {
  const c = base();
  c.suspects[0].age = 17;
  assert(validateCase(c, 'easy').some((e) => e.includes('age outside 18–95')));
});

Deno.test('seed avoids recently used settings and locales', () => {
  const recent = SETTINGS.slice(0, 15).map((setting, i) => ({ seed: { setting, locale: LOCALES[i % 6].locale } }));
  const usedLocales = LOCALES.slice(0, 6).map((l) => l.locale);
  for (let i = 0; i < 50; i++) {
    const s = pickSeed(recent, { difficulty: 'medium' });
    assert(!SETTINGS.slice(0, 15).includes(s.setting));
    assert(!usedLocales.includes(s.locale));
  }
});

Deno.test('hard seed combines two different mechanisms', () => {
  for (let i = 0; i < 20; i++) {
    const s = pickSeed([], { difficulty: 'hard' });
    assert(s.secondMechanism !== undefined && s.secondMechanism !== s.mechanism);
  }
  assertEquals(pickSeed([], { difficulty: 'easy' }).secondMechanism, undefined);
});

Deno.test('dark ratio controls intensity', () => {
  assertEquals(pickSeed([], { difficulty: 'easy', darkRatio: 0 }).intensity, 'standard');
  assertEquals(pickSeed([], { difficulty: 'easy', darkRatio: 1 }).intensity, 'dark');
});

const scores = (overrides: Partial<EditorScores> = {}): EditorScores => ({
  logic: 5,
  fairness: 5,
  difficulty_fit: 4,
  setting: 4,
  language: 5,
  content: 5,
  originality: 4,
  ...overrides,
});

const THRESHOLDS = { min: 4, reject: 2 };

Deno.test('editor: all scores at or above minimum approve', () => {
  assertEquals(decideEditorial({ scores: scores(), issues: [], summary: '' }, THRESHOLDS).decision, EditorDecision.approve);
});

Deno.test('editor: a score at the reject threshold rejects', () => {
  const v = decideEditorial({ scores: scores({ language: 2 }), issues: [], summary: '' }, THRESHOLDS);
  assertEquals(v.decision, EditorDecision.reject);
  assert(v.reasons[0].includes('language'));
  assertEquals(decideEditorial({ scores: scores({ content: 1 }), issues: [], summary: '' }, THRESHOLDS).decision, EditorDecision.reject);
});

Deno.test('editor: a score between thresholds is borderline', () => {
  assertEquals(
    decideEditorial({ scores: scores({ originality: 3 }), issues: [], summary: '' }, THRESHOLDS).decision,
    EditorDecision.borderline,
  );
});

Deno.test('editor: missing or invalid scores reject', () => {
  assertEquals(decideEditorial(null, THRESHOLDS).decision, EditorDecision.reject);
  const bad = { ...scores(), fairness: 7 };
  assertEquals(decideEditorial({ scores: bad, issues: [], summary: '' }, THRESHOLDS).decision, EditorDecision.reject);
});

Deno.test('quota: daily limit stops retries until the reset', () => {
  const now = new Date('2026-10-12T08:00:00Z');
  const text = 'Gemini API 429: {"error":{"message":"Rate limit exceeded for model gemini-3.8-flash (limit: 20 requests per day on Free Tier). Please retry in 15h24m28s"}}';
  assertEquals(parseRetryDelayMs(text), (15 * 3600 + 24 * 60 + 28) * 1000);
  const e = quotaError(429, text, now);
  assert(e instanceof QuotaExceededError);
  assertEquals(e.retryAt.toISOString(), '2026-10-12T11:00:00.000Z');
});

Deno.test('quota: project quota without a delay waits one hour', () => {
  const now = new Date('2026-10-14T01:00:00Z');
  const e = quotaError(429, '{"error":{"message":"Your project has exceeded a quota. See https://ai.dev/rate-limit"}}', now);
  assert(e instanceof QuotaExceededError);
  assertEquals(e.retryAt.toISOString(), '2026-10-14T02:00:00.000Z');
});

Deno.test('quota: short rate limits and other errors are retried', () => {
  assertEquals(quotaError(429, 'Too many requests, retry in 20s'), null);
  assertEquals(quotaError(429, '{"retryDelay": "30s"}'), null);
  assertEquals(quotaError(503, 'per day'), null);
});
