import { createClient } from 'jsr:@supabase/supabase-js@2';
import { anthropicClient } from './anthropic.ts';
import { geminiClient } from './gemini.ts';
import { type LlmClient, QuotaExceededError, sleep } from './llm.ts';
import {
  buildEditorUser,
  buildGeneratorUser,
  buildRevisionUser,
  buildSolverUser,
  CASE_SCHEMA,
  EDITOR_SCHEMA,
  EDITOR_SYSTEM,
  GENERATOR_SYSTEM,
  SOLVER_SCHEMA,
  SOLVER_SYSTEM,
} from './prompt.ts';
import { pickSeed } from './seeds.ts';
import {
  CaseKind,
  CaseStatus,
  DIFFICULTIES,
  type Difficulty,
  EditorDecision,
  type EditorReview,
  type GeneratedCase,
  type RecentCase,
  type Seed,
  type SolverAnswer,
} from './types.ts';
import {
  decideEditorial,
  downgradeTarget,
  evaluateSolverRuns,
  revisable,
  splitCase,
  structureChanges,
  validateCase,
} from './validate.ts';

const env = (name: string, fallback?: string): string => {
  const v = Deno.env.get(name) ?? fallback;
  if (v === undefined || v === '') throw new Error(`Missing environment variable ${name}.`);
  return v;
};

const DEFAULT_MODEL: Record<string, string> = {
  gemini: 'gemini-3.8-flash',
  anthropic: 'claude-sonnet-5-5',
};

const CONFIG = {
  provider: () => env('LLM_PROVIDER', 'gemini'),
  model: () => env('GEN_MODEL', DEFAULT_MODEL[CONFIG.provider()]),
  solverModel: () => env('SOLVER_MODEL', CONFIG.model()),
  maxTokens: () => Number(env('GEN_MAX_TOKENS', CONFIG.provider() === 'gemini' ? '24000' : '8000')),
  solverMaxTokens: () => Number(env('SOLVER_MAX_TOKENS', CONFIG.provider() === 'gemini' ? '8000' : '1500')),
  solverRuns: () => Math.max(1, Number(env('SOLVER_RUNS', '3'))),
  solverDelayMs: () => Number(env('SOLVER_DELAY_MS', '2000')),
  solverThinking: () => env('SOLVER_THINKING', 'medium'),
  daysAhead: () => Number(env('DAYS_AHEAD', '7')),
  darkRatio: () => Number(env('DARK_RATIO', '0.25')),
  requireReview: () => env('REQUIRE_REVIEW', 'false') === 'true',
  editorModel: () => env('EDITOR_MODEL', CONFIG.model()),
  editorThinking: () => env('EDITOR_THINKING', 'high'),
  editorMaxTokens: () => Number(env('EDITOR_MAX_TOKENS', CONFIG.provider() === 'gemini' ? '12000' : '2000')),
  editorMinScore: () => Number(env('EDITOR_MIN_SCORE', '4')),
  editorRejectScore: () => Number(env('EDITOR_REJECT_SCORE', '2')),
  editorBorderline: () => env('EDITOR_BORDERLINE', EditorDecision.reject),
  maxRevisions: () => Number(env('EDITOR_REVISIONS', '1')),
};

const BORDERLINE_STATUS: Record<string, CaseStatus> = {
  [EditorDecision.reject]: CaseStatus.rejected,
  [EditorDecision.approve]: CaseStatus.approved,
  pending: CaseStatus.pending,
};

function llm(model: string, thinking = env('GEMINI_THINKING', 'high')): LlmClient {
  const provider = CONFIG.provider();
  if (provider === 'anthropic') return anthropicClient(env('ANTHROPIC_API_KEY'), model);
  if (provider === 'gemini') return geminiClient(env('GEMINI_API_KEY'), model, thinking);
  throw new Error(`Unknown LLM_PROVIDER "${provider}". Use "gemini" or "anthropic".`);
}

const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), {
  auth: { persistSession: false },
});

async function log(caseDate: string | null, ok: boolean, stage: string, detail: Record<string, unknown>) {
  const { error } = await db.rpc('admin_log', { p_case_date: caseDate, p_ok: ok, p_stage: stage, p_detail: detail });
  if (error) console.error('admin_log', error.message);
}

