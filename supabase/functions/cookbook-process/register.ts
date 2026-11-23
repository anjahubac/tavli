// Registracija knjige koju je aplikacija već otpremila u privatni bucket.
// Klijent koristi jedinstvenu putanju; originalno ime ostaje u redu knjige.

export const MAX_BOOKS_PER_HOUSEHOLD = 20;

export class LimitReachedError extends Error {
  constructor() {
    super("cookbook_limit");
    this.name = "LimitReachedError";
  }
}

export class DuplicateBookError extends Error {
  constructor() {
    super("cookbook_duplicate");
    this.name = "DuplicateBookError";
  }
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface RegisterDeps {
  isMember: (userId: string, householdId: string) => Promise<boolean>;
  objectExists: (storagePath: string) => Promise<boolean>;
  readObject: (storagePath: string) => Promise<Uint8Array>;
  deleteObject: (storagePath: string) => Promise<void>;
  countBooks: (householdId: string) => Promise<number>;
  findByPath: (
    householdId: string,
    storagePath: string,
  ) => Promise<{ id: string; status: string } | null>;
  findByHash: (householdId: string, hash: string) => Promise<boolean>;
  embeddingModel: string;
  createBook: (b: {
    householdId: string;
    path: string;
    filename: string;
    title: string;
    userId: string;
    contentSha256: string;
    embeddingModel: string;
  }) => Promise<{ id: string; status: string }>;
}

export type RegisterResult =
  | { ok: true; id: string; status: string }
  | {
    ok: false;
    error:
      | "bad_request"
      | "forbidden"
      | "not_found"
      | "limit_reached"
      | "duplicate";
  };

export async function registerBook(
  deps: RegisterDeps,
  userId: string,
  req: { storagePath: unknown; filename: unknown; title: unknown },
): Promise<RegisterResult> {
  const path = req.storagePath;
  if (typeof path !== "string" || path.length > 400) return bad();
  const parts = path.split("/");
  if (parts.length !== 2 || !UUID.test(parts[0])) return bad();
  const [fileId, pathExtension] = parts[1].split(".");
  if (
    !UUID.test(fileId) ||
    !["pdf", "epub"].includes(pathExtension?.toLowerCase())
  ) return bad();

  const filename = typeof req.filename === "string" ? req.filename.trim() : "";
  if (
    filename.length < 5 || filename.length > 255 ||
    /[\\/]/.test(filename) || filename.includes("..") ||
    !filename.toLowerCase().endsWith(`.${pathExtension.toLowerCase()}`)
  ) return bad();

  let title = typeof req.title === "string" ? req.title.trim() : "";
  if (title.length > 200) return bad();
  if (title === "") title = filename.replace(/\.(pdf|epub)$/i, "").trim();
  if (title === "") return bad();

  const householdId = parts[0];
  if (!(await deps.isMember(userId, householdId))) {
    return { ok: false, error: "forbidden" };
  }
  const existing = await deps.findByPath(householdId, path);
  if (existing) return { ok: true, id: existing.id, status: existing.status };
  if (!(await deps.objectExists(path))) {
    return { ok: false, error: "not_found" };
  }

  const bytes = await deps.readObject(path);
  const digestInput = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(digestInput).set(bytes);
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", digestInput),
  );
  const contentSha256 = Array.from(
    digest,
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
  if (await deps.findByHash(householdId, contentSha256)) {
    await deps.deleteObject(path);
    return { ok: false, error: "duplicate" };
  }
  if ((await deps.countBooks(householdId)) >= MAX_BOOKS_PER_HOUSEHOLD) {
    return { ok: false, error: "limit_reached" };
  }

  try {
    const book = await deps.createBook({
      householdId,
      path,
      filename,
      title,
      userId,
      contentSha256,
      embeddingModel: deps.embeddingModel,
    });
    return { ok: true, id: book.id, status: book.status };
  } catch (e) {
    if (e instanceof LimitReachedError) {
      return { ok: false, error: "limit_reached" };
    }
    if (e instanceof DuplicateBookError) {
      await deps.deleteObject(path);
      return { ok: false, error: "duplicate" };
    }
    throw e;
  }
}

function bad(): RegisterResult {
  return { ok: false, error: "bad_request" };
}
