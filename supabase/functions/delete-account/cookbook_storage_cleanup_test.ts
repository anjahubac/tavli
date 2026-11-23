import { assertEquals, assertRejects } from "jsr:@std/assert@0.224.0";
import {
  type CookbookStorageBucket,
  type CookbookStorageEntry,
  removeHouseholdCookbooks,
} from "./cookbook_storage_cleanup.ts";

const householdId = "a0000000-0000-4000-8000-000000000001";

Deno.test("briše fajlove kroz stare ugnježdene putanje i završava", async () => {
  const objects = new Set([
    `${householdId}/staro/podfolder/knjiga.pdf`,
    `${householdId}/novo.epub`,
  ]);
  const listed: string[] = [];
  const bucket: CookbookStorageBucket = {
    async list(path) {
      listed.push(path);
      const prefix = `${path}/`;
      const children = new Set<string>();
      for (const object of objects) {
        if (!object.startsWith(prefix)) continue;
        const rest = object.slice(prefix.length);
        children.add(rest.split("/")[0]);
      }
      return {
        data: [...children].map((name) => {
          const isFile = objects.has(`${path}/${name}`);
          return { name, id: isFile ? `id-${name}` : null };
        }),
        error: null,
      };
    },
    async remove(paths) {
      const removed = paths.filter((path) => objects.delete(path));
      return { data: removed, error: null };
    },
  };

  await removeHouseholdCookbooks(bucket, householdId);

  assertEquals(objects.size, 0);
  assertEquals(listed.slice(0, 5), [
    householdId,
    `${householdId}/staro`,
    `${householdId}/staro/podfolder`,
    `${householdId}/staro/podfolder`,
    `${householdId}/staro`,
  ]);
  assertEquals(listed.at(-1), householdId);
});

Deno.test("ne vrti se u petlji kad Storage ne obriše nijedan objekat", async () => {
  const bucket: CookbookStorageBucket = {
    async list() {
      return { data: [{ name: "knjiga.pdf", id: "file-id" }], error: null };
    },
    async remove() {
      return { data: [], error: null };
    },
  };

  await assertRejects(
    () => removeHouseholdCookbooks(bucket, householdId),
    Error,
    "cookbook_storage_cleanup_no_progress",
  );
});

Deno.test("odbacuje ime objekta sa separatorom putanje", async () => {
  const entry: CookbookStorageEntry = { name: "../outside.pdf", id: "bad" };
  const bucket: CookbookStorageBucket = {
    async list() {
      return { data: [entry], error: null };
    },
    async remove() {
      return { data: [], error: null };
    },
  };

  await assertRejects(
    () => removeHouseholdCookbooks(bucket, householdId),
    Error,
    "invalid_cookbook_object_name",
  );
});
