import type { Difficulty, Intensity, RecentCase, Seed } from './types.ts';

export interface Locale {
  weight: number;
  era: string;
  locale: string;
  hint: string;
}

export const LOCALES: Locale[] = [
  { weight: 6, era: 'present day', locale: 'Poland', hint: 'Police, prosecutors, CCTV, phones, call records, card payments, GPS.' },
  { weight: 4, era: 'present day', locale: 'Scandinavia', hint: 'Small coastal towns, ferries, long winter nights, police districts, CCTV, phones.' },
  { weight: 4, era: 'present day', locale: 'Japan', hint: 'Prefectural police, konbini receipts, IC transit cards, station cameras.' },
  { weight: 4, era: 'present day', locale: 'United States', hint: 'County sheriff or city police, motels, highway toll records, phone location data.' },
  { weight: 3, era: 'present day', locale: 'Italy', hint: 'Carabinieri, family businesses, vineyards, small piazzas, ZTL traffic cameras.' },
  { weight: 3, era: 'present day', locale: 'Brazil', hint: 'Civil police, condominiums with doormen and access logs, motorbike couriers.' },
  { weight: 3, era: 'present day', locale: 'South Africa', hint: 'SAPS, gated estates with guard logs, game reserves, prepaid electricity meters.' },
  { weight: 3, era: 'present day', locale: 'Australia', hint: 'State police, outback roadhouses, fuel receipts, satellite phones.' },
  { weight: 3, era: 'present day', locale: 'Canada', hint: 'RCMP or city police, ski resorts, snowmobile trails, lift-pass scans.' },
  { weight: 3, era: 'present day', locale: 'India', hint: 'Local police station, joint families, railway reservations, UPI payments.' },
  { weight: 3, era: '1970s–1980s', locale: 'Polish People\'s Republic', hint: 'Citizens\' Militia (MO), landline phones, ration cards, no CCTV, factory and housing co-operatives.' },
  { weight: 3, era: '1920s–1930s', locale: 'interwar Poland', hint: 'State Police, telegraph, horse cabs and early cars, residence registers.' },
  { weight: 3, era: '1890s', locale: 'Victorian London', hint: 'Metropolitan Police, gas lamps, telegrams, railway timetables, pawnshop ledgers.' },
  { weight: 3, era: '1920s', locale: 'Chicago', hint: 'Prohibition, speakeasies, city police, telephone exchanges, newspaper reporters.' },
  { weight: 3, era: '1930s', locale: 'Paris', hint: 'Sûreté, cafés, cabarets, pneumatic post, concierges who see everything.' },
  { weight: 2, era: '1950s', locale: 'Los Angeles', hint: 'LAPD, film studios, motels, payphones, private investigators.' },
  { weight: 2, era: '1960s', locale: 'West Berlin', hint: 'West Berlin police, the Wall, border crossings with stamped papers, radio stations.' },
  { weight: 2, era: '1980s', locale: 'Tokyo', hint: 'Metropolitan Police, bubble economy, pagers, karaoke bars, company dormitories.' },
  { weight: 2, era: '1880s', locale: 'American Old West', hint: 'Town marshal, stagecoach schedules, telegraph office, saloon ledgers, mining claims.' },
  { weight: 2, era: '1600s', locale: 'Edo-period Japan', hint: 'Town magistrate (bugyō) and constables, merchant houses, night watchmen, sealed letters.' },
  { weight: 2, era: '1500s', locale: 'Renaissance Venice', hint: 'Council of Ten, gondoliers, glassmakers of Murano, masked carnival, guild records.' },
  { weight: 2, era: '1st century AD', locale: 'ancient Rome', hint: 'Vigiles and magistrates, insulae, public baths, wax tablets, slaves as witnesses.' },
  { weight: 2, era: '1300s', locale: 'medieval England', hint: 'Coroner and sheriff, monasteries, market fairs, manor court rolls, candle clocks.' },
  { weight: 2, era: '1920s', locale: 'Cairo', hint: 'Egyptian police with British officials, archaeological digs, hotels, telegrams.' },
  { weight: 2, era: '1930s', locale: 'Shanghai', hint: 'International Settlement police, trading houses, jazz clubs, river steamers.' },
  { weight: 2, era: '1940s', locale: 'Buenos Aires', hint: 'Federal police, tango halls, port warehouses, railway companies.' },
];

export const SETTINGS: string[] = [
  'a marina in the height of the sailing season',
  'a regatta',
  'a motorcycle rally',
  'a classic motorcycle restoration workshop',
  'a shooting range during a competition',
  'a club with a firearms collection',
  'a mountain hut cut off by a snowstorm',
  'a long-distance night train',
  'an antiquarian shop',
  'a theatre on opening night',
  'a vineyard during the harvest',
  'a newspaper office',
  'a university laboratory',
  'a seaside guesthouse off season',
  'a horse stud before an auction',
  'a violin maker\'s workshop',
  'a mine',
  'a wedding at a country estate',
  'a lighthouse',
  'a flea market',
  'an accounting office before an audit',
  'a family bakery',
  'a lakeside campsite',
  'a museum before an exhibition opening',
  'a mountain guesthouse',
  'a boatyard',
  'a small airfield',
  'a brewery',
  'a veterinary clinic',
  'a castle with an exhibition of historic weapons',
  'a tenement house with tenants in a rent dispute',
  'a sweet factory',
  'an astronomical observatory',
  'an orchard and fruit press',
  'a circus on tour',
  'a monastery',
  'a luxury hotel',
  'a fishing village',
  'a recording studio',
  'a perfume workshop',
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

export interface SeedOptions {
  difficulty: Difficulty;
  darkRatio?: number;
  rng?: Rng;
}

export function pickSeed(recent: RecentCase[], options: SeedOptions): Seed {
  const rng = options.rng ?? Math.random;
  const recentSeeds = recent.map((r) => r.seed ?? {});
  const usedSettings = new Set(recentSeeds.slice(0, 15).map((s) => s.setting).filter(Boolean));
  const usedLocales = new Set(recentSeeds.slice(0, 6).map((s) => s.locale).filter(Boolean));
  const usedMechanisms = new Set(recentSeeds.slice(0, 3).map((s) => s.mechanism).filter(Boolean));
  const usedCrimes = new Set(recentSeeds.slice(0, 2).map((s) => s.crime).filter(Boolean));

  const locales = LOCALES.filter((l) => !usedLocales.has(l.locale));
  const settings = SETTINGS.filter((s) => !usedSettings.has(s));
  const mechanisms = MECHANISMS.filter((m) => !usedMechanisms.has(m));
  const crimes = CRIMES.filter((c) => !usedCrimes.has(c));

  const locale = pickWeighted(locales.length ? locales : LOCALES, rng);
  const mechanismPool = mechanisms.length ? mechanisms : MECHANISMS;
  const mechanism = pick(mechanismPool, rng);
  const intensity: Intensity = rng() < (options.darkRatio ?? 0.25) ? 'dark' : 'standard';

  const seed: Seed = {
    difficulty: options.difficulty,
    intensity,
    era: locale.era,
    locale: locale.locale,
    eraHint: locale.hint,
    setting: pick(settings.length ? settings : SETTINGS, rng),
    crime: pick(crimes.length ? crimes : CRIMES, rng),
    mechanism,
  };

  if (options.difficulty === 'hard') {
    const others = MECHANISMS.filter((m) => m !== mechanism);
    seed.secondMechanism = pick(others, rng);
  }
  return seed;
}