type Outcome = { status: string; date?: string; difficulty?: Difficulty; detail?: unknown };

async function quotaOutcome(
  e: QuotaExceededError,
  model: string,
  date: string,
  difficulty: Difficulty,
  stage: string,
): Promise<Outcome> {
  const retryAt = e.retryAt.toISOString();
  await log(date, false, 'quota', { difficulty, stage, model, retry_at: retryAt, error: e.message });
  return { status: 'quota_exceeded', date, difficulty, detail: { stage, model, retry_at: retryAt } };
}
type Target = { date: string; difficulty: Difficulty; recent_failures?: number };
type Draft = {
  id: string;
  status?: CaseStatus;
  revisions?: number;
  revision_request?: Record<string, unknown> | null;
  case_date: string;
  difficulty: Difficulty;
  case: GeneratedCase;
  seed: Seed;
};

async function generateDraft(target: Target, recent: RecentCase[]): Promise<Outcome & { draft?: Draft }> {
  const { date, difficulty } = target;
  const seed = pickSeed(recent, { difficulty, darkRatio: CONFIG.darkRatio() });
  const client = llm(CONFIG.model());

  let gen;
  try {
    gen = await client.generate<GeneratedCase>({
      system: GENERATOR_SYSTEM,
      user: buildGeneratorUser(seed, recent),
      name: 'save_case',
      description: 'Saves a finished crime case.',
      schema: CASE_SCHEMA,
      maxTokens: CONFIG.maxTokens(),
      temperature: 1,
    });
  } catch (e) {
    if (e instanceof QuotaExceededError) return quotaOutcome(e, client.model, date, difficulty, 'generation');
    await log(date, false, 'generation', { difficulty, seed, error: String(e) });
    return { status: 'generation_failed', date, difficulty, detail: String(e) };
  }

  const draft = gen.data;
  const errors = validateCase(draft, difficulty);
  if (errors.length) {
    await log(date, false, 'validation', { difficulty, seed, errors, title: draft?.title });
    return { status: 'invalid', date, difficulty, detail: errors };
  }

  const { content, secret } = splitCase(draft);
  const { data: id, error } = await db.rpc('admin_insert_case', {
    p_case_date: date,
    p_difficulty: difficulty,
    p_status: CaseStatus.draft,
    p_kind: CaseKind.fictional,
    p_title: draft.title,
    p_content: content,
    p_secret: { ...secret, draft },
    p_meta: { source: 'ai', seed, provider: client.provider, usage: gen.usage, attempts: gen.attempts ?? 1 },
    p_model: client.model,
  });
  if (error) {
    await log(date, false, 'insert', { difficulty, title: draft.title, error: error.message });
    return { status: 'insert_failed', date, difficulty, detail: error.message };
  }

  await log(date, true, 'draft_saved', { id, difficulty, title: draft.title, seed });
  return {
    status: 'draft',
    date,
    difficulty,
    detail: { id, title: draft.title },
    draft: { id: id as string, status: CaseStatus.draft, case_date: date, difficulty, case: draft, seed },
  };
}

