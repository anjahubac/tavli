import {
  chains,
  type Env,
  modelId,
  orderedChain,
  providerOrder,
  resolveModel,
} from "./providers.ts";

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      "Actual: " + JSON.stringify(actual) + "; expected: " +
        JSON.stringify(expected),
    );
  }
}

const envOf = (values: Record<string, string>): Env => (name) => values[name];
const ids = (kind: "text" | "vision", env: Env) =>
  orderedChain(kind, env).map(modelId);
const prod = "openai,gemini,groq,openrouter";

Deno.test("without AI_PROVIDER_ORDER the chains keep the current order", () => {
  for (const kind of ["text", "vision"] as const) {
    equal(ids(kind, envOf({})), chains[kind].map(modelId));
    equal(
      ids(kind, envOf({ AI_PROVIDER_ORDER: " , " })),
      chains[kind].map(modelId),
    );
  }
});

Deno.test("the prod order groups models by provider in the given order", () => {
  const env = envOf({ AI_PROVIDER_ORDER: prod });
  equal(ids("text", env), [
    "openai/default",
    "gemini/gemini-pro-latest",
    "gemini/gemini-flash-latest",
    "gemini/gemini-flash-lite-latest",
    "groq/openai/gpt-oss-120b",
    "groq/llama-3.3-70b-versatile",
    "openrouter/google/gemma-3-27b-it:free",
  ]);
  equal(ids("vision", env), [
    "openai/default",
    "gemini/gemini-flash-latest",
    "gemini/gemini-pro-latest",
    "gemini/gemini-flash-lite-latest",
    "groq/qwen/qwen3.8-27b",
    "openrouter/google/gemma-3-27b-it:free",
  ]);
});

Deno.test("spaces, case, duplicates and unknown names are handled safely", () => {
  const messy = envOf({
    AI_PROVIDER_ORDER:
      " OpenAI , gemini,open ai,GEMINI,, groq ,mistral,openrouter",
  });
  equal(providerOrder(messy), {
    order: ["openai", "gemini", "groq", "openrouter"],
    ignored: ["open ai", "mistral"],
  });
  equal(ids("text", messy), ids("text", envOf({ AI_PROVIDER_ORDER: prod })));

  // Only unknown names: same as unset, nothing is lost.
  const typo = envOf({ AI_PROVIDER_ORDER: "open-ai,gemni" });
  equal(ids("text", typo), chains.text.map(modelId));
  equal(providerOrder(typo).ignored, ["open-ai", "gemni"]);
});

Deno.test("providers missing from a short list follow in their default order", () => {
  const env = envOf({ AI_PROVIDER_ORDER: "groq" });
  equal(ids("text", env), [
    "groq/openai/gpt-oss-120b",
    "groq/llama-3.3-70b-versatile",
    "openai/default",
    "gemini/gemini-pro-latest",
    "gemini/gemini-flash-latest",
    "gemini/gemini-flash-lite-latest",
    "openrouter/google/gemma-3-27b-it:free",
  ]);
  for (const kind of ["text", "vision"] as const) {
    equal(ids(kind, env).length, chains[kind].length);
  }
});

Deno.test("a provider without its key is skipped and the next one is first", () => {
  const env = envOf({
    AI_PROVIDER_ORDER: prod,
    GEMINI_API_KEY: "fake-gemini",
    GROQ_API_KEY: "fake-groq",
  });
  const usable = orderedChain("text", env).filter((m) => resolveModel(m, env))
    .map(modelId);
  equal(usable[0], "gemini/gemini-pro-latest");
  equal(usable.includes("openai/default"), false);
  equal(usable.some((id) => id.startsWith("openrouter/")), false);
});
