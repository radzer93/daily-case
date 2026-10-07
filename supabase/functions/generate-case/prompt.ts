import { EXAMPLE_CASE } from './example_case.ts';
import type { GeneratedCase, RecentCase, Seed } from './types.ts';

export const GENERATOR_SYSTEM = `You write crime puzzles for "Sprawa Dnia", a Polish mobile game.
Every day all players get the same case. They read the case file, evidence and suspect statements, then name the culprit, the motive and the piece of evidence that proves it. They have three attempts.

LANGUAGE: every text field of the case (title, docket, place, date, brief, names, roles, statements, evidence, motives, explanation) must be written in natural, idiomatic Polish. Ids are lowercase ASCII slugs.

FAIR PLAY RULES (most important; a case that breaks them is rejected):
1. The case is fictional. All people, companies and venues are invented. Do not use names of real people or details of real crimes. Real Polish towns and regions are allowed.
2. Uniqueness. Exactly one suspect is the culprit. Every innocent suspect is excluded by a specific PUBLIC piece of evidence or statement (confirmed alibi, no access, no opportunity). List this in innocence_check.
3. Deduction. The culprit follows from public evidence (hint=false) through reasoning: a contradiction in a statement, knowledge they could not have, access, time and place, a technical trace. The player must connect at least two elements.
4. No giveaways. No confessions, no culprit's fingerprints on the weapon, no eyewitnesses to the act in public evidence.
5. Key evidence. solution.evidence lists 1–2 evidence ids that directly prove the culprit's guilt. At least one of them is public.
6. Motive. Exactly 4 motives. The true one follows from public material (at least indirectly) and hints may confirm it. The other 3 are plausible: they fit other suspects or the situation, but not the culprit.
7. Hints. Exactly 2 pieces of evidence have hint=true. They make the case easier and confirm the solution, but are not required.
8. Every suspect has a motive or suspicious behaviour, so the choice is not obvious.
9. Consistency. Times, distances, dates and period details must agree. Check the timeline before saving.

FORMAT:
- Exactly 6 pieces of evidence: 4 public (hint=false) and 2 hints (hint=true). Ids: e1–e6.
- 3 or 4 suspects. Ids: short lowercase ASCII slugs (e.g. "kinga", "pawel").
- title: 2–4 words, no colon.
- docket: a realistic Polish case reference for the era (e.g. "RSD 482/25" today, "Ds. 114/78" in the 1970s, "II K 1287/35" before the war, "Vr 214/03" under Austrian rule).
- date: the date of the events written out in Polish, e.g. "14 marca 2025".
- brief: 2 paragraphs of 2–4 sentences. The report, the place, the victim or loss, the circumstances.
- statement: 2 paragraphs in the first person, spoken and natural. No admissions of guilt.
- evidence text: 1–3 factual sentences in the style of a police record, with concrete times and numbers.
- explain: 3 paragraphs: (1) how the public evidence points to the culprit, (2) what excludes the others, (3) the motive.

STYLE: plain, concise Polish with the feel of police files. No graphic descriptions of injuries. Victims are never children.`;

export function buildGeneratorUser(seed: Seed, recent: RecentCase[]): string {
  const avoid = recent
    .slice(0, 25)
    .map((r) => `- ${r.title ?? '?'} (${r.place ?? '?'})`)
    .join('\n');

  return `Write a new case.

SEED (adapt the setting to the era if needed):
- Era: ${seed.era}. ${seed.eraHint}
- Setting: ${seed.setting}
- Type of case: ${seed.crime}
- Main deduction mechanism: ${seed.mechanism}

RECENT CASES (do not repeat titles, places or patterns):
${avoid || '- none'}

REFERENCE FOR FORMAT AND LOGIC (do not copy the plot, names or mechanism):
${JSON.stringify(EXAMPLE_CASE)}

Before calling the save_case tool, check that:
- every innocent suspect is excluded by public evidence or a statement,
- the culprit and motive can be identified without hints,
- the timeline is consistent.`;
}

const str = (description: string) => ({ type: 'string', description });

export const CASE_TOOL = {
  name: 'save_case',
  description: 'Saves a finished crime case.',
  input_schema: {
    type: 'object',
    required: ['title', 'docket', 'place', 'date', 'brief', 'suspects', 'evidence', 'motives', 'solution', 'innocence_check'],
    properties: {
      title: str('Title in Polish, 2–4 words'),
      docket: str('Case reference'),
      place: str('Town'),
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
            age: { type: 'integer' },
            role: str('Who they are, in Polish, e.g. "asystent w antykwariacie od sześciu lat"'),
            statement: { type: 'array', minItems: 2, maxItems: 2, items: { type: 'string' } },
          },
        },
      },
      evidence: {
        type: 'array',
        minItems: 6,
        maxItems: 6,
        items: {
          type: 'object',
          required: ['id', 'title', 'text', 'hint'],
          properties: {
            id: str('e1–e6'),
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
  },
} as const;

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
  lines.push('', 'Answer with the submit_answer tool, using the ids in square brackets.');
  return lines.join('\n');
}

export const SOLVER_TOOL = {
  name: 'submit_answer',
  description: 'Submits the solution of the case.',
  input_schema: {
    type: 'object',
    required: ['culprit', 'motive', 'evidence', 'other_possible_culprits', 'confidence', 'reasoning'],
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
  },
} as const;
