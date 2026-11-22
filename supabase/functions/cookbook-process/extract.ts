// Tekst po stranici iz tekstualnog PDF-a i EPUB-a. Skenirane knjige (bez
// teksta) nisu podržane: ExtractError("no_text"). Ne loguje sadržaj knjige.

import { unzipSync } from "npm:fflate@0.8.2";

export const MAX_PAGES = 500;
/** Najviše znakova jedne EPUB „stranice”: dugo poglavlje se deli na više. */
export const EPUB_PAGE_CHARS = 3000;

export type ExtractErrorCode = "no_text" | "corrupt" | "too_many_pages";

export class ExtractError extends Error {
  constructor(public code: ExtractErrorCode) {
    super(code);
    this.name = "ExtractError";
  }
}

function hasText(pages: string[]): boolean {
  return pages.some((p) => p.trim() !== "");
}

export async function extractPdfPages(bytes: Uint8Array): Promise<string[]> {
  const pdfjs = await import("npm:pdfjs-dist@4.10.38/legacy/build/pdf.mjs");
  let doc;
  try {
    // pdfjs preuzima bafer, pa mu se daje kopija.
    doc = await pdfjs.getDocument({
      data: bytes.slice(),
      isEvalSupported: false,
      useSystemFonts: false,
      disableFontFace: true,
      verbosity: 0,
    }).promise;
  } catch {
    throw new ExtractError("corrupt");
  }
  try {
    if (doc.numPages > MAX_PAGES) throw new ExtractError("too_many_pages");
    const pages: string[] = [];
    for (let i = 1; i <= doc.numPages; i++) {
      const page = await doc.getPage(i);
      const content = await page.getTextContent();
      let line = "";
      for (const item of content.items as { str?: string; hasEOL?: boolean }[]) {
        line += item.str ?? "";
        line += item.hasEOL ? "\n" : " ";
      }
      pages.push(line.replace(/[ \t]+/g, " ").trim());
      page.cleanup();
    }
    if (!hasText(pages)) throw new ExtractError("no_text");
    return pages;
  } catch (e) {
    if (e instanceof ExtractError) throw e;
    throw new ExtractError("corrupt");
  } finally {
    await doc.destroy();
  }
}

const ENTITIES: Record<string, string> = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
  nbsp: " ",
};

function htmlToText(html: string): string {
  return html
    .replace(/<(script|style)\b[\s\S]*?<\/\1>/gi, " ")
    .replace(/<\/(p|div|h[1-6]|li|br|tr)>|<br\s*\/?>/gi, "\n")
    .replace(/<[^>]*>/g, " ")
    .replace(/&(#x?[0-9a-f]+|[a-z]+);/gi, (m, e: string) => {
      if (e[0] === "#") {
        const n = e[1].toLowerCase() === "x"
          ? parseInt(e.slice(2), 16)
          : parseInt(e.slice(1), 10);
        return Number.isFinite(n) && n > 0 && n < 0x110000
          ? String.fromCodePoint(n)
          : " ";
      }
      return ENTITIES[e.toLowerCase()] ?? m;
    })
    .replace(/[ \t]+/g, " ")
    .replace(/\n\s*\n+/g, "\n")
    .trim();
}

function attr(tag: string, name: string): string | undefined {
  const m = new RegExp(`\\b${name}\\s*=\\s*("([^"]*)"|'([^']*)')`, "i").exec(tag);
  return m ? (m[2] ?? m[3]) : undefined;
}

function resolve(base: string, href: string): string {
  const dir = base.includes("/") ? base.slice(0, base.lastIndexOf("/") + 1) : "";
  const parts = (dir + decodeURIComponent(href.split("#")[0])).split("/");
  const out: string[] = [];
  for (const p of parts) {
    if (p === "..") out.pop();
    else if (p !== "." && p !== "") out.push(p);
  }
  return out.join("/");
}

function splitLong(text: string): string[] {
  if (text.length <= EPUB_PAGE_CHARS) return [text];
  const pieces: string[] = [];
  let rest = text;
  while (rest.length > EPUB_PAGE_CHARS) {
    let cut = rest.lastIndexOf(" ", EPUB_PAGE_CHARS);
    if (cut < EPUB_PAGE_CHARS / 2) cut = EPUB_PAGE_CHARS;
    pieces.push(rest.slice(0, cut).trim());
    rest = rest.slice(cut).trim();
  }
  if (rest !== "") pieces.push(rest);
  return pieces;
}

export function extractEpubPages(bytes: Uint8Array): Promise<string[]> {
  let files: Record<string, Uint8Array>;
  try {
    // Samo tekstualni delovi, svaki najviše 10 MB: slike i zip bombe se ne raspakuju.
    files = unzipSync(bytes, {
      filter: (f) =>
        f.originalSize <= 10_000_000 && /\.(xhtml|html|htm|opf|xml)$/i.test(f.name),
    });
  } catch {
    return Promise.reject(new ExtractError("corrupt"));
  }
  const text = (name: string) => {
    const f = files[name];
    return f ? new TextDecoder().decode(f) : undefined;
  };
  const container = text("META-INF/container.xml");
  const rootTag = container && /<rootfile\b[^>]*>/i.exec(container)?.[0];
  const opfPath = rootTag ? attr(rootTag, "full-path") : undefined;
  const opf = opfPath ? text(opfPath) : undefined;
  if (!opfPath || !opf) return Promise.reject(new ExtractError("corrupt"));

  const manifest = new Map<string, string>();
  for (const m of opf.matchAll(/<item\b[^>]*>/gi)) {
    const id = attr(m[0], "id"), href = attr(m[0], "href");
    if (id && href) manifest.set(id, href);
  }
  const pages: string[] = [];
  for (const m of opf.matchAll(/<itemref\b[^>]*>/gi)) {
    const href = manifest.get(attr(m[0], "idref") ?? "");
    const html = href ? text(resolve(opfPath, href)) : undefined;
    if (html === undefined) continue;
    const t = htmlToText(html);
    if (t !== "") pages.push(...splitLong(t));
    if (pages.length > MAX_PAGES) return Promise.reject(new ExtractError("too_many_pages"));
  }
  return hasText(pages)
    ? Promise.resolve(pages)
    : Promise.reject(new ExtractError("no_text"));
}
