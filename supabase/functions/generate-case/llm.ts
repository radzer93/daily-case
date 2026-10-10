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
