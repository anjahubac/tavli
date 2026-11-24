// Supabase edge runtime (kompatibilan sa Deno 2.1) nema
// `Uint8Array.fromBase64`, a CI pokreće testove na novijem Deno-u. Ovi testovi
// uklanjaju tu metodu da bi proverili isti put koji radi na serveru.
import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { decodeBase64 } from "./base64.ts";
import { parseCompletion } from "./input.ts";

const png =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jAfQAAAAASUVORK5CYII=";

function withoutFromBase64(run: () => void) {
  const holder = Uint8Array as unknown as Record<string, unknown>;
  const original = holder.fromBase64;
  delete holder.fromBase64;
  try {
    run();
  } finally {
    if (original !== undefined) holder.fromBase64 = original;
  }
}

Deno.test("an image request parses on a runtime without fromBase64", () => {
  withoutFromBase64(() => {
    const input = parseCompletion({
      task: "recipe_from_image",
      model: "gemini/gemini-flash-latest",
      system: "Return JSON",
      prompt: "Read the recipe",
      images: ["data:image/png;base64," + png],
    });
    assertEquals(input?.kind, "vision");
  });
});

Deno.test("decodeBase64 decodes standard padded base64", () => {
  withoutFromBase64(() => {
    assertEquals(decodeBase64("AAECAw=="), new Uint8Array([0, 1, 2, 3]));
    assertEquals(decodeBase64("/+8="), new Uint8Array([255, 239]));
    assertEquals(decodeBase64(""), new Uint8Array());
  });
});

Deno.test("decodeBase64 rejects malformed input", () => {
  for (const bad of ["AAE", "AA=A", "AA*A", "AAAAA", "AAECAw==="]) {
    assertThrows(() => decodeBase64(bad), SyntaxError, undefined, bad);
  }
});
