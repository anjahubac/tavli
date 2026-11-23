// Odgovor ide kroz isti tekstualni lanac kao AI gateway. Ključevi su samo u
// zaglavljima; poruke i odgovori se ne loguju jer mogu sadržati tekst knjige.

import { chains, type Env, resolveModel } from "../ai-gateway/providers.ts";

export class GenerateError extends Error {
  constructor(public status: number | null, message: string) {
    super(message);
    this.name = "GenerateError";
  }
}

export interface GeneratorOptions {
  env: Env;
  fetch?: typeof fetch;
  maxTokens?: number;
}

export function createGenerator(options: GeneratorOptions) {
  const doFetch = options.fetch ?? fetch;
  return async (system: string, prompt: string): Promise<string> => {
    let lastStatus: number | null = null;
    for (const candidate of chains.text) {
      const selected = resolveModel(candidate, options.env);
      if (!selected) continue;
      let res: Response;
      try {
        res = await doFetch(selected.url, {
          method: "POST",
          redirect: "error",
          headers: {
            Authorization: `Bearer ${selected.key}`,
            "Content-Type": "application/json",
            ...(selected.model.provider === "openrouter"
              ? { "X-Title": "Tavli" }
              : {}),
          },
          body: JSON.stringify({
            model: selected.model.name,
            [selected.tokenField]: options.maxTokens ?? 1024,
            response_format: { type: "json_object" },
            messages: [
              { role: "system", content: system },
              { role: "user", content: prompt },
            ],
          }),
          signal: AbortSignal.timeout(selected.model.timeoutSeconds * 1000),
        });
      } catch {
        continue;
      }
      if (!res.ok) {
        lastStatus = res.status;
        await res.body?.cancel().catch(() => {});
        continue;
      }
      try {
        const data = await res.json() as {
          choices?: { message?: { content?: unknown } }[];
        };
        const content = data.choices?.[0]?.message?.content;
        if (typeof content === "string" && content.trim()) return content;
      } catch {
        // Try the next configured provider without exposing response bodies.
      }
    }
    throw new GenerateError(lastStatus, "generation providers exhausted");
  };
}
