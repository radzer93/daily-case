#!/usr/bin/env node

import { readFileSync } from 'node:fs';

const CASE_KIND = { fictional: 'fictional', inspired: 'inspired' };

const args = process.argv.slice(2);
const startDate = args[0];
const file = args.slice(1).find((a) => !a.startsWith('--')) ?? 'assets/cases.json';
const only = args.find((a) => a.startsWith('--only='))?.slice(7).split(',');
const difficulty = args.find((a) => a.startsWith('--difficulty='))?.slice(13) ?? 'easy';
const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!startDate || !/^\d{4}-\d{2}-\d{2}$/.test(startDate) || !url || !key || !['easy', 'medium', 'hard'].includes(difficulty)) {
  console.error('Usage: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node tools/import_cases.mjs YYYY-MM-DD [file] [--only=id1,id2] [--difficulty=easy|medium|hard]');
  process.exit(1);
}

const cases = JSON.parse(readFileSync(file, 'utf8')).filter((c) => !only || only.includes(c.id));

function addDays(iso, n) {
  const d = new Date(`${iso}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

for (const [i, c] of cases.entries()) {
  const caseDate = addDays(startDate, i);
  const content = {
    docket: c.docket,
    place: c.place,
    date: c.date,
    note: c.note ?? null,
    brief: c.brief,
    suspects: c.suspects,
    evidence: c.evidence.map((e) =>
      e.hint ? { id: e.id, title: e.title, hint: true } : { id: e.id, title: e.title, text: e.text, hint: false }
    ),
    motives: c.motives,
  };
  const secret = {
    solution: c.solution,
    hints: Object.fromEntries(c.evidence.filter((e) => e.hint).map((e) => [e.id, e.text])),
  };

  const res = await fetch(`${url}/rest/v1/rpc/admin_insert_case`, {
    method: 'POST',
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      p_case_date: caseDate,
      p_difficulty: difficulty,
      p_status: 'approved',
      p_kind: c.kind === CASE_KIND.inspired ? CASE_KIND.inspired : CASE_KIND.fictional,
      p_title: c.title,
      p_content: content,
      p_secret: secret,
      p_meta: { source: 'manual', asset_id: c.id },
      p_model: null,
    }),
  });

  if (res.ok) {
    console.log(`✔ ${caseDate}  ${difficulty}  ${c.title}`);
  } else {
    console.error(`✘ ${caseDate}  ${c.title}: ${res.status} ${await res.text()}`);
  }
}
