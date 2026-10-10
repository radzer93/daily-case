import { createClient } from 'jsr:@supabase/supabase-js@2';
import { anthropicClient } from './anthropic.ts';
import { geminiClient } from './gemini.ts';
import { type LlmClient, sleep } from './llm.ts';
import { buildGeneratorUser, buildSolverUser, CASE_SCHEMA, GENERATOR_SYSTEM, SOLVER_SCHEMA, SOLVER_SYSTEM } from './prompt.ts';
import { pickSeed } from './seeds.ts';
import {
  CaseKind,
  DIFFICULTIES,
  type Difficulty,
  type GeneratedCase,
  type RecentCase,
  type Seed,
  type SolverAnswer,
} from './types.ts';
import { evaluateSolverRuns, splitCase, validateCase } from './validate.ts';

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
type Target = { date: string; difficulty: Difficulty; recent_failures?: number };
type Draft = { id: string; case_date: string; difficulty: Difficulty; case: GeneratedCase; seed: Seed };

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
    p_status: 'draft',
    p_kind: CaseKind.fictional,
    p_title: draft.title,
    p_content: content,
    p_secret: { ...secret, draft },
    p_meta: { source: 'ai', seed, provider: client.provider, usage: gen.usage },
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
    draft: { id: id as string, case_date: date, difficulty, case: draft, seed },
  };
}

async function verifyDraft(d: Draft): Promise<Outcome> {
  const draft = d.case;
  if (!draft || !Array.isArray(draft.evidence)) {
    await db.rpc('admin_finalize_case', { p_id: d.id, p_status: 'rejected', p_meta: { rejected_because: ['draft content missing'] } });
    await log(d.case_date, false, 'solver_rejected', { id: d.id, difficulty: d.difficulty, reasons: ['draft content missing'] });
    return { status: 'rejected', date: d.case_date, difficulty: d.difficulty, detail: 'draft content missing' };
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
    const { data: outcome } = await db.rpc('admin_note_draft_failure', { p_id: d.id, p_error: String(e).slice(0, 500) });
    await log(d.case_date, false, 'solver_error', { id: d.id, difficulty: d.difficulty, error: String(e), outcome });
    return { status: 'solver_failed', date: d.case_date, difficulty: d.difficulty, detail: String(e) };
  }

  const summary = runs.map((r) => ({ culprit: r.culprit, motive: r.motive, evidence: r.evidence, confidence: r.confidence }));
  const verdict = evaluateSolverRuns(draft, runs);

  if (!verdict.ok) {
    const { error } = await db.rpc('admin_finalize_case', {
      p_id: d.id,
      p_status: 'rejected',
      p_meta: { solver: summary, rejected_because: verdict.reasons },
    });
    if (error) throw new Error(`admin_finalize_case: ${error.message}`);
    await log(d.case_date, false, 'solver_rejected', { id: d.id, difficulty: d.difficulty, reasons: verdict.reasons, runs });
    return { status: 'rejected', date: d.case_date, difficulty: d.difficulty, detail: verdict.reasons };
  }

  if (verdict.extraEvidence) draft.solution.evidence.push(verdict.extraEvidence);
  const { content, secret } = splitCase(draft);
  const status = CONFIG.requireReview() ? 'pending' : 'approved';
  const { error } = await db.rpc('admin_finalize_case', {
    p_id: d.id,
    p_status: status,
    p_content: content,
    p_secret: secret,
    p_meta: { solver: summary, extra_evidence: verdict.extraEvidence ?? null, solver_model: client.model },
  });
  if (error) throw new Error(`admin_finalize_case: ${error.message}`);

  await log(d.case_date, true, 'saved', { id: d.id, difficulty: d.difficulty, title: draft.title, status });
  return { status, date: d.case_date, difficulty: d.difficulty, detail: { id: d.id, title: draft.title } };
}

async function tick(options: { target?: Target; full?: boolean }): Promise<Outcome> {
  const { data: plan, error } = await db.rpc('admin_generation_plan', { p_days_ahead: CONFIG.daysAhead() });
  if (error) throw new Error(`admin_generation_plan: ${error.message}`);

  if (!options.target && plan.draft) return verifyDraft(plan.draft as Draft);

  const missing: Target[] = plan.missing ?? [];
  const recent: RecentCase[] = plan.recent ?? [];
  const target = options.target ?? missing.find((m) => (m.recent_failures ?? 0) < 3) ?? missing[0];
  if (!target) return { status: 'buffer_full' };
  if (options.target && !missing.some((m) => m.date === target.date && m.difficulty === target.difficulty)) {
    return { status: 'taken_or_outside_buffer', date: target.date, difficulty: target.difficulty };
  }

  const generated = await generateDraft({ date: target.date, difficulty: target.difficulty }, recent);
  if (options.full && generated.draft) return verifyDraft(generated.draft);
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
