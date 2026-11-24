// Zadatak glasovnog nacrta (spec 027) je tekstualni: bez slike prolazi,
// sa slikom se odbija pre limita.
import { assertEquals } from "jsr:@std/assert@1";

import { parseCompletion } from "./input.ts";

const base = {
  task: "voice_draft_actions",
  model: "groq/openai/gpt-oss-120b",
  system: "Return JSON",
  prompt: 'Transcript: "Sarma za šest osoba."',
  temperature: 0.1,
};

Deno.test("voice_draft_actions is a text task", () => {
  assertEquals(parseCompletion(base)?.kind, "text");
});

Deno.test("voice_draft_actions rejects an image", () => {
  assertEquals(
    parseCompletion({ ...base, images: ["data:image/png;base64,AAAA"] }),
    undefined,
  );
});
