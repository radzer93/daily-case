import { createClient } from 'jsr:@supabase/supabase-js@2';
import { callTool } from './anthropic.ts';
import { buildGeneratorUser, buildSolverUser, CASE_TOOL, GENERATOR_SYSTEM, SOLVER_SYSTEM, SOLVER_TOOL } from './prompt.ts';
import { pickSeed } from './seeds.ts';
import { CaseKind, type GeneratedCase, type RecentCase, type SolverAnswer } from './types.ts';
import { evaluateSolverRuns, splitCase, validateCase } from './validate.ts';

const env = (name: string, fallback?: string): string => {
  const v = Deno.env.get(name) ?? fallback;
  if (v === undefined || v === '') throw new Error(`Missing environment variable ${name}.`);
  return v;
};

const CONFIG = {
  anthropicKey: () => env('ANTHROPIC_API_KEY'),
  model: () => env('GEN_MODEL', 'claude-sonnet-5-5'),
  solverModel: () => env('SOLVER_MODEL', env('GEN_MODEL', 'claude-sonnet-5-5')),
  maxTokens: () => Number(env('GEN_MAX_TOKENS', '8000')),
  solverRuns: () => Math.max(1, Number(env('SOLVER_RUNS', '3'))),
  daysAhead: () => Number(env('DAYS_AHEAD', '7')),
  requireReview: () => env('REQUIRE_REVIEW', 'false') === 'true',
};

const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), {
  auth: { persistSession: false },
});

async function log(caseDate: string | null, ok: boolean, stage: string, detail: Record<string, unknown>) {
  const { error } = await db.rpc('admin_log', { p_case_date: caseDate, p_ok: ok, p_stage: stage, p_detail: detail });
  if (error) console.error('admin_log', error.message);
}

type Outcome = { status: string; date?: string; detail?: unknown };

async function generateNext(forcedDate?: string): Promise<Outcome> {
  const { data: plan, error } = await db.rpc('admin_generation_plan', { p_days_ahead: CONFIG.daysAhead() });
  if (error) throw new Error(`admin_generation_plan: ${error.message}`);

  const missing: string[] = plan.missing ?? [];
  const date = forcedDate ?? missing[0];
  if (!date) return { status: 'buffer_full' };
  if (forcedDate && !missing.includes(forcedDate)) return { status: 'date_taken_or_outside_buffer', date };

  const recent: RecentCase[] = plan.recent ?? [];
  const seed = pickSeed(recent);

  let gen;
  try {
    gen = await callTool<GeneratedCase>({
      apiKey: CONFIG.anthropicKey(),
      model: CONFIG.model(),
      system: GENERATOR_SYSTEM,
      user: buildGeneratorUser(seed, recent),
      tool: CASE_TOOL,
      maxTokens: CONFIG.maxTokens(),
      temperature: 1,
    });
  } catch (e) {
    await log(date, false, 'generation', { seed, error: String(e) });
    return { status: 'generation_failed', date, detail: String(e) };
  }
  const draft = gen.input;

  const errors = validateCase(draft);
  if (errors.length) {
    await log(date, false, 'validation', { seed, errors, title: draft?.title });
    return { status: 'invalid', date, detail: errors };
  }

  const solverUser = buildSolverUser(draft);
  let runs: SolverAnswer[];
  try {
    const results = await Promise.all(
      Array.from({ length: CONFIG.solverRuns() }, () =>
        callTool<SolverAnswer>({
          apiKey: CONFIG.anthropicKey(),
          model: CONFIG.solverModel(),
          system: SOLVER_SYSTEM,
          user: solverUser,
          tool: SOLVER_TOOL,
          maxTokens: 1500,
          temperature: 0.7,
        })
      ),
    );
    runs = results.map((r) => r.input);
  } catch (e) {
    await log(date, false, 'solver_error', { seed, title: draft.title, error: String(e) });
    return { status: 'solver_failed', date, detail: String(e) };
  }

  const verdict = evaluateSolverRuns(draft, runs);
  if (!verdict.ok) {
    await log(date, false, 'solver_rejected', { seed, title: draft.title, reasons: verdict.reasons, runs });
    return { status: 'rejected', date, detail: verdict.reasons };
  }
  if (verdict.extraEvidence) draft.solution.evidence.push(verdict.extraEvidence);

  const { content, secret } = splitCase(draft);
  const status = CONFIG.requireReview() ? 'pending' : 'approved';
  const { data: id, error: insertError } = await db.rpc('admin_insert_case', {
    p_case_date: date,
    p_status: status,
    p_kind: CaseKind.fictional,
    p_title: draft.title,
    p_content: content,
    p_secret: secret,
    p_meta: {
      source: 'ai',
      seed,
      usage: gen.usage,
      solver: runs.map((r) => ({ culprit: r.culprit, motive: r.motive, evidence: r.evidence, confidence: r.confidence })),
      extra_evidence: verdict.extraEvidence ?? null,
    },
    p_model: CONFIG.model(),
  });
  if (insertError) {
    await log(date, false, 'insert', { title: draft.title, error: insertError.message });
    return { status: 'insert_failed', date, detail: insertError.message };
  }

  await log(date, true, 'saved', { id, title: draft.title, status, seed });
  return { status, date, detail: { id, title: draft.title } };
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
  const forcedDate = typeof body?.date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(body.date) ? body.date : undefined;

  const task = generateNext(forcedDate).catch(async (e) => {
    console.error(e);
    await log(forcedDate ?? null, false, 'crash', { error: String(e) });
    return { status: 'error', detail: String(e) } as Outcome;
  });

  if (body?.wait === true || typeof EdgeRuntime === 'undefined') {
    return json(await task);
  }
  EdgeRuntime.waitUntil(task);
  return json({ status: 'accepted' }, 202);
});
