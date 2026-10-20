import type { Difficulty, Intensity } from './types.ts';

export interface DifficultyProfile {
  suspects: number;
  evidence: number;
  falseLeads: string;
  mechanism: string;
  hints: string;
  rules: string[];
  minSteps: number;
  minCombinedSteps: number;
  minFalseLeads: number;
}

export const PROFILES: Record<Difficulty, DifficultyProfile> = {
  easy: {
    suspects: 3,
    evidence: 6,
    falseLeads: 'at most one false lead',
    mechanism: 'one clear deduction mechanism; an attentive reader solves the case in a few minutes',
    hints: 'the two hints strongly confirm the solution',
    rules: [],
    minSteps: 2,
    minCombinedSteps: 1,
    minFalseLeads: 0,
  },
  medium: {
    suspects: 4,
    evidence: 6,
    falseLeads: 'one or two false leads',
    mechanism: 'one deduction mechanism hidden among ordinary-looking details',
    hints: 'the two hints confirm the solution',
    rules: [
      'No public record places the culprit at the scene during the crime; their presence must be inferred.',
    ],
    minSteps: 2,
    minCombinedSteps: 1,
    minFalseLeads: 1,
  },
  hard: {
    suspects: 4,
    evidence: 7,
    falseLeads: 'two or three convincing false leads',
    mechanism: 'two deduction mechanisms that must be combined; neither of them alone identifies the culprit',
    hints: 'the two hints narrow the field but do not name the culprit',
    rules: [
      'No public record places the culprit at the scene during the crime, and no single item links them to it; only a combination of at least two items does.',
      'The culprit has an alibi or explanation that looks solid on first reading and collapses only when two separate items are combined.',
      'No innocent suspect is cleared by a single log entry; each is cleared by combining a statement with evidence or two pieces of evidence.',
      'At least two innocent suspects look more suspicious than the culprit on first reading (motive, lie about something unrelated, presence nearby).',
      'If a case could be solved by matching one timestamp or one log line, it is not hard: rework it.',
    ],
    minSteps: 3,
    minCombinedSteps: 2,
    minFalseLeads: 2,
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
