export interface ToolDef {
  name: string;
  description: string;
  input_schema: Record<string, unknown>;
}

export interface ToolCallResult<T> {
  input: T;
  usage: { input_tokens: number; output_tokens: number };
  stopReason: string;
}

export interface ToolCallOptions {
  apiKey: string;
  model: string;
  system: string;
  user: string;
  tool: ToolDef;
  maxTokens: number;
  temperature?: number;
}

const RETRYABLE = new Set([429, 500, 502, 503, 504, 529]);

export async function callTool<T>(o: ToolCallOptions): Promise<ToolCallResult<T>> {
  const body: Record<string, unknown> = {
    model: o.model,
    max_tokens: o.maxTokens,
    system: o.system,
    messages: [{ role: 'user', content: o.user }],
    tools: [o.tool],
    tool_choice: { type: 'tool', name: o.tool.name },
  };
  if (o.temperature !== undefined) body.temperature = o.temperature;

  let lastError = '';
  for (let attempt = 0; attempt < 3; attempt++) {
    if (attempt > 0) await new Promise((r) => setTimeout(r, 2000 * attempt));

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': o.apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      lastError = `Anthropic API ${res.status}: ${(await res.text()).slice(0, 500)}`;
      if (RETRYABLE.has(res.status)) continue;
      throw new Error(lastError);
    }

    const data = await res.json();
    const block = (data.content ?? []).find(
      (b: { type: string; name?: string }) => b.type === 'tool_use' && b.name === o.tool.name,
    );
    if (!block) {
      throw new Error(`Model did not call tool ${o.tool.name} (stop_reason: ${data.stop_reason}).`);
    }
    if (data.stop_reason === 'max_tokens') {
      throw new Error('Response truncated (max_tokens). Increase GEN_MAX_TOKENS.');
    }
    return { input: block.input as T, usage: data.usage, stopReason: data.stop_reason };
  }
  throw new Error(lastError || 'Anthropic API: unknown error.');
}
