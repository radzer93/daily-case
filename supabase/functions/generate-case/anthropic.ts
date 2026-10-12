import { type LlmClient, quotaError, RETRYABLE_STATUS, sleep, type StructuredRequest, type StructuredResponse } from './llm.ts';

export function anthropicClient(apiKey: string, model: string): LlmClient {
  return {
    provider: 'anthropic',
    model,
    async generate<T>(r: StructuredRequest): Promise<StructuredResponse<T>> {
      const body: Record<string, unknown> = {
        model,
        max_tokens: r.maxTokens,
        system: r.system,
        messages: [{ role: 'user', content: r.user }],
        tools: [{ name: r.name, description: r.description, input_schema: r.schema }],
        tool_choice: { type: 'tool', name: r.name },
      };
      if (r.temperature !== undefined) body.temperature = r.temperature;

      let lastError = '';
      for (let attempt = 0; attempt < 3; attempt++) {
        if (attempt > 0) await sleep(2000 * attempt);

        const res = await fetch('https://api.anthropic.com/v1/messages', {
          method: 'POST',
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: JSON.stringify(body),
        });

        if (!res.ok) {
          lastError = `Anthropic API ${res.status}: ${(await res.text()).slice(0, 500)}`;
          const quota = quotaError(res.status, lastError);
          if (quota) throw quota;
          if (RETRYABLE_STATUS.has(res.status)) continue;
          throw new Error(lastError);
        }

        const data = await res.json();
        const block = (data.content ?? []).find(
          (b: { type: string; name?: string }) => b.type === 'tool_use' && b.name === r.name,
        );
        if (!block) throw new Error(`Model did not call tool ${r.name} (stop_reason: ${data.stop_reason}).`);
        if (data.stop_reason === 'max_tokens') throw new Error('Response truncated (max_tokens). Increase GEN_MAX_TOKENS.');
        return { data: block.input as T, usage: data.usage ?? {} };
      }
      throw new Error(lastError || 'Anthropic API: unknown error.');
    },
  };
}
