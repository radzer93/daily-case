import { PROFILES } from './difficulty.ts';
import {
  type Difficulty,
  EDITOR_CRITERIA,
  EditorDecision,
  type EditorReview,
  type GeneratedCase,
  type GenEvidence,
  type SolverAnswer,
} from './types.ts';

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

  const isRef = (r: unknown) => typeof r === 'string' && (openIds.has(r) || suspectIds.includes(r));
  const steps = Array.isArray(c.deduction) ? c.deduction : [];
  if (steps.length < profile.minSteps) {
    errors.push(`deduction: at least ${profile.minSteps} steps required for ${difficulty}, found ${steps.length}.`);
  }
  for (const [i, step] of steps.entries()) {
    const uses = Array.isArray(step?.uses) ? step.uses : [];
    if (uses.length === 0 || !uses.every(isRef)) {
      errors.push(`deduction[${i + 1}]: must use only public evidence ids or suspect ids.`);
    }
    if (!isStr(step?.conclusion, 400)) errors.push(`deduction[${i + 1}]: conclusion missing.`);
  }
  const combined = steps.filter((s) => Array.isArray(s?.uses) && new Set(s.uses).size >= 2).length;
  if (combined < profile.minCombinedSteps) {
    errors.push(`deduction: at least ${profile.minCombinedSteps} steps must combine two or more items for ${difficulty}.`);
  }

  const leads = Array.isArray(c.false_leads) ? c.false_leads : [];
  const leadSuspects = new Set<string>();
  for (const lead of leads) {
    const id = lead?.suspect_id;
    if (!suspectIds.includes(id) || id === sol?.culprit) {
      errors.push(`false_leads: "${id}" is not an innocent suspect.`);
      continue;
    }
    const points = Array.isArray(lead.points_to_them) ? lead.points_to_them : [];
    const cleared = Array.isArray(lead.cleared_by) ? lead.cleared_by : [];
    if (points.length === 0 || !points.every(isRef) || cleared.length === 0 || !cleared.every(isRef)) {
      errors.push(`false_leads[${id}]: must point to public evidence or statements.`);
      continue;
    }
    leadSuspects.add(id);
  }
  if (leadSuspects.size < profile.minFalseLeads) {
    errors.push(`false_leads: at least ${profile.minFalseLeads} innocent suspects required for ${difficulty}, found ${leadSuspects.size}.`);
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
    deduction: c.deduction,
    false_leads: c.false_leads,
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

export interface EditorThresholds {
  min: number;
  reject: number;
}

export interface EditorVerdict {
  decision: EditorDecision;
  reasons: string[];
}

const DOWNGRADE: Partial<Record<Difficulty, Difficulty>> = { hard: 'medium' };

export function downgradeTarget(difficulty: Difficulty, review: unknown, thresholds: EditorThresholds): Difficulty | null {
  const lower = DOWNGRADE[difficulty];
  const scores = (review as EditorReview | null)?.scores;
  if (!lower || !scores || typeof scores !== 'object') return null;
  const valid = EDITOR_CRITERIA.every((k) => Number.isInteger(scores[k]) && scores[k] >= 1 && scores[k] <= 5);
  if (!valid || scores.difficulty_fit >= thresholds.min) return null;
  const othersOk = EDITOR_CRITERIA.filter((k) => k !== 'difficulty_fit').every((k) => scores[k] >= thresholds.min);
  return othersOk ? lower : null;
}

export function decideEditorial(review: unknown, thresholds: EditorThresholds): EditorVerdict {
  const scores = (review as EditorReview | null)?.scores;
  if (!scores || typeof scores !== 'object') {
    return { decision: EditorDecision.reject, reasons: ['Editor scores missing.'] };
  }
  const missing = EDITOR_CRITERIA.filter((k) => !Number.isInteger(scores[k]) || scores[k] < 1 || scores[k] > 5);
  if (missing.length) {
    return { decision: EditorDecision.reject, reasons: [`Invalid editor scores: ${missing.join(', ')}.`] };
  }
  if (scores.content <= thresholds.reject) {
    return { decision: EditorDecision.reject, reasons: [`content scored ${scores.content}.`] };
  }
  const low = EDITOR_CRITERIA.filter((k) => scores[k] <= thresholds.reject);
  if (low.length) {
    return { decision: EditorDecision.reject, reasons: low.map((k) => `${k} scored ${scores[k]}.`) };
  }
  const weak = EDITOR_CRITERIA.filter((k) => scores[k] < thresholds.min);
  if (weak.length) {
    return { decision: EditorDecision.borderline, reasons: weak.map((k) => `${k} scored ${scores[k]}.`) };
  }
  return { decision: EditorDecision.approve, reasons: [] };
}

export function revisable(review: unknown, thresholds: EditorThresholds): boolean {
  const scores = (review as EditorReview | null)?.scores;
  if (!scores || typeof scores !== 'object') return false;
  const valid = EDITOR_CRITERIA.every((k) => Number.isInteger(scores[k]) && scores[k] >= 1 && scores[k] <= 5);
  if (!valid) return false;
  if (scores.content < thresholds.min || scores.difficulty_fit < thresholds.min) return false;
  return EDITOR_CRITERIA.every((k) => scores[k] > thresholds.reject);
}

const ids = (items: { id: string }[] | undefined) => (items ?? []).map((i) => i.id).join(',');

export function structureChanges(before: GeneratedCase, after: GeneratedCase): string[] {
  const changes: string[] = [];
  if (ids(before.suspects) !== ids(after?.suspects)) changes.push('suspect ids changed');
  if (ids(before.motives) !== ids(after?.motives)) changes.push('motive ids changed');
  const evidence = (c: GeneratedCase | undefined) => (c?.evidence ?? []).map((e) => `${e.id}:${e.hint}`).join(',');
  if (evidence(before) !== evidence(after)) changes.push('evidence ids or hint flags changed');
  const sol = (c: GeneratedCase | undefined) =>
    c?.solution ? `${c.solution.culprit}|${c.solution.motive}|${[...(c.solution.evidence ?? [])].sort().join(',')}` : '';
  if (sol(before) !== sol(after)) changes.push('solution changed');
  return changes;
}