async function verifyDraft(d: Draft): Promise<Outcome & { draft?: Draft }> {
  const draft = d.case;
  if (!draft || !Array.isArray(draft.evidence)) {
    await db.rpc('admin_finalize_case', { p_id: d.id, p_status: CaseStatus.rejected, p_meta: { rejected_because: ['draft content missing'] } });
    await log(d.case_date, false, 'solver_rejected', { id: d.id, difficulty: d.difficulty, reasons: ['draft content missing'] });
    return { status: CaseStatus.rejected, date: d.case_date, difficulty: d.difficulty, detail: 'draft content missing' };
  }
  const client = llm(CONFIG.solverModel(), CONFIG.solverThinking());
  const user = buildSolverUser(draft);
  const runs: SolverAnswer[] = [];

  try {
    for (let i = 0; i < CONFIG.solverRuns(); i++) {
      if (i > 0) await sleep(CONFIG.solverDelayMs());
      const res = await client.generate<SolverAnswer>({
        system: SOLVER_SYSTEM,
        user,
        name: 'submit_answer',
        description: 'Submits the solution of the case.',
        schema: SOLVER_SCHEMA,
        maxTokens: CONFIG.solverMaxTokens(),
        temperature: 0.7,
      });
      runs.push(res.data);
    }
  } catch (e) {
    if (e instanceof QuotaExceededError) return quotaOutcome(e, client.model, d.case_date, d.difficulty, 'solver');
    const { data: outcome } = await db.rpc('admin_note_draft_failure', { p_id: d.id, p_error: String(e).slice(0, 500) });
    await log(d.case_date, false, 'solver_error', { id: d.id, difficulty: d.difficulty, error: String(e), outcome });
    return { status: 'solver_failed', date: d.case_date, difficulty: d.difficulty, detail: String(e) };
  }

  const summary = runs.map((r) => ({ culprit: r.culprit, motive: r.motive, evidence: r.evidence, confidence: r.confidence }));
  const verdict = evaluateSolverRuns(draft, runs);

  if (!verdict.ok) {
    const { error } = await db.rpc('admin_finalize_case', {
      p_id: d.id,
      p_status: CaseStatus.rejected,
      p_meta: { solver: summary, rejected_because: verdict.reasons },
    });
    if (error) throw new Error(`admin_finalize_case: ${error.message}`);
    await log(d.case_date, false, 'solver_rejected', { id: d.id, difficulty: d.difficulty, reasons: verdict.reasons, runs });
    return { status: CaseStatus.rejected, date: d.case_date, difficulty: d.difficulty, detail: verdict.reasons };
  }

  if (verdict.extraEvidence) draft.solution.evidence.push(verdict.extraEvidence);
  const { content, secret } = splitCase(draft);
  const { error } = await db.rpc('admin_finalize_case', {
    p_id: d.id,
    p_status: CaseStatus.verified,
    p_content: content,
    p_secret: { ...secret, draft },
    p_meta: { solver: summary, extra_evidence: verdict.extraEvidence ?? null, solver_model: client.model },
  });
  if (error) throw new Error(`admin_finalize_case: ${error.message}`);

  await log(d.case_date, true, 'verified', { id: d.id, difficulty: d.difficulty, title: draft.title });
  return {
    status: CaseStatus.verified,
    date: d.case_date,
    difficulty: d.difficulty,
    detail: { id: d.id, title: draft.title },
    draft: { ...d, status: CaseStatus.verified, case: draft },
  };
}

