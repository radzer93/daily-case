import { assert, assertEquals } from 'jsr:@std/assert@1';
import { EXAMPLE_CASE } from './example_case.ts';
import { pickSeed, SETTINGS } from './seeds.ts';
import type { GeneratedCase, SolverAnswer } from './types.ts';
import { evaluateSolverRuns, splitCase, validateCase } from './validate.ts';

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
  assertEquals(validateCase(base()), []);
});

Deno.test('detects wrong number of hints', () => {
  const c = base();
  c.evidence[0].hint = true;
  assert(validateCase(c).some((e) => e.includes('exactly 2 hints')));
});

Deno.test('key evidence must be public', () => {
  const c = base();
  c.solution.evidence = ['e5'];
  assert(validateCase(c).some((e) => e.includes('must be public')));
});

Deno.test('every innocent suspect must be excluded by public material', () => {
  const c = base();
  c.innocence_check = [{ suspect_id: 'kinga', excluded_by: ['e6'], reason: 'hint only' }];
  const errors = validateCase(c);
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

Deno.test('seed avoids recently used settings', () => {
  const recent = SETTINGS.slice(0, 10).map((setting) => ({ seed: { setting } }));
  for (let i = 0; i < 50; i++) {
    const s = pickSeed(recent);
    assert(!SETTINGS.slice(0, 10).includes(s.setting));
  }
});
