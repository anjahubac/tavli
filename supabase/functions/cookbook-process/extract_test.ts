// 026 / Task 2: izvlačenje teksta po stranici i chunking (čiste funkcije).
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { zipSync, strToU8 } from "npm:fflate@0.8.2";

import { chunkPage } from "./chunk.ts";
import {
  ExtractError,
  extractEpubPages,
  extractPdfPages,
  MAX_PAGES,
} from "./extract.ts";

// Najmanji PDF sa tekstom (Helvetica); `null` je stranica bez teksta (samo crtež).
function makePdf(pages: (string | null)[]): Uint8Array {
  const objs: string[] = [];
  const kids = pages.map((_, i) => `${4 + i * 2} 0 R`).join(" ");
  objs[1] = `<< /Type /Catalog /Pages 2 0 R >>`;
  objs[2] = `<< /Type /Pages /Kids [${kids}] /Count ${pages.length} >>`;
  objs[3] = `<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>`;
  pages.forEach((text, i) => {
    const page = 4 + i * 2, content = 5 + i * 2;
    objs[page] =
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents ${content} 0 R /Resources << /Font << /F1 3 0 R >> >> >>`;
    const stream = text === null
      ? "0 0 100 100 re f"
      : `BT /F1 12 Tf 50 700 Td (${text}) Tj ET`;
    objs[content] = `<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`;
  });
  let out = "%PDF-1.4\n";
  const offsets: number[] = [];
  for (let i = 1; i < objs.length; i++) {
    offsets[i] = out.length;
    out += `${i} 0 obj\n${objs[i]}\nendobj\n`;
  }
  const xref = out.length;
  out += `xref\n0 ${objs.length}\n0000000000 65535 f \n`;
  for (let i = 1; i < objs.length; i++) {
    out += `${String(offsets[i]).padStart(10, "0")} 00000 n \n`;
  }
  out += `trailer\n<< /Size ${objs.length} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
  return strToU8(out);
}

function makeEpub(chapters: string[]): Uint8Array {
  const manifest = chapters
    .map((_, i) =>
      `<item id="c${i}" href="text/ch${i}.xhtml" media-type="application/xhtml+xml"/>`
    ).join("");
  const spine = chapters.map((_, i) => `<itemref idref="c${i}"/>`).join("");
  const files: Record<string, Uint8Array> = {
    "mimetype": strToU8("application/epub+zip"),
    "META-INF/container.xml": strToU8(
      `<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>`,
    ),
    "OEBPS/content.opf": strToU8(
      `<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0"><manifest>${manifest}</manifest><spine>${spine}</spine></package>`,
    ),
  };
  chapters.forEach((html, i) => {
    files[`OEBPS/text/ch${i}.xhtml`] = strToU8(
      `<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><body>${html}</body></html>`,
    );
  });
  return zipSync(files);
}

Deno.test("chunkPage: prazan ili beo tekst ne daje chunk", () => {
  assertEquals(chunkPage(""), []);
  assertEquals(chunkPage("  \n\t  "), []);
});

Deno.test("chunkPage: kratak tekst je jedan chunk", () => {
  assertEquals(chunkPage("Sarma se kuva dugo."), ["Sarma se kuva dugo."]);
});

Deno.test("chunkPage: chunkovi ne prelaze granicu, ne seku reči i imaju preklapanje", () => {
  const sentences = Array.from(
    { length: 12 },
    (_, i) => `Rečenica broj ${i} o pasulju i kobasici u loncu.`,
  );
  const chunks = chunkPage(sentences.join(" "), { maxChars: 120, overlap: 30 });
  assert(chunks.length > 1);
  for (const c of chunks) assert(c.length <= 120, `predug chunk: ${c.length}`);
  // svaka rečenica se pojavljuje celovita u bar jednom chunku
  for (const s of sentences) assert(chunks.some((c) => c.includes(s)), s);
  // susedni chunkovi dele preklapanje
  for (let i = 1; i < chunks.length; i++) {
    const tail = chunks[i - 1].slice(-20).trim();
    assert(chunks[i].includes(tail.split(" ").slice(-2).join(" ")));
  }
});

Deno.test("chunkPage: jedna predugačka reč se seče na granici, ne gubi se", () => {
  const word = "x".repeat(300);
  const chunks = chunkPage(word, { maxChars: 100, overlap: 10 });
  assert(chunks.every((c) => c.length <= 100));
  assertEquals(chunks.join("").replaceAll("x", "").length, 0);
});

Deno.test("extractPdfPages: tekstualni PDF daje tekst po stranici", async () => {
  const pages = await extractPdfPages(makePdf(["Pasulj sa kobasicom", "Palacinke"]));
  assertEquals(pages.length, 2);
  assert(pages[0].includes("Pasulj sa kobasicom"));
  assert(pages[1].includes("Palacinke"));
});

Deno.test("extractPdfPages: skeniran PDF bez teksta je no_text", async () => {
  const err = await assertRejects(
    () => extractPdfPages(makePdf([null, null])),
    ExtractError,
  );
  assertEquals(err.code, "no_text");
});

Deno.test("extractPdfPages: stranica bez teksta u sredini ostaje prazna, ne pomera brojeve", async () => {
  const pages = await extractPdfPages(makePdf(["Prva", null, "Treca"]));
  assertEquals(pages.length, 3);
  assertEquals(pages[1].trim(), "");
  assert(pages[2].includes("Treca"));
});

Deno.test("extractPdfPages: oštećen fajl je corrupt, ne pada", async () => {
  const err = await assertRejects(
    () => extractPdfPages(strToU8("ovo nije pdf")),
    ExtractError,
  );
  assertEquals(err.code, "corrupt");
});

Deno.test("extractPdfPages: više od MAX_PAGES stranica je too_many_pages", async () => {
  const many = Array.from({ length: MAX_PAGES + 1 }, () => "x");
  const err = await assertRejects(
    () => extractPdfPages(makePdf(many)),
    ExtractError,
  );
  assertEquals(err.code, "too_many_pages");
});

Deno.test("extractEpubPages: poglavlja idu redom spine-a, oznake i skripte se skidaju", async () => {
  const pages = await extractEpubPages(
    makeEpub([
      "<h1>Supe</h1><p>Čorba od povrća.</p><script>alert(1)</script>",
      "<h1>Deserti</h1><p>Tufahije &amp; baklava.</p>",
    ]),
  );
  assertEquals(pages.length, 2);
  assert(pages[0].includes("Supe") && pages[0].includes("Čorba od povrća."));
  assert(!pages[0].includes("alert") && !pages[0].includes("<"));
  assert(pages[1].includes("Tufahije & baklava."));
});

Deno.test("extractEpubPages: dugo poglavlje se deli na više stranica", async () => {
  const long = "<p>" + "Reč ".repeat(2000) + "</p>";
  const pages = await extractEpubPages(makeEpub([long]));
  assert(pages.length > 1);
});

Deno.test("extractEpubPages: EPUB bez teksta je no_text, a loš zip je corrupt", async () => {
  const empty = await assertRejects(
    () => extractEpubPages(makeEpub(["<p>   </p>"])),
    ExtractError,
  );
  assertEquals(empty.code, "no_text");
  const bad = await assertRejects(
    () => extractEpubPages(strToU8("nije zip")),
    ExtractError,
  );
  assertEquals(bad.code, "corrupt");
});