async function reviewDraft(d: Draft, recent: RecentCase[], missing: Target[]): Promise<Outcome> {
  const draft = d.case;
  const client = llm(CONFIG.editorModel(), CONFIG.editorThinking());
  const others = recent.filter((r) => r.id !== d.id);

  let review: EditorReview;
  let editorAttempts = 1;
  try {
    const res = await client.generate<EditorReview>({
      system: EDITOR_SYSTEM,
      user: buildEditorUser(draft, d.difficulty, others),
      name: 'submit_review',
      description: 'Submits the editorial review of the case.',
      schema: EDITOR_SCHEMA,
      maxTokens: CONFIG.editorMaxTokens(),
      temperature: 0.3,
    });
    review = res.data;
    editorAttempts = res.attempts ?? 1;
  } catch (e) {
    if (e instanceof QuotaExceededError) return quotaOutcome(e, client.model, d.case_date, d.difficulty, 'editor');
    const { data: outcome } = await db.rpc('admin_note_draft_failure', { p_id: d.id, p_error: String(e).slice(0, 500) });
    await log(d.case_date, false, 'editor_error', { id: d.id, difficulty: d.difficulty, error: String(e), outcome });
    return { status: 'editor_failed', date: d.case_date, difficulty: d.difficulty, detail: String(e) };
  }

  const thresholds = { min: CONFIG.editorMinScore(), reject: CONFIG.editorRejectScore() };
  const verdict = decideEditorial(review, thresholds);
  let status: CaseStatus = verdict.decision === EditorDecision.approve
    ? CaseStatus.approved
    : verdict.decision === EditorDecision.borderline
    ? BORDERLINE_STATUS[CONFIG.editorBorderline()] ?? CaseStatus.rejected
    : CaseStatus.rejected;

  let slot = { date: d.case_date, difficulty: d.difficulty };
  let downgradedFrom: typeof slot | null = null;
  const lower = status === CaseStatus.approved ? null : downgradeTarget(d.difficulty, review, thresholds);
  const free = lower ? missing.find((m) => m.difficulty === lower) : undefined;
  if (free) {
    const { error: moveError } = await db.rpc('admin_move_case', {
      p_id: d.id,
      p_case_date: free.date,
      p_difficulty: free.difficulty,
    });
    if (moveError) {
      await log(d.case_date, false, 'downgrade_failed', { id: d.id, difficulty: d.difficulty, error: moveError.message });
    } else {
      downgradedFrom = slot;
      slot = { date: free.date, difficulty: free.difficulty };
      status = CaseStatus.approved;
    }
  }
  if (status === CaseStatus.approved && CONFIG.requireReview()) status = CaseStatus.pending;

  const editor = {
    scores: review?.scores ?? null,
    issues: review?.issues ?? [],
    summary: review?.summary ?? null,
    decision: verdict.decision,
    reasons: verdict.reasons,
    model: client.model,
    attempts: editorAttempts,
    downgraded_from: downgradedFrom,
  };

  if (status === CaseStatus.rejected && (d.revisions ?? 0) < CONFIG.maxRevisions() && revisable(review, thresholds)) {
    const { error: requestError } = await db.rpc('admin_finalize_case', {
      p_id: d.id,
      p_status: CaseStatus.verified,
      p_meta: { revision_request: editor },
    });
    if (requestError) throw new Error(`admin_finalize_case: ${requestError.message}`);
    await log(d.case_date, true, 'revision_requested', { id: d.id, difficulty: d.difficulty, title: draft.title, editor });
    return { status: 'revision_requested', date: d.case_date, difficulty: d.difficulty, detail: { id: d.id, editor } };
  }

  const { content, secret } = splitCase(draft);
  const { error } = await db.rpc('admin_finalize_case', {
    p_id: d.id,
    p_status: status,
    p_content: content,
    p_secret: secret,
    p_meta: { editor },
  });
  if (error) throw new Error(`admin_finalize_case: ${error.message}`);

  const ok = status !== CaseStatus.rejected;
  await log(slot.date, ok, ok ? 'saved' : 'editor_rejected', {
    id: d.id,
    difficulty: slot.difficulty,
    title: draft.title,
    status,
    editor,
  });
  return { status, date: slot.date, difficulty: slot.difficulty, detail: { id: d.id, title: draft.title, editor } };
}

async function reviseDraft(d: Draft, editor: Record<string, unknown>, recent: RecentCase[]): Promise<Outcome> {
  const client = llm(CONFIG.model());
  const issues = (editor.issues as string[] | undefined) ?? [];
  const reject = async (reasons: string[]) => {
    await db.rpc('admin_finalize_case', {
      p_id: d.id,
      p_status: CaseStatus.rejected,
      p_meta: { editor, rejected_because: reasons },
    });
    await log(d.case_date, false, 'revision_failed', { id: d.id, difficulty: d.difficulty, reasons });
    return { status: CaseStatus.rejected, date: d.case_date, difficulty: d.difficulty, detail: reasons } as Outcome;
  };

  let revised: GeneratedCase;
  try {
    const res = await client.generate<GeneratedCase>({
      system: GENERATOR_SYSTEM,
      user: buildRevisionUser(d.case, d.difficulty, issues, recent.filter((r) => r.id !== d.id)),
      name: 'save_case',
      description: 'Saves the corrected crime case.',
      schema: CASE_SCHEMA,
      maxTokens: CONFIG.maxTokens(),
      temperature: 0.4,
    });
    revised = res.data;
  } catch (e) {
    if (e instanceof QuotaExceededError) return quotaOutcome(e, client.model, d.case_date, d.difficulty, 'revision');
    return reject([`revision call failed: ${String(e).slice(0, 300)}`]);
  }

  const problems = [...validateCase(revised, d.difficulty), ...structureChanges(d.case, revised)];
  if (problems.length) return reject(problems);

  const { content, secret } = splitCase(revised);
  const revisions = (d.revisions ?? 0) + 1;
  const { error } = await db.rpc('admin_revise_case', {
    p_id: d.id,
    p_title: revised.title,
    p_content: content,
    p_secret: { ...secret, draft: revised },
    p_meta: { revisions, [`editor_before_revision_${revisions}`]: editor },
  });
  if (error) throw new Error(`admin_revise_case: ${error.message}`);

  await log(d.case_date, true, 'revised', { id: d.id, difficulty: d.difficulty, title: revised.title, issues });
  return { status: 'revised', date: d.case_date, difficulty: d.difficulty, detail: { id: d.id, title: revised.title } };
}

