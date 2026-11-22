// Deli tekst jedne stranice na chunkove za embedding: nikad duže od maxChars,
// bez sečenja reči (osim reči duže od granice), sa preklapanjem da rečenica na
// granici ostane u oba chunka.

export interface ChunkOptions {
  maxChars: number;
  overlap: number;
}

const DEFAULTS: ChunkOptions = { maxChars: 900, overlap: 150 };

export function chunkPage(
  text: string,
  options: Partial<ChunkOptions> = {},
): string[] {
  const { maxChars, overlap } = { ...DEFAULTS, ...options };
  if (maxChars < 1 || overlap < 0 || overlap >= maxChars) {
    throw new RangeError("chunkPage: neispravne granice");
  }
  const t = text.replace(/\s+/g, " ").trim();
  if (t === "") return [];
  if (t.length <= maxChars) return [t];

  const chunks: string[] = [];
  let start = 0;
  while (start < t.length) {
    let end = Math.min(start + maxChars, t.length);
    if (end < t.length) {
      // Vrati se na poslednji razmak u drugoj polovini prozora; bez razmaka
      // (jedna dugačka reč) seče se na granici.
      const space = t.lastIndexOf(" ", end);
      if (space > start + maxChars / 2) end = space;
    }
    const piece = t.slice(start, end).trim();
    if (piece !== "") chunks.push(piece);
    if (end >= t.length) break;
    // Sledeći chunk počinje na početku reči unutar poslednjih `overlap` znakova.
    let next = Math.max(end - overlap, start + 1);
    if (next > start + 1 && t[next - 1] !== " ") {
      const sp = t.indexOf(" ", next);
      next = sp === -1 || sp >= end ? next : sp + 1;
    }
    start = next;
  }
  return chunks;
}
