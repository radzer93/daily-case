import { INTENSITY_RULES, PROFILES, publicEvidenceCount } from './difficulty.ts';
import { EXAMPLE_CASE } from './example_case.ts';
import { EDITOR_CRITERIA, type GeneratedCase, type RecentCase, type Seed } from './types.ts';

export const GENERATOR_SYSTEM = `You write crime puzzles for "Sprawa Dnia", a mobile game for players aged 16+.
Every day all players get the same case at each difficulty level. They read the case file, evidence and suspect statements, then name the culprit, the motive and the piece of evidence that proves it. They have three attempts.

LANGUAGE: every text field of the case (title, docket, place, date, brief, names, roles, statements, evidence, motives, explanation) is written in natural, idiomatic Polish. Ids are lowercase ASCII slugs.

WORLD: the case can take place anywhere on Earth and in any era given by the seed. Names, institutions, police ranks, money, technology and the docket reference fit that place and time (Japanese names in Japan, a Roman magistrate in ancient Rome). The text is still Polish.

FAIR PLAY RULES (most important; a case that breaks them is rejected):
1. The case is fictional. All people, companies and venues are invented. Do not use names of real people or details of real crimes. Real towns, regions and historical institutions are allowed.
2. Uniqueness. Exactly one suspect is the culprit. Every innocent suspect is excluded by a specific PUBLIC piece of evidence or statement (confirmed alibi, no access, no opportunity). List this in innocence_check.
3. Deduction. The culprit follows from public evidence (hint=false) through reasoning: a contradiction in a statement, knowledge they could not have, access, time and place, a technical trace. The player must connect at least two elements.
4. No giveaways. No confessions, no culprit's fingerprints on the weapon, no eyewitnesses to the act in public evidence.
5. Key evidence. solution.evidence lists 1–2 evidence ids that directly prove the culprit's guilt. At least one of them is public.
6. Motive. Exactly 4 motives. The true one follows from public material (at least indirectly) and hints may confirm it. The other 3 are plausible: they fit other suspects or the situation, but not the culprit.
7. Hints. Exactly 2 pieces of evidence have hint=true.
8. Every suspect has a motive or suspicious behaviour, so the choice is not obvious.
9. Consistency. Times, distances, dates and period details must agree. Check the timeline before answering.

CONTENT LIMITS (always, at every intensity):
- No sexual violence and no sexual content.
- No minors as victims, perpetrators or suspects; every person in the case is at least 18.
- No detailed torture.
- No usable instructions for weapons, poisons, explosives or committing crimes: a poison may be named, never how to make, obtain or dose it.
- No national, ethnic or religious stereotypes; the culprit is never defined by their origin.

FORMAT:
- Evidence ids: e1, e2, … in order. Exactly 2 have hint=true; the rest are public.
- title: 2–4 words, no colon.
- docket: a realistic case reference for the place and era.
- date: the date of the events written out in Polish (e.g. "14 marca 2025", "wiosna 1592 roku").
- brief: 2 paragraphs of 2–4 sentences. The report, the place, the victim or loss, the circumstances.
- statement: 2 paragraphs in the first person, spoken and natural. No admissions of guilt.
- evidence text: 1–3 factual sentences in the style of an official record, with concrete times and numbers.
- explain: 3 paragraphs: (1) how the public evidence points to the culprit, (2) what excludes the others, (3) the motive.

STYLE: plain, concise Polish with the feel of police files.`;

