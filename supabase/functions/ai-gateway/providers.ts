export type Kind = "text" | "vision";
export type Env = (name: string) => string | undefined;

const providers = {
  gemini: {
    url:
      "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
    secret: "GEMINI_API_KEY",
    tokenField: "max_tokens",
  },
  groq: {
    url: "https://api.groq.com/openai/v1/chat/completions",
    secret: "GROQ_API_KEY",
    tokenField: "max_completion_tokens",
  },
  openrouter: {
    url: "https://openrouter.ai/api/v1/chat/completions",
    secret: "OPENROUTER_API_KEY",
    tokenField: "max_tokens",
  },
  openai: {
    url: "https://api.openai.com/v1/chat/completions",
    secret: "OPENAI_API_KEY",
    tokenField: "max_completion_tokens",
  },
} as const;

type Provider = keyof typeof providers;

interface Model {
  provider: Provider;
  name: string;
  timeoutSeconds: number;
}

function model(provider: Provider, name: string, timeoutSeconds = 30): Model {
  return { provider, name, timeoutSeconds };
}

const openai = model("openai", "default", 60);
const geminiFlash = model("gemini", "gemini-flash-latest");
const geminiPro = model("gemini", "gemini-pro-latest", 60);
const geminiLite = model("gemini", "gemini-flash-lite-latest");
const openrouter = model("openrouter", "google/gemma-3-27b-it:free");

export const chains: Record<Kind, readonly Model[]> = {
  vision: [
    openai,
    geminiFlash,
    model("groq", "qwen/qwen3.8-27b"),
    geminiPro,
    geminiLite,
    openrouter,
  ],
  text: [
    openai,
    geminiPro,
    model("groq", "openai/gpt-oss-120b"),
    geminiFlash,
    model("groq", "llama-3.3-70b-versatile"),
    geminiLite,
    openrouter,
  ],
};

/** Optional built-in provider order, for example `openai,gemini,groq,openrouter`. */
export const providerOrderSecret = "AI_PROVIDER_ORDER";

/**
 * Known provider names from `AI_PROVIDER_ORDER`, in order: trimmed,
 * lowercased, duplicates and unknown names dropped. `ignored` lists the
 * dropped unknown names so a typo can be logged (names only, never keys).
 */
export function providerOrder(env: Env): {
  order: Provider[];
  ignored: string[];
} {
  const order: Provider[] = [];
  const ignored: string[] = [];
  for (const raw of (env(providerOrderSecret) ?? "").split(",")) {
    const name = raw.trim().toLowerCase();
    if (!name) continue;
    if (!Object.hasOwn(providers, name)) {
      ignored.push(name);
    } else if (!order.includes(name as Provider)) {
      order.push(name as Provider);
    }
  }
  return { order, ignored };
}

/**
 * The built-in chain for [kind] in the configured provider order. Without
 * `AI_PROVIDER_ORDER` (or with no known name in it) this is exactly
 * [chains]. Otherwise models are grouped by provider in the listed order,
 * keeping each provider's own model order; providers that are not listed
 * follow in their default order, so a short list never removes a model.
 * A provider without a key is still skipped later by [resolveModel].
 */
export function orderedChain(kind: Kind, env: Env): readonly Model[] {
  const { order } = providerOrder(env);
  const chain = chains[kind];
  if (order.length === 0) return chain;
  const rank = (model: Model) => {
    const index = order.indexOf(model.provider);
    return index === -1 ? order.length : index;
  };
  return chain
    .map((model, index) => ({ model, index }))
    .sort((a, b) => rank(a.model) - rank(b.model) || a.index - b.index)
    .map(({ model }) => model);
}

export function modelId(model: Model): string {
  return model.provider + "/" + model.name;
}

export function resolveModel(candidate: Model, env: Env) {
  const config = providers[candidate.provider];
  const key = env(config.secret)?.trim();
  if (!key) return null;
  let name = candidate.name;
  if (candidate.provider === "openai") {
    if (env("AI_OPENAI_ENABLED") !== "1") return null;
    name = env("OPENAI_MODEL")?.trim() ?? "";
    if (!name) return null;
  }
  return { ...config, key, model: { ...candidate, name } };
}
