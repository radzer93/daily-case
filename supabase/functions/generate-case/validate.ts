import { PROFILES } from './difficulty.ts';
import type { Difficulty, GeneratedCase, GenEvidence, SolverAnswer } from './types.ts';

const ID_RE = /^[a-z][a-z0-9_-]{0,23}$/;

const isStr = (v: unknown, max = 2000): v is string =>
  typeof v === 'string' && v.trim().length > 0 && v.length <= max;

const strArray = (v: unknown, min: number, max: number, maxLen = 900): v is string[] =>
  Array.isArray(v) && v.length >= min && v.length <= max && v.every((s) => isStr(s, maxLen));

function dupes(ids: string[]): string[] {
  const seen = new Set<string>();
  const out = new Set<string>();
  for (const id of ids) (seen.has(id) ? out : seen).add(id);
  return [...out];
}

export function validateCase(input: unknown, difficulty: Difficulty): string[] {
  const errors: string[] = [];
  const profile = PROFILES[difficulty];
  const c = input as GeneratedCase;
  if (!c || typeof c !== 'object') return ['Case object missing.'];

  if (!isStr(c.title, 40)) errors.push('title: empty or longer than 40 characters.');
  if (isStr(c.title) && c.title.includes(':')) errors.push('title: contains a colon.');
  if (!isStr(c.docket, 30)) errors.push('docket: missing.');
  if (!isStr(c.place, 60)) errors.push('place: missing.');
  if (!isStr(c.date, 40)) errors.push('date: missing.');
  if (!strArray(c.brief, 1, 3, 700)) errors.push('brief: 1–3 paragraphs of up to 700 characters required.');

  const suspects = Array.isArray(c.suspects) ? c.suspects : [];
  if (suspects.length !== profile.suspects) {
    errors.push(`suspects: exactly ${profile.suspects} required for ${difficulty}, found ${suspects.length}.`);
  }
  for (const s of suspects) {
    if (!ID_RE.test(String(s?.id))) errors.push(`suspects: invalid id "${s?.id}".`);
    if (!isStr(s?.name, 60)) errors.push(`suspects[${s?.id}]: name missing.`);
    if (!Number.isInteger(s?.age) || s.age < 18 || s.age > 95) errors.push(`suspects[${s?.id}]: age outside 18–95.`);
    if (!isStr(s?.role, 120)) errors.push(`suspects[${s?.id}]: role missing.`);
    if (!strArray(s?.statement, 1, 3, 700)) errors.push(`suspects[${s?.id}]: statement must be 1–3 paragraphs of up to 700 characters.`);
  }
  const suspectIds = suspects.map((s) => s?.id);
  for (const d of dupes(suspectIds)) errors.push(`suspects: duplicate id "${d}".`);

  const evidence: GenEvidence[] = Array.isArray(c.evidence) ? c.evidence : [];
  if (evidence.length !== profile.evidence) {
    errors.push(`evidence: exactly ${profile.evidence} items required for ${difficulty}, found ${evidence.length}.`);
  }
  for (const e of evidence) {
    if (!isStr(e?.id, 10)) errors.push('evidence: id missing.');
    if (!isStr(e?.title, 80)) errors.push(`evidence[${e?.id}]: title missing.`);
    if (!isStr(e?.text, 600)) errors.push(`evidence[${e?.id}]: text missing or longer than 600 characters.`);
    if (typeof e?.hint !== 'boolean') errors.push(`evidence[${e?.id}]: hint must be true or false.`);
  }
  const evidenceIds = evidence.map((e) => e?.id);
  for (const d of dupes(evidenceIds)) errors.push(`evidence: duplicate id "${d}".`);
  const hints = evidence.filter((e) => e?.hint === true);
  if (hints.length !== 2) errors.push(`evidence: exactly 2 hints required, found ${hints.length}.`);
  const openIds = new Set(evidence.filter((e) => e?.hint === false).map((e) => e.id));

  const motives = Array.isArray(c.motives) ? c.motives : [];
  if (motives.length !== 4) errors.push('motives: exactly 4 required.');
  for (const m of motives) {
    if (!ID_RE.test(String(m?.id))) errors.push(`motives: invalid id "${m?.id}".`);
    if (!isStr(m?.label, 60)) errors.push(`motives[${m?.id}]: label missing.`);
  }
  for (const d of dupes(motives.map((m) => m?.id))) errors.push(`motives: duplicate id "${d}".`);

  const sol = c.solution;
  if (!sol || typeof sol !== 'object') {
    errors.push('solution: missing.');
  } else {
    if (!suspectIds.includes(sol.culprit)) errors.push('solution.culprit: no such suspect.');
    if (!motives.some((m) => m?.id === sol.motive)) errors.push('solution.motive: no such motive.');
    if (!Array.isArray(sol.evidence) || sol.evidence.length < 1 || sol.evidence.length > 2) {
      errors.push('solution.evidence: 1–2 items required.');
    } else {
      for (const id of sol.evidence) {
        if (!evidenceIds.includes(id)) errors.push(`solution.evidence: no evidence "${id}".`);
      }
      if (!sol.evidence.some((id) => openIds.has(id))) {
        errors.push('solution.evidence: at least one key item must be public (not a hint).');
      }
    }
    if (!strArray(sol.explain, 2, 4, 900)) errors.push('solution.explain: 2–4 paragraphs required.');
  }

  const checks = Array.isArray(c.innocence_check) ? c.innocence_check : [];
  const innocent = suspectIds.filter((id) => id !== sol?.culprit);
  for (const id of innocent) {
    const check = checks.find((k) => k?.suspect_id === id);
    if (!check) {
      errors.push(`innocence_check: no justification for excluding "${id}".`);
      continue;
    }
    const refs = Array.isArray(check.excluded_by) ? check.excluded_by : [];
    const valid = refs.filter((r) => openIds.has(r) || suspectIds.includes(r));
    if (valid.length === 0) {
      errors.push(`innocence_check[${id}]: exclusion must rely on public evidence or a statement.`);
    }
  }

  return errors;
}

