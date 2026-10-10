export const CaseKind = {
  fictional: 'fictional',
  inspired: 'inspired',
} as const;
export type CaseKind = (typeof CaseKind)[keyof typeof CaseKind];

export const DIFFICULTIES = ['easy', 'medium', 'hard'] as const;
export type Difficulty = (typeof DIFFICULTIES)[number];

export type Intensity = 'standard' | 'dark';

export interface GenSuspect {
  id: string;
  name: string;
  age: number;
  role: string;
  statement: string[];
}

export interface GenEvidence {
  id: string;
  title: string;
  text: string;
  hint: boolean;
}

export interface GenMotive {
  id: string;
  label: string;
}

export interface GenSolution {
  culprit: string;
  motive: string;
  evidence: string[];
  explain: string[];
}

export interface InnocenceCheck {
  suspect_id: string;
  excluded_by: string[];
  reason: string;
}

export interface GeneratedCase {
  title: string;
  docket: string;
  place: string;
  date: string;
  brief: string[];
  suspects: GenSuspect[];
  evidence: GenEvidence[];
  motives: GenMotive[];
  solution: GenSolution;
  innocence_check: InnocenceCheck[];
}

export type Confidence = 'certain' | 'likely' | 'guess';

export interface SolverAnswer {
  culprit: string;
  motive: string;
  evidence: string;
  other_possible_culprits: string[];
  confidence: Confidence;
  reasoning: string;
}

export const EDITOR_CRITERIA = [
  'logic',
  'fairness',
  'difficulty_fit',
  'setting',
  'language',
  'content',
  'originality',
] as const;
export type EditorCriterion = (typeof EDITOR_CRITERIA)[number];
export type EditorScores = Record<EditorCriterion, number>;

export interface EditorReview {
  scores: EditorScores;
  issues: string[];
  summary: string;
}

export const EditorDecision = {
  approve: 'approve',
  reject: 'reject',
  borderline: 'borderline',
} as const;
export type EditorDecision = (typeof EditorDecision)[keyof typeof EditorDecision];

export const CaseStatus = {
  draft: 'draft',
  verified: 'verified',
  pending: 'pending',
  approved: 'approved',
  rejected: 'rejected',
} as const;
export type CaseStatus = (typeof CaseStatus)[keyof typeof CaseStatus];

export interface Seed {
  difficulty: Difficulty;
  intensity: Intensity;
  era: string;
  locale: string;
  eraHint: string;
  setting: string;
  crime: string;
  mechanism: string;
  secondMechanism?: string;
}

export interface RecentCase {
  id?: string;
  title?: string;
  place?: string;
  seed?: Partial<Seed> | null;
}
