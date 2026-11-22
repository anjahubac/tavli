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
      // (jedna dugačka reč) seče se na granici. Pretraga je ograničena na
      // prozor, da jedan ogroman „red” bez razmaka ne daje kvadratno vreme.
      const lo = start + Math.floor(maxChars / 2);
      for (let i = end; i > lo; i--) {
        if (t.charCodeAt(i) === 32) {
          end = i;
          break;
        }
      }
    }
    const piece = t.slice(start, end).trim();
    if (piece !== "") chunks.push(piece);
    if (end >= t.length) break;
    // Sledeći chunk počinje na početku reči unutar poslednjih `overlap` znakova.
    let next = Math.max(end - overlap, start + 1);
    if (next > start + 1 && t[next - 1] !== " ") {
      for (let i = next; i < end; i++) {
        if (t.charCodeAt(i) === 32) {
          next = i + 1;
          break;
        }
      }
    }
    start = next;
  }
  return chunks;
}