export function buildGeneratorUser(seed: Seed, recent: RecentCase[]): string {
  const p = PROFILES[seed.difficulty];
  const avoid = recent
    .slice(0, 30)
    .map((r) => `- ${r.title ?? '?'} (${r.place ?? '?'})`)
    .join('\n');
  const mechanisms = seed.secondMechanism
    ? `- Deduction mechanisms to COMBINE:\n  1. ${seed.mechanism}\n  2. ${seed.secondMechanism}`
    : `- Main deduction mechanism: ${seed.mechanism}`;

  return `Write a new case. Respond with JSON matching the schema.

SEED (adapt the setting to the place and era if needed):
- Place: ${seed.locale}
- Era: ${seed.era}. ${seed.eraHint}
- Setting: ${seed.setting}
- Type of case: ${seed.crime}
${mechanisms}

DIFFICULTY: ${seed.difficulty.toUpperCase()}
- Exactly ${p.suspects} suspects.
- Exactly ${p.evidence} pieces of evidence: ${publicEvidenceCount(seed.difficulty)} public and 2 hints.
- False leads: ${p.falseLeads}.
- Deduction: ${p.mechanism}.
- Hints: ${p.hints}.

INTENSITY: ${INTENSITY_RULES[seed.intensity]}

RECENT CASES (do not repeat titles, places or patterns):
${avoid || '- none'}

REFERENCE FOR FORMAT AND LOGIC (an easy case; do not copy the plot, names, place or mechanism):
${JSON.stringify(EXAMPLE_CASE)}

Before answering, check that:
- every innocent suspect is excluded by public evidence or a statement,
- the culprit and motive can be identified without hints,
- the timeline is consistent.`;
}

const str = (description: string) => ({ type: 'string', description });

export const CASE_SCHEMA = {
  type: 'object',
  required: ['title', 'docket', 'place', 'date', 'brief', 'suspects', 'evidence', 'motives', 'solution', 'innocence_check'],
  properties: {
    title: str('Title in Polish, 2–4 words'),
    docket: str('Case reference'),
    place: str('Town or place'),
    date: str('Date of events written out in Polish'),
    brief: { type: 'array', minItems: 2, maxItems: 2, items: { type: 'string' } },
    suspects: {
      type: 'array',
      minItems: 3,
      maxItems: 4,
      items: {
        type: 'object',
        required: ['id', 'name', 'age', 'role', 'statement'],
        properties: {
          id: str('lowercase ASCII slug'),
          name: str('First and last name'),
          age: { type: 'integer', minimum: 18, maximum: 95 },
          role: str('Who they are, in Polish'),
          statement: { type: 'array', minItems: 2, maxItems: 2, items: { type: 'string' } },
        },
      },
    },
    evidence: {
      type: 'array',
      minItems: 6,
      maxItems: 7,
      items: {
        type: 'object',
        required: ['id', 'title', 'text', 'hint'],
        properties: {
          id: str('e1, e2, …'),
          title: str('Short name of the evidence'),
          text: str('Evidence text'),
          hint: { type: 'boolean', description: 'true = hint evidence (exactly 2 items)' },
        },
      },
    },
    motives: {
      type: 'array',
      minItems: 4,
      maxItems: 4,
      items: {
        type: 'object',
        required: ['id', 'label'],
        properties: { id: str('lowercase ASCII slug'), label: str('Motive, 2–6 words') },
      },
    },
    solution: {
      type: 'object',
      required: ['culprit', 'motive', 'evidence', 'explain'],
      properties: {
        culprit: str('culprit id'),
        motive: str('id of the true motive'),
        evidence: { type: 'array', minItems: 1, maxItems: 2, items: { type: 'string' } },
        explain: { type: 'array', minItems: 3, maxItems: 3, items: { type: 'string' } },
      },
    },
    innocence_check: {
      type: 'array',
      description: 'For each innocent suspect: which public evidence ids or statements (suspect ids) exclude them.',
      items: {
        type: 'object',
        required: ['suspect_id', 'excluded_by', 'reason'],
        properties: {
          suspect_id: { type: 'string' },
          excluded_by: { type: 'array', minItems: 1, items: { type: 'string' } },
          reason: { type: 'string' },
        },
      },
    },
  },
};

export const SOLVER_SYSTEM = `You are a very strong player of detective games. You solve the case using only the material provided, without guessing. The material is in Polish.
Name the culprit, the motive and the piece of evidence that most strongly proves their guilt.
If the material lets you fairly argue for another culprit, add them to other_possible_culprits. If you have to guess, set confidence to "guess".`;