async function rejectExpired(d: Draft): Promise<Outcome> {
  const reasons = ['case date passed before review finished'];
  const { error } = await db.rpc('admin_finalize_case', { p_id: d.id, p_status: CaseStatus.rejected, p_meta: { rejected_because: reasons } });
  if (error) throw new Error(`admin_finalize_case: ${error.message}`);
  await log(d.case_date, false, 'expired', { id: d.id, difficulty: d.difficulty });
  return { status: CaseStatus.rejected, date: d.case_date, difficulty: d.difficulty, detail: reasons };
}

async function advance(d: Draft, recent: RecentCase[], missing: Target[], full: boolean): Promise<Outcome> {
  if (d.status === CaseStatus.verified && d.revision_request) return reviseDraft(d, d.revision_request, recent);
  if (d.status === CaseStatus.verified) return reviewDraft(d, recent, missing);
  const verified = await verifyDraft(d);
  if (full && verified.draft) return reviewDraft(verified.draft, recent, missing);
  const { draft: _draft, ...outcome } = verified;
  return outcome;
}

async function tick(options: { target?: Target; full?: boolean }): Promise<Outcome> {
  const { data: plan, error } = await db.rpc('admin_generation_plan', { p_days_ahead: CONFIG.daysAhead() });
  if (error) throw new Error(`admin_generation_plan: ${error.message}`);

  const missing: Target[] = plan.missing ?? [];
  const recent: RecentCase[] = plan.recent ?? [];
  const pending = options.target ? undefined : (plan.draft as Draft | null) ?? undefined;

  if (pending && pending.case_date < plan.today) return rejectExpired(pending);

  const nextModel = !pending || pending.revision_request
    ? CONFIG.model()
    : pending.status === CaseStatus.verified
    ? CONFIG.editorModel()
    : CONFIG.solverModel();
  const { data: quotaUntil, error: quotaError } = await db.rpc('admin_quota_until', { p_model: nextModel });
  if (quotaError) throw new Error(`admin_quota_until: ${quotaError.message}`);
  if (quotaUntil && new Date(quotaUntil as string).getTime() > Date.now()) {
    return { status: 'quota_wait', detail: { model: nextModel, retry_at: quotaUntil } };
  }

  if (pending) return advance(pending, recent, missing, options.full === true);

  const target = options.target ?? missing.find((m) => (m.recent_failures ?? 0) < 3) ?? missing[0];
  if (!target) return { status: 'buffer_full' };
  if (options.target && !missing.some((m) => m.date === target.date && m.difficulty === target.difficulty)) {
    return { status: 'taken_or_outside_buffer', date: target.date, difficulty: target.difficulty };
  }

  const generated = await generateDraft({ date: target.date, difficulty: target.difficulty }, recent);
  if (options.full && generated.draft) return advance(generated.draft, recent, missing, true);
  const { draft: _draft, ...outcome } = generated;
  return outcome;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void } | undefined;

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  if (req.headers.get('x-cron-secret') !== Deno.env.get('CRON_SECRET')) {
    return json({ error: 'forbidden' }, 403);
  }

  const body = await req.json().catch(() => ({}));
  const date = typeof body?.date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(body.date) ? body.date : undefined;
  const difficulty = DIFFICULTIES.find((d) => d === body?.difficulty);
  const target = date ? { date, difficulty: difficulty ?? 'medium' } : undefined;

  const task = tick({ target, full: body?.full === true }).catch(async (e) => {
    console.error(e);
    await log(date ?? null, false, 'crash', { error: String(e) });
    return { status: 'error', detail: String(e) } as Outcome;
  });

  if (body?.wait === true || typeof EdgeRuntime === 'undefined') {
    return json(await task);
  }
  EdgeRuntime.waitUntil(task);
  return json({ status: 'accepted' }, 202);
});
