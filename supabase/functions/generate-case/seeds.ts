import type { RecentCase, Seed } from './types.ts';

const ERAS: { weight: number; era: string; hint: string }[] = [
  {
    weight: 60,
    era: 'present day',
    hint: 'Years 2015–2026. Police and prosecutors, CCTV, mobile phones, call records, card payments, GPS.',
  },
  {
    weight: 14,
    era: 'Polish People\'s Republic',
    hint: 'Years 1965–1985. Citizens\' Militia (MO), landline phones, ration cards, no CCTV.',
  },
  {
    weight: 16,
    era: 'interwar Poland',
    hint: 'Years 1924–1938. State Police, telegraph, horse cabs and early cars, residence registers.',
  },
  {
    weight: 10,
    era: 'turn of the 20th century',
    hint: 'Years 1890–1912, partitioned Poland. Investigating judges, pharmacies with poison registers, railways, telegraph.',
  },
];

export const SETTINGS: string[] = [
  'a marina in the Masurian lakes at the height of the season',
  'a regatta on a reservoir',
  'a motorcycle rally in the mountains',
  'a classic motorcycle restoration workshop',
  'a sport shooting range during a competition',
  'a shooting club with a firearms collection',
  'a mountain hut cut off by a snowstorm',
  'a long-distance night train',
  'an antiquarian shop in an old town',
  'a theatre on opening night',
  'a vineyard during the grape harvest',
  'a local newspaper office',
  'a university laboratory',
  'a seaside guesthouse off season',
  'a horse stud before an auction',
  'a violin maker\'s workshop',
  'a salt mine with a tourist route',
  'a manor house during a wedding',
  'a lighthouse',
  'a flea market',
  'an accounting office before a tax audit',
  'a family bakery',
  'a lakeside campsite',
  'a regional museum before an exhibition opening',
  'a guesthouse in the Tatra mountains',
  'a yacht shipyard',
  'a flying club with a grass airstrip',
  'a craft brewery',
  'a veterinary clinic',
  'a castle with an exhibition of historic weapons',
  'a tenement house with tenants in a rent dispute',
  'a sweet factory',
  'an astronomical observatory',
  'an orchard and fruit processing plant',
];

export const CRIMES: string[] = [
  'murder',
  'poisoning',
  'theft of a valuable object',
  'sabotage',
  'fraud and forgery',
  'arson',
  'disappearance ending with a body being found',
];

export const MECHANISMS: string[] = [
  'Access: the scene could only be entered with a key, code or card that the culprit had.',
  'False alibi: a document (ticket, receipt, register, call record, logbook entry) contradicts the culprit\'s statement.',
  'Guilty knowledge: the statement mentions a detail the investigators never disclosed.',
  'Physical contradiction: the statement does not match the weather, light, distance or timetable.',
  'Time and place record: a log (camera, meter, clock, journal, GPS) places the culprit where they claim they were not.',
  'Tool or substance: the culprit obtained it, as shown by a register or receipt, and denies it.',
  'Time window: only the culprit could have been alone at the scene during the critical minutes.',
  'Lie about a skill: the culprit claims not to know how to do something, and the evidence shows they do.',
];

type Rng = () => number;

function pick<T>(items: T[], rng: Rng): T {
  return items[Math.floor(rng() * items.length) % items.length];
}

function pickWeighted<T extends { weight: number }>(items: T[], rng: Rng): T {
  const total = items.reduce((s, i) => s + i.weight, 0);
  let r = rng() * total;
  for (const item of items) {
    r -= item.weight;
    if (r < 0) return item;
  }
  return items[items.length - 1];
}

export function pickSeed(recent: RecentCase[], rng: Rng = Math.random): Seed {
  const recentSeeds = recent.map((r) => r.seed ?? {});
  const usedSettings = new Set(recentSeeds.slice(0, 10).map((s) => s.setting).filter(Boolean));
  const usedMechanisms = new Set(recentSeeds.slice(0, 2).map((s) => s.mechanism).filter(Boolean));
  const usedCrimes = new Set(recentSeeds.slice(0, 1).map((s) => s.crime).filter(Boolean));

  const settings = SETTINGS.filter((s) => !usedSettings.has(s));
  const mechanisms = MECHANISMS.filter((m) => !usedMechanisms.has(m));
  const crimes = CRIMES.filter((c) => !usedCrimes.has(c));

  const era = pickWeighted(ERAS, rng);
  return {
    era: era.era,
    eraHint: era.hint,
    setting: pick(settings.length ? settings : SETTINGS, rng),
    crime: pick(crimes.length ? crimes : CRIMES, rng),
    mechanism: pick(mechanisms.length ? mechanisms : MECHANISMS, rng),
  };
}
