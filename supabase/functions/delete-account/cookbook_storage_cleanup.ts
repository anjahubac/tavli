export interface CookbookStorageEntry {
  id: string | null;
  name: string;
}

export interface CookbookStorageBucket {
  list(
    path: string,
    options: { limit: number },
  ): Promise<{ data: CookbookStorageEntry[] | null; error: unknown }>;
  remove(
    paths: string[],
  ): Promise<{ data: unknown[] | null; error: unknown }>;
}

/** Briše sve objekte ispod domaćinstva, uključujući stare ugnježdene putanje. */
export async function removeHouseholdCookbooks(
  bucket: CookbookStorageBucket,
  householdId: string,
): Promise<void> {
  await removeFolder(bucket, householdId);
}

async function removeFolder(
  bucket: CookbookStorageBucket,
  folderPath: string,
): Promise<number> {
  let totalRemoved = 0;

  while (true) {
    const { data: entries, error } = await bucket.list(folderPath, {
      limit: 100,
    });
    if (error) throw error;
    if (!entries || entries.length === 0) return totalRemoved;

    const before = totalRemoved;
    const files: string[] = [];
    for (const entry of entries) {
      if (
        !entry.name || entry.name === "." || entry.name === ".." ||
        entry.name.includes("/") || entry.name.includes("\\")
      ) {
        throw new Error("invalid_cookbook_object_name");
      }

      const path = `${folderPath}/${entry.name}`;
      if (entry.id === null) {
        totalRemoved += await removeFolder(bucket, path);
      } else {
        files.push(path);
      }
    }

    if (files.length > 0) {
      const { data: removed, error: removeError } = await bucket.remove(files);
      if (removeError) throw removeError;
      if (!removed || removed.length === 0) {
        throw new Error("cookbook_storage_cleanup_no_progress");
      }
      totalRemoved += removed.length;
    }

    if (totalRemoved === before) {
      throw new Error("cookbook_storage_cleanup_no_progress");
    }
  }
}
