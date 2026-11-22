// Registracija knjige koju je aplikacija već otpremila u bucket `cookbooks`.
// Putanja je `{household_id}/{ime}.pdf|epub`: prvi deo mora biti domaćinstvo
// čiji je pozivalac član. Klijent ne piše tabelu knjiga; to radi samo ovde.

export const MAX_BOOKS_PER_HOUSEHOLD = 20;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export interface RegisterDeps {
  isMember: (userId: string, householdId: string) => Promise<boolean>;
  objectExists: (storagePath: string) => Promise<boolean>;
  countBooks: (householdId: string) => Promise<number>;
  findByPath: (
    householdId: string,
    storagePath: string,
  ) => Promise<{ id: string; status: string } | null>;
  createBook: (b: {
    householdId: string;
    path: string;
    title: string;
    userId: string;
  } & Record<string, unknown>) => Promise<{ id: string; status: string }>;
}

export type RegisterResult =
  | { ok: true; id: string; status: string }
  | { ok: false; error: "bad_request" | "forbidden" | "not_found" | "limit_reached" };

export async function registerBook(
  deps: RegisterDeps,
  userId: string,
  req: { storagePath: unknown; title: unknown },
): Promise<RegisterResult> {
  const path = req.storagePath;
  if (typeof path !== "string" || path.length > 400) return bad();
  const parts = path.split("/");
  if (parts.length !== 2 || !UUID.test(parts[0])) return bad();
  const file = parts[1];
  if (!/^[^/\\]+\.(pdf|epub)$/i.test(file) || file.includes("..")) return bad();

  let title = typeof req.title === "string" ? req.title.trim() : "";
  if (title.length > 200) return bad();
  if (title === "") title = file.replace(/\.(pdf|epub)$/i, "");

  const householdId = parts[0];
  if (!(await deps.isMember(userId, householdId))) {
    return { ok: false, error: "forbidden" };
  }
  const existing = await deps.findByPath(householdId, path);
  if (existing) return { ok: true, id: existing.id, status: existing.status };
  if (!(await deps.objectExists(path))) return { ok: false, error: "not_found" };
  if ((await deps.countBooks(householdId)) >= MAX_BOOKS_PER_HOUSEHOLD) {
    return { ok: false, error: "limit_reached" };
  }
  const book = await deps.createBook({ householdId, path, title, userId, filename: file });
  return { ok: true, id: book.id, status: book.status };
}

function bad(): RegisterResult {
  return { ok: false, error: "bad_request" };
}