export function buildSolverUser(c: GeneratedCase): string {
  const open = c.evidence.filter((e) => !e.hint);
  const lines: string[] = [];
  lines.push(`CASE: ${c.title} (${c.place}, ${c.date})`, '', 'CASE FILE:', ...c.brief, '', 'EVIDENCE:');
  for (const e of open) lines.push(`[${e.id}] ${e.title}: ${e.text}`);
  lines.push('', 'STATEMENTS:');
  for (const s of c.suspects) {
    lines.push(`[${s.id}] ${s.name}, ${s.age}, ${s.role}:`, ...s.statement.map((p) => `"${p}"`), '');
  }
  lines.push('POSSIBLE MOTIVES:');
  for (const m of c.motives) lines.push(`[${m.id}] ${m.label}`);
  lines.push('', 'Respond with JSON matching the schema, using the ids in square brackets.');
  return lines.join('\n');
}

export const EDITOR_SYSTEM = `You are the senior editor of "Sprawa Dnia", a daily crime puzzle game for players aged 16+. Cases are written in Polish by an AI author and have already passed automated checks and blind solver runs. Nobody else reviews them before publication, so you are the last line of defence. Be strict: a mediocre case is better rejected than published.

Score each criterion from 1 (unacceptable) to 5 (excellent):
- logic: the timeline, distances, numbers and period details are consistent; nothing contradicts anything else; the explanation matches the evidence.
- fairness: the culprit, motive and key evidence follow from public evidence by deduction; every innocent suspect is excluded by public material; no giveaway, no guessing needed.
- difficulty_fit: the case matches the stated difficulty level (easy = one clear deduction step, medium = a few connected clues, hard = two combined mechanisms and real false leads).
- setting: names, institutions, ranks, money and technology fit the place and era; no anachronisms.
- language: natural, correct, idiomatic Polish; no calques, no English words, no awkward machine phrasing; statements sound spoken.
- content: respects the limits (no sexual content, nobody under 18, no detailed torture, no usable instructions for weapons, poisons or crimes, no stereotypes, no real people or real crimes). Score 1 if any limit is broken.
- originality: the plot and mechanism are not a cliché and differ from the recent cases.

List concrete issues (in English, each one sentence, quoting the problematic fragment if useful). Give a one-sentence summary.`;

export function buildEditorUser(c: GeneratedCase, difficulty: string, recent: RecentCase[]): string {
  const avoid = recent
    .slice(0, 20)
    .map((r) => `- ${r.title ?? '?'} (${r.place ?? '?'})`)
    .join('\n');
  return `DIFFICULTY: ${difficulty.toUpperCase()}

FULL CASE WITH SOLUTION (evidence with hint=true is hidden from players until unlocked):
${JSON.stringify(c)}

RECENT CASES:
${avoid || '- none'}

Respond with JSON matching the schema.`;
}

const score = (description: string) => ({ type: 'integer', minimum: 1, maximum: 5, description });

export const EDITOR_SCHEMA = {
  type: 'object',
  required: ['issues', 'scores', 'summary'],
  properties: {
    issues: { type: 'array', items: { type: 'string' }, description: 'Concrete problems found; empty if none' },
    scores: {
      type: 'object',
      required: [...EDITOR_CRITERIA],
      properties: Object.fromEntries(EDITOR_CRITERIA.map((k) => [k, score(k)])),
    },
    summary: str('One-sentence verdict'),
  },
};

export const SOLVER_SCHEMA = {
  type: 'object',
  required: ['reasoning', 'culprit', 'motive', 'evidence', 'other_possible_culprits', 'confidence'],
  properties: {
    reasoning: str('Reasoning, at most 5 sentences'),
    culprit: str('suspect id'),
    motive: str('motive id'),
    evidence: str('id of the evidence that most strongly proves guilt'),
    other_possible_culprits: {
      type: 'array',
      items: { type: 'string' },
      description: 'ids of other suspects who could also fairly be argued to be the culprit; empty if the solution is unique',
    },
    confidence: { type: 'string', enum: ['certain', 'likely', 'guess'] },
  },
};
