import type { Difficulty, Intensity } from './types.ts';

export interface DifficultyProfile {
  suspects: number;
  evidence: number;
  falseLeads: string;
  mechanism: string;
  hints: string;
}

export const PROFILES: Record<Difficulty, DifficultyProfile> = {
  easy: {
    suspects: 3,
    evidence: 6,
    falseLeads: 'at most one false lead',
    mechanism: 'one clear deduction mechanism; an attentive reader solves the case in a few minutes',
    hints: 'the two hints strongly confirm the solution',
  },
  medium: {
    suspects: 4,
    evidence: 6,
    falseLeads: 'one or two false leads',
    mechanism: 'one deduction mechanism hidden among ordinary-looking details',
    hints: 'the two hints confirm the solution',
  },
  hard: {
    suspects: 4,
    evidence: 7,
    falseLeads: 'two or three convincing false leads',
    mechanism: 'two deduction mechanisms that must be combined; neither of them alone identifies the culprit',
    hints: 'the two hints narrow the field but do not name the culprit',
  },
};

export const INTENSITY_RULES: Record<Intensity, string> = {
  standard:
    'Restrained tone: violence is stated factually, injuries are named without detail, the focus is on the puzzle.',
  dark:
    'Darker tone for a 16+ audience: the crime scene may be grim (blood, a described wound, fear, the culprit\'s cruelty), written soberly in the style of a police report. No gratuitous gore.',
};

export function publicEvidenceCount(d: Difficulty): number {
  return PROFILES[d].evidence - 2;
}
