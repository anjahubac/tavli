import { cleanHouseholdPhotos, type CleanupBatch } from "./worker.ts";

const home = "00000000-0000-4000-8000-000000000001";
const claim = "00000000-0000-4000-8000-000000000002";
const retired = `${home}/old.jpg`;
const staged = `${home}/joinphoto-${"a".repeat(64)}.jpg`;

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

Deno.test("a failed Storage deletion retries independently of the join request", async () => {
  const calls: unknown[] = [];
  const batch: CleanupBatch = {
    claim_id: claim,
    staged_paths: [staged],
    retired_id: home,
    retired_paths: [retired],
  };
  let failRetired = true;
  const backend = {
    claim: () => Promise.resolve(batch),
    remove(paths: string[]) {
      calls.push(paths);
      if (failRetired && paths[0] === retired) {
        return Promise.reject(new Error("storage_unavailable"));
      }
      return Promise.resolve();
    },
    complete(stagedClaim: string | null, retiredId: string | null) {
      calls.push([stagedClaim, retiredId]);
      return Promise.resolve();
    },
  };

  const first = await Promise.allSettled([cleanHouseholdPhotos(backend)]);
  equal(first[0].status, "rejected");
  equal(calls, [[staged], [retired], [claim, null]]);

  calls.length = 0;
  batch.staged_paths = [];
  failRetired = false;
  await cleanHouseholdPhotos(backend);
  equal(calls, [[retired], [null, home]]);
});

Deno.test("a path outside the retired household never reaches Storage", async () => {
  const calls: string[] = [];
  const result = await Promise.allSettled([cleanHouseholdPhotos({
    claim: () =>
      Promise.resolve({
        claim_id: claim,
        staged_paths: [],
        retired_id: home,
        retired_paths: [`${home}/../other/photo.jpg`],
      }),
    remove() {
      calls.push("remove");
      return Promise.resolve();
    },
    complete() {
      calls.push("complete");
      return Promise.resolve();
    },
  })]);
  if (result[0].status !== "rejected") throw new Error("Expected rejection");
  equal((result[0].reason as Error).message, "photo_cleanup_retry");
  equal(calls, []);
});
