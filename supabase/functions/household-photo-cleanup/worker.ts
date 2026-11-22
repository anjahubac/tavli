export type CleanupBatch = {
  claim_id: string;
  staged_paths: string[];
  retired_id: string | null;
  retired_paths: string[] | null;
};

type CleanupBackend = {
  claim(): Promise<CleanupBatch>;
  remove(paths: string[]): Promise<void>;
  complete(stagedClaim: string | null, retiredId: string | null): Promise<void>;
};

const uuid = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/;
const stagedPath = /^[0-9a-f-]{36}\/joinphoto-[0-9a-f]{64}\.jpg$/;

function retiredPath(path: string, id: string): boolean {
  const prefix = `${id}/`;
  return path.startsWith(prefix) &&
    path.slice(prefix.length).split("/").every((part) =>
      part !== "" && part !== "." && part !== ".." && !part.includes("\\")
    );
}

export async function cleanHouseholdPhotos(
  backend: CleanupBackend,
): Promise<void> {
  const batch = await backend.claim();
  // Both queues get an attempt even if one batch hits a Storage error.
  const results = await Promise.allSettled([
    (async () => {
      if (!batch.staged_paths.length) return;
      if (
        !uuid.test(batch.claim_id) ||
        !batch.staged_paths.every((path) => stagedPath.test(path))
      ) {
        throw new Error("invalid_staged_paths");
      }
      await backend.remove(batch.staged_paths);
      await backend.complete(batch.claim_id, null);
    })(),
    (async () => {
      const id = batch.retired_id;
      if (id === null) return;
      const paths = batch.retired_paths ?? [];
      if (!uuid.test(id) || !paths.every((path) => retiredPath(path, id))) {
        throw new Error("invalid_retired_paths");
      }
      if (paths.length) await backend.remove(paths);
      await backend.complete(null, id);
    })(),
  ]);
  if (results.some((result) => result.status === "rejected")) {
    throw new Error("photo_cleanup_retry");
  }
}