export function splitCase(c: GeneratedCase): { content: Record<string, unknown>; secret: Record<string, unknown> } {
  const content = {
    docket: c.docket,
    place: c.place,
    date: c.date,
    note: null,
    brief: c.brief,
    suspects: c.suspects.map(({ id, name, age, role, statement }) => ({ id, name, age, role, statement })),
    evidence: c.evidence.map((e) =>
      e.hint ? { id: e.id, title: e.title, hint: true } : { id: e.id, title: e.title, text: e.text, hint: false }
    ),
    motives: c.motives.map(({ id, label }) => ({ id, label })),
  };
  const secret = {
    solution: c.solution,
    hints: Object.fromEntries(c.evidence.filter((e) => e.hint).map((e) => [e.id, e.text])),
    innocence_check: c.innocence_check,
  };
  return { content, secret };
}

export interface SolverVerdict {
  ok: boolean;
  reasons: string[];
  extraEvidence?: string;
}

export function evaluateSolverRuns(c: GeneratedCase, runs: SolverAnswer[]): SolverVerdict {
  const reasons: string[] = [];
  if (runs.length === 0) return { ok: false, reasons: ['No solver runs.'] };

  runs.forEach((r, i) => {
    const n = i + 1;
    if (r.culprit !== c.solution.culprit) reasons.push(`Run ${n}: picked "${r.culprit}" instead of "${c.solution.culprit}".`);
    if (r.motive !== c.solution.motive) reasons.push(`Run ${n}: motive "${r.motive}" instead of "${c.solution.motive}".`);
    const others = (r.other_possible_culprits ?? []).filter((id) => id !== c.solution.culprit);
    if (others.length > 0) reasons.push(`Run ${n}: other possible culprits: ${others.join(', ')}.`);
    if (r.confidence === 'guess') reasons.push(`Run ${n}: guessed.`);
  });

  const openIds = new Set(c.evidence.filter((e) => !e.hint).map((e) => e.id));
  const hits = runs.filter((r) => c.solution.evidence.includes(r.evidence)).length;
  let extraEvidence: string | undefined;
  if (hits * 2 < runs.length) {
    const first = runs[0].evidence;
    const unanimous = runs.every((r) => r.evidence === first);
    if (unanimous && openIds.has(first) && c.solution.evidence.length < 3) {
      extraEvidence = first;
    } else {
      reasons.push(`Evidence: only ${hits}/${runs.length} runs picked evidence from the solution.`);
    }
  }

  return { ok: reasons.length === 0, reasons, extraEvidence };
}
