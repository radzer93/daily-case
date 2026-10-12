import { type LlmClient, quotaError, RETRYABLE_STATUS, sleep, type StructuredRequest, type StructuredResponse } from './llm.ts';

const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/interactions';

interface InteractionStep {
  type?: string;
  content?: { type?: string; text?: string }[];
}

interface InteractionResponse {
  status?: string;
  steps?: InteractionStep[];
  usage?: Record<string, unknown>;
}

export function extractOutputText(data: InteractionResponse): string {
  return (data.steps ?? [])
    .filter((s) => s.type === 'model_output')
    .flatMap((s) => s.content ?? [])
    .filter((p) => p.type === 'text' && typeof p.text === 'string')
    .map((p) => p.text)
    .join('');
}

export function geminiClient(apiKey: string, model: string, thinkingLevel = 'high'): LlmClient {
  return {
    provider: 'gemini',
    model,
    async generate<T>(r: StructuredRequest): Promise<StructuredResponse<T>> {
      const body = {
        model,
        system_instruction: r.system,
        input: r.user,
        store: false,
        generation_config: {
          max_output_tokens: r.maxTokens,
          thinking_level: thinkingLevel,
        },
        response_format: {
          type: 'text',
          mime_type: 'application/json',
          schema: r.schema,
        },
      };

      let lastError = '';
      for (let attempt = 0; attempt < 4; attempt++) {
        if (attempt > 0) await sleep(5000 * attempt);

        const res = await fetch(ENDPOINT, {
          method: 'POST',
          headers: { 'x-goog-api-key': apiKey, 'content-type': 'application/json' },
          body: JSON.stringify(body),
        });

        if (!res.ok) {
          lastError = `Gemini API ${res.status}: ${(await res.text()).slice(0, 500)}`;
          const quota = quotaError(res.status, lastError);
          if (quota) throw quota;
          if (RETRYABLE_STATUS.has(res.status)) continue;
          throw new Error(lastError);
        }

        const data = (await res.json()) as InteractionResponse;
        if (data.status && data.status !== 'completed') {
          throw new Error(`Gemini interaction ended with status "${data.status}" (${r.name}).`);
        }
        const text = extractOutputText(data);
        if (!text) throw new Error(`Gemini returned no text output (${r.name}).`);
        try {
          return { data: JSON.parse(text) as T, usage: data.usage ?? {} };
        } catch {
          throw new Error(`Gemini output is not valid JSON (${r.name}): ${text.slice(0, 200)}`);
        }
      }
      throw new Error(lastError || 'Gemini API: unknown error.');
    },
  };
}
