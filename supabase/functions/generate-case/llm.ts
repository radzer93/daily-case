export interface StructuredRequest {
  system: string;
  user: string;
  name: string;
  description: string;
  schema: Record<string, unknown>;
  maxTokens: number;
  temperature?: number;
}

export interface StructuredResponse<T> {
  data: T;
  usage: Record<string, unknown>;
}

export interface LlmClient {
  readonly provider: string;
  readonly model: string;
  generate<T>(request: StructuredRequest): Promise<StructuredResponse<T>>;
}

export const RETRYABLE_STATUS = new Set([429, 500, 502, 503, 504, 529]);

export const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export const LONG_QUOTA_MS = 10 * 60 * 1000;
const DEFAULT_QUOTA_WAIT_MS = 60 * 60 * 1000;
export const MAX_QUOTA_WAIT_MS = 3 * 60 * 60 * 1000;

export class QuotaExceededError extends Error {
  readonly retryAt: Date;

  constructor(message: string, retryAt: Date) {
    super(message);
    this.retryAt = retryAt;
    this.name = 'QuotaExceededError';
  }
}

export function parseRetryDelayMs(text: string): number | null {
  const human = /retry in\s+(?:(\d+)h)?\s*(?:(\d+)m)?\s*(?:([\d.]+)s)?/i.exec(text);
  if (human && (human[1] || human[2] || human[3])) {
    return ((Number(human[1] ?? 0) * 60 + Number(human[2] ?? 0)) * 60 + Number(human[3] ?? 0)) * 1000;
  }
  const field = /"retryDelay"\s*:\s*"([\d.]+)s"/.exec(text);
  return field ? Number(field[1]) * 1000 : null;
}

export function quotaError(status: number, text: string, now = new Date()): QuotaExceededError | null {
  if (status !== 429) return null;
  const delay = parseRetryDelayMs(text);
  const quota = /per day|daily|exceeded (?:a|your) quota|quota exceeded/i.test(text);
  if (!quota && (delay === null || delay < LONG_QUOTA_MS)) return null;
  const wait = Math.min(delay ?? DEFAULT_QUOTA_WAIT_MS, MAX_QUOTA_WAIT_MS);
  return new QuotaExceededError(text.slice(0, 300), new Date(now.getTime() + wait));
}
