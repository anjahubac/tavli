import { boundedJson, record } from "./input.ts";
import type { Env } from "./providers.ts";

export const recipeVectorModel = "@cf/baai/bge-m3";
const dimensions = 1024;

export function recipeVectorProvider(env: Env) {
  const account = env("AI_RECIPE_VECTOR_ACCOUNT")?.trim();
  const token = env("AI_RECIPE_VECTOR_TOKEN")?.trim();
  if (
    env("AI_RECIPE_VECTORS_ENABLED") !== "1" ||
    !account || !/^[a-f0-9]{32}$/i.test(account) || !token
  ) return;
  return {
    token,
    url:
      `https://api.cloudflare.com/client/v4/accounts/${account}/ai/v1/embeddings`,
  };
}

export function parseRecipeSearch(raw: unknown) {
  const body = record(raw);
  if (!body || Object.keys(body).length !== 3) return;
  const { query, recipeIds } = body;
  if (
    typeof query !== "string" || !query.trim() || query.length > 500 ||
    !Array.isArray(recipeIds) || recipeIds.length === 0 ||
    recipeIds.length > 2048 ||
    !recipeIds.every((id) =>
      typeof id === "string" && id.length > 0 && id.length <= 64
    )
  ) return;
  return { query: query.trim(), recipeIds: [...new Set<string>(recipeIds)] };
}

export class RecipeVectorProviderError extends Error {
  constructor(public status: number) {
    super("recipe_vector_provider_failed");
  }
}

export async function embedRecipeVectors(
  texts: string[],
  provider: NonNullable<ReturnType<typeof recipeVectorProvider>>,
  send: typeof fetch,
) {
  const reply = await send(provider.url, {
    method: "POST",
    redirect: "error",
    signal: AbortSignal.timeout(30_000),
    headers: {
      Authorization: "Bearer " + provider.token,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ model: recipeVectorModel, input: texts }),
  });
  if (!reply.ok) {
    await reply.body?.cancel().catch(() => {});
    throw new RecipeVectorProviderError(reply.status);
  }
  const result = record(await boundedJson(reply.body, 800_000));
  if (!Array.isArray(result?.data) || result.data.length !== texts.length) {
    throw new RecipeVectorProviderError(502);
  }
  const vectors = new Array<number[]>(texts.length);
  for (const entry of result.data) {
    const item = record(entry);
    const index = item?.index;
    const vector = item?.embedding;
    if (
      typeof index !== "number" || !Number.isInteger(index) ||
      index < 0 || index >= texts.length || vectors[index] !== undefined ||
      !Array.isArray(vector) || vector.length !== dimensions ||
      !vector.every((value) =>
        typeof value === "number" && Number.isFinite(value)
      ) ||
      !vector.some((value) => value !== 0)
    ) throw new RecipeVectorProviderError(502);
    vectors[index] = vector as number[];
  }
  return vectors;
}

export interface RankedRecipe {
  recipe_id: string;
  distance: number;
}
