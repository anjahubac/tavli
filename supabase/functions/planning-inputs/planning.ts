// Ukusi članova za plan obroka (spec 019 FR-004, ugovor 008).
//
// Server sam određuje domaćinstvo i učesnike (svi trenutni članovi), daje
// listu vidljivih namirnica i poziva `planning_advisory_inputs` sa
// `for_provider = true`: doprinose samo članovi koji su uključili deljenje
// za planiranje, i za sopstvene podatke, jer rezultat ide AI-ju. Odgovor ima
// tačno šest nizova ukusa: bez članova, imena, omiljenih i alergena.
// Ništa se ne kešira i ne loguje.

export const tasteKeys = [
  "likedFoodIds",
  "dislikedFoodIds",
  "likedDishKinds",
  "dislikedDishKinds",
  "likedCuisineCodes",
  "dislikedCuisineCodes",
] as const;

export type Tastes = Record<(typeof tasteKeys)[number], string[]>;

export interface AdvisoryRequest {
  actor: string;
  household: string;
  participants: string[];
  visibleFoodIds: string[];
}

export interface PlanningDependencies {
  /** Id prijavljenog (ne anonimnog) korisnika ili null. */
  authenticate(token: string): Promise<string | null>;
  /** Domaćinstvo korisnika (najviše jedno) ili null. */
  householdOf(uid: string): Promise<string | null>;
  membersOf(household: string): Promise<string[]>;
  /** Namirnice iz ukusa [participants] koje [household] sme da vidi. */
  visibleTasteFoods(household: string, participants: string[]): Promise<
    string[]
  >;
  advisory(request: AdvisoryRequest): Promise<unknown>;
  /** Ograničenje zahteva po korisniku; false znači 429. */
  allow(uid: string): boolean;
}

const maxBodyBytes = 1024;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const maxItems = 500;

const headers = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};

function respond(status: number, body: unknown, extra?: HeadersInit) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, ...extra },
  });
}

const failure = (status: number, error: string) => respond(status, { error });

/** Čita `{"householdId": uuid}`; sve ostalo je nevažeće. */
export async function parseRequest(request: Request): Promise<string | null> {
  if (Number(request.headers.get("Content-Length")) > maxBodyBytes) return null;
  const text = await request.text();
  if (new TextEncoder().encode(text).length > maxBodyBytes) return null;
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    return null;
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return null;
  }
  const keys = Object.keys(body);
  const id = (body as Record<string, unknown>).householdId;
  return keys.length === 1 && typeof id === "string" && uuid.test(id)
    ? id
    : null;
}

/** Tačno šest nizova kratkih tekstova; višak (npr. omiljeni) se odbacuje. */
export function project(raw: unknown): Tastes {
  if (typeof raw !== "object" || raw === null) {
    throw new Error("planning_inputs_shape");
  }
  const source = raw as Record<string, unknown>;
  const result = {} as Tastes;
  for (const key of tasteKeys) {
    const value = source[key];
    if (
      !Array.isArray(value) || value.length > maxItems ||
      !value.every((v) => typeof v === "string" && v.length <= 64)
    ) {
      throw new Error("planning_inputs_shape");
    }
    result[key] = value as string[];
  }
  return result;
}

export function planningInputs(deps: PlanningDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return failure(405, "method_not_allowed");
    }
    const token = /^Bearer ([^\s]+)$/i.exec(
      request.headers.get("Authorization") ?? "",
    )?.[1];
    if (!token) return failure(401, "unauthorized");
    try {
      const uid = await deps.authenticate(token);
      if (!uid) return failure(401, "unauthorized");
      if (!deps.allow(uid)) {
        return failure(429, "rate_limited");
      }
      const expected = await parseRequest(request);
      if (!expected) return failure(400, "bad_request");
      // Domaćinstvo se promenilo usred zahteva: ukusi novog ne idu u plan
      // starog. Aplikacija tada staje i ne pravi plan sa tuđim podacima.
      const household = await deps.householdOf(uid);
      if (household !== expected) return failure(409, "household_changed");
      const participants = await deps.membersOf(household);
      if (!participants.includes(uid)) {
        return failure(409, "household_changed");
      }
      const visibleFoodIds = await deps.visibleTasteFoods(
        household,
        participants,
      );
      const tastes = project(
        await deps.advisory({
          actor: uid,
          household,
          participants,
          visibleFoodIds,
        }),
      );
      return respond(200, tastes);
    } catch {
      return failure(500, "internal");
    }
  };
}

/** Id-jevi namirnica iz liked/disliked nizova profila (samo ispravni uuid). */
export function tasteFoodIds(profiles: unknown[]): string[] {
  const ids = new Set<string>();
  for (const p of profiles) {
    if (typeof p !== "object" || p === null) continue;
    for (const key of ["likedFoodIds", "dislikedFoodIds"]) {
      const list = (p as Record<string, unknown>)[key];
      if (!Array.isArray(list)) continue;
      for (const id of list) {
        if (typeof id === "string" && uuid.test(id)) ids.add(id);
      }
    }
  }
  return [...ids].sort().slice(0, maxItems);
}

export const isUuid = (value: string) => uuid.test(value);

/**
 * Ograničenje u memoriji jedne instance funkcije: najviše [limit] zahteva po
 * korisniku u minuti. Zaštita od petlje u aplikaciji, ne trajna kvota.
 */
export function minuteLimiter(limit: number, now: () => number = Date.now) {
  const windows = new Map<string, { start: number; count: number }>();
  return (uid: string): boolean => {
    const minute = Math.floor(now() / 60_000);
    const current = windows.get(uid);
    if (!current || current.start !== minute) {
      if (windows.size > 10_000) windows.clear();
      windows.set(uid, { start: minute, count: 1 });
      return true;
    }
    current.count++;
    return current.count <= limit;
  };
}
