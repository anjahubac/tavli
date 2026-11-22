// Jedan poziv modela za odgovor nad odlomcima. Ključ ide u zaglavlje, a greške
// nose samo status: telo odgovora može da sadrži tekst knjige ili pitanja.

export class GenerateError extends Error {
  constructor(public status: number | null, message: string) {
    super(message);
    this.name = "GenerateError";
  }
}

export interface GeneratorOptions {
  apiKey: string;
  model?: string;
  fetch?: typeof fetch;
  timeoutMs?: number;
}

const DEFAULT_MODEL = "gemini-flash-lite-latest";

export function createGenerator(options: GeneratorOptions) {
  const model = options.model || DEFAULT_MODEL;
  const doFetch = options.fetch ?? fetch;
  return async (system: string, prompt: string): Promise<string> => {
    if (!options.apiKey) throw new GenerateError(null, "generation key missing");
    let res: Response;
    try {
      res = await doFetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json", "x-goog-api-key": options.apiKey },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: system }] },
            contents: [{ role: "user", parts: [{ text: prompt }] }],
            generationConfig: {
              temperature: 0.1,
              maxOutputTokens: 1024,
              responseMimeType: "application/json",
            },
          }),
          signal: AbortSignal.timeout(options.timeoutMs ?? 30_000),
        },
      );
    } catch {
      throw new GenerateError(null, "generation request failed");
    }
    if (!res.ok) throw new GenerateError(res.status, `generation status ${res.status}`);
    let data: { candidates?: { content?: { parts?: { text?: string }[] } }[] };
    try {
      data = await res.json();
    } catch {
      throw new GenerateError(res.status, "generation response invalid");
    }
    const text = data.candidates?.[0]?.content?.parts?.map((p) => p.text ?? "").join("") ?? "";
    if (text.trim() === "") throw new GenerateError(res.status, "generation response empty");
    return text;
  };
}
