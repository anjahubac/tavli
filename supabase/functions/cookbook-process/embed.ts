// Embedding tekstova preko Gemini API-ja sa serverskim ključem. Ključ ide u
// zaglavlje (ne u URL, da ne završi u logovima), a greške nose samo status:
// telo odgovora može da sadrži tekst knjige ili pitanja.

/** Dimenzija vektora u bazi (vector(768)); model dobija outputDimensionality. */
export const EMBEDDING_DIMENSIONS = 768;

export class EmbedError extends Error {
  constructor(public status: number | null, message: string) {
    super(message);
    this.name = "EmbedError";
  }
}

export class EmbedQuotaError extends Error {
  constructor(public retryAfterSeconds: number) {
    super("embedding quota exhausted");
    this.name = "EmbedQuotaError";
  }
}

export type EmbedKind = "document" | "query";

export interface EmbedderOptions {
  apiKey: string;
  model?: string;
  fetch?: typeof fetch;
  reserveBatch?: (userId?: string) => Promise<() => Promise<void>>;
}

export const DEFAULT_EMBEDDING_MODEL = "gemini-embedding-001";
const BATCH = 100;

export function createEmbedder(options: EmbedderOptions) {
  const model = options.model || DEFAULT_EMBEDDING_MODEL;
  const doFetch = options.fetch ?? fetch;
  return async (
    texts: string[],
    kind: EmbedKind,
    userId?: string,
  ): Promise<number[][]> => {
    if (!options.apiKey) throw new EmbedError(null, "embedding key missing");
    const out: number[][] = [];
    for (let i = 0; i < texts.length; i += BATCH) {
      const slice = texts.slice(i, i + BATCH);
      const release = await options.reserveBatch?.(userId);
      let res: Response;
      try {
        res = await doFetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:batchEmbedContents`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": options.apiKey,
            },
            body: JSON.stringify({
              requests: slice.map((text) => ({
                model: `models/${model}`,
                content: { parts: [{ text }] },
                taskType: kind === "query"
                  ? "RETRIEVAL_QUERY"
                  : "RETRIEVAL_DOCUMENT",
                outputDimensionality: EMBEDDING_DIMENSIONS,
              })),
            }),
            signal: AbortSignal.timeout(30_000),
          },
        );
      } catch {
        throw new EmbedError(null, "embedding request failed");
      } finally {
        if (release) await release().catch(() => {});
      }
      if (!res.ok) {
        throw new EmbedError(res.status, `embedding status ${res.status}`);
      }
      let data: { embeddings?: { values?: number[] }[] };
      try {
        data = await res.json();
      } catch {
        throw new EmbedError(res.status, "embedding response invalid");
      }
      const got = data.embeddings ?? [];
      if (
        got.length !== slice.length || got.some((e) => !Array.isArray(e.values))
      ) {
        throw new EmbedError(res.status, "embedding response shape");
      }
      for (const e of got) out.push(e.values as number[]);
    }
    return out;
  };
}
