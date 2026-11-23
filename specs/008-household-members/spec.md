# Specification: Household, member preferences and personal choices

**ID**: 008-household-members | **Feature key**: HOUSEHOLD
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 3 | **Proposed independent reviewer**: Dev 1 and Dev 2

## Scope and source

Implements the HOUSEHOLD portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

The 2026-11-20 direction agreed with Matija (Dev 3) supersedes the original
invitation behavior in [Trello #58](https://trello.com/c/lkL6PzXU),
[#59](https://trello.com/c/zshRjGSY) and [#60](https://trello.com/c/GX84OkvD).
The ticket IDs and original assignment are retained for traceability.

## Requirements and source traceability

- **FR-001**: Deliver **Agree the member-input contract for planning**. Source D3-001; Dev 3; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Complete sign-in refinements**. Source D3-002; Dev 3; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-003**: Deliver **Provide taste and preference settings**. Source D3-004; Dev 3; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-004**: Deliver **Create invitation data and access rules**. Source D3-005; Dev 3; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-005**: Deliver **Provide household invitation UI**. Source D3-006; Dev 3; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-006**: Deliver **Join a household with confirmation**. Source D3-007; Dev 3; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-007**: Deliver **Manage household members and roles**. Source D3-008; Dev 3; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-008**: Deliver **Choose structured allergens per member**. Source D3-009; Dev 3; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-009**: Deliver **Display allergens on ingredients and recipes**. Source D3-010; Dev 3; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-010**: Deliver **Store favorites per member**. Source D3-011; Dev 3; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-011**: Deliver **Rate recipes**. Source D3-018; Dev 3; phase 4. A member has one current 1–5-star rating per saved recipe; recooking may update it. An optional note is private to its author. Household members see only the aggregate average and number of ratings, never another member's rating or note. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Any current member, owner or not, can share the same reusable invite credential of their household (decision 2026-11-23) as a link, QR payload or a manually entered code. New credentials have twelve random characters from an alphabet of 32 symbols. Display three groups of four. Manual entry accepts lowercase, spaces and hyphens. The in-app QR scanner reads the same code. The configured Supabase project hosts the HTTPS redirect. App links, QR and manual entry converge on the same authenticated preview and explicit confirmation. The preview reveals the destination name and whether the caller is the last member of their source household. The owner can replace the invite with a new one (decision 2026-11-23); the old link, QR and code stop working at once and memberships stay. The invite has no scheduled expiry, recipient binding, active invites list, join request or owner approval. It is unavailable once the destination household is deleted.
- **FR-102**: Show the destination household name before changing membership. The existing membership, including the personal household provisioned for a new account, is the source. If source and destination differ, ask whether to leave and offer “Da, ponesi moje recepte”, “Da, bez recepata” and “Ne, ostani ovde”. Either affirmative choice joins as a member and leaves the source in one server transition. The first copies recipes created by the departing user and legacy recipes with no known creator, including eligible content from a solo household before deletion. Each copy is independent. When members remain, the originals stay in the source. The second option copies zero recipes. Plans, shopping and pantry do not transfer. Cancel leaves both households untouched. Opening the link of the current household causes no transition.
- **FR-103**: A departing owner automatically hands ownership to the longest-serving remaining member, ordered by the earliest membership join time and then by ascending user UUID to break ties. Before the last member leaves, show an explicit permanent-deletion warning and require acknowledgement as part of the switch. After confirmation and any selected recipe copies, delete the empty household and its remaining shared data, including recipes, plans, shopping, pantry and source photo objects. Its link stops working. Personal account data retains its existing access and lifecycle. The owner can remove a member through the member-management slice. Removal ends access under the old membership; under the bearer-link rule, a removed user who still has the link can join again until the owner replaces the invite. When a device later sees that the account moved to a new personal household with the owner role, it shows a one-time removal notice naming the old and new household (decision 2026-11-23).
- **FR-103a**: Account deletion uses the same ownership succession rule and household locks as a switch. Shared data and the existing invite stay with remaining members. Deleting the last member retires the household and queues its photos for cleanup before deleting the login. A retry resumes any pending photo cleanup.
- **FR-104**: Each person chooses tastes, structured allergens, favorites and recipe ratings. Same-household membership does not grant broad access to private records.
- **FR-105**: Preserve existing email-code/name/confirmation flow and close confirmed defects with regression tests; use canonical reviewed allergen/avoidance vocabulary.
- **FR-106**: Planning takes an explicit nonempty set of participating member IDs, defaulting in the UI to all current household members. Only those members' inputs contribute; unknown, foreign or removed IDs fail the whole request.
- **FR-107**: Members select canonical allergen groups, distinct from catalog foods and taste dislikes. Catalog foods carry reviewed group mappings; unresolved ingredients have unknown allergen status, never an implicit safe status.
- **FR-108**: Members may like or dislike catalog foods, the existing `DishKind` values and reviewed cuisine codes, and, in a later slice, add an optional short planning note with separate consent. These are soft preferences. No dietary-mode setting or custom style category is included.
- **FR-109**: A favorite is a personal user/recipe pair. Only selected participants' favorites for accessible household recipes contribute to planning; delete the pair when the recipe is deleted or the user loses access on leaving the household.
- **FR-110**: The planning consumer receives only the authorized aggregate of selected participants' tastes and favorite counts. Separately consented notes are added in a later slice. The server plan endpoint reads selected participants' allergen restrictions separately. Personal rows, profiles and diary entries are outside the aggregate.
- **FR-111**: Each member explicitly opts in to sharing structured preferences and favorites with household planning. A separate `planningNote` flag is enabled with the later note slice. Defaults are off, only the owner can change them, and withdrawal takes effect on server acknowledgement. The first release re-reads consent for personalized planning and keeps no aggregate cache. The server omits unshared fields; the caller's own tastes, notes and favorites are returned regardless of flags when the caller is the only participant. See the contract's Disclosure and consent section.
- **FR-112**: A request for a single other participant returns only that person's consented fields, with no name or ID. AI output is untrusted: a leak guard rejects responses that echo names, emails, notes or attributed allergies, and prompts use pseudonymous labels and are never logged.
- **FR-113**: For planning, the server plan endpoint uses the selected allergen codes present at request time to pre-filter candidates and check results. An empty selection contributes no codes and does not block planning. A profile reminder is deferred. Planning never sends member allergen selections to an AI provider, returns them to a client or logs them. The owner-only settings path handles the member's own selections; planning needs no allergen-sharing flag. Type, import-boundary, outbound-guard and canary regression tests keep it that way. See the contract's Allergen protection section.

## User scenarios and acceptance

- **US1 / SC-001**: A valid shared link, scanned code or manually entered code previews the destination name and the caller’s own switch consequences before confirmation. Invalid tokens, unavailable households and unauthenticated callers cannot join. Cancel and opening one's own household link leave data unchanged. Two eligible accounts can independently join through the same link.
- **US1 / SC-004**: Each affirmative choice results in exactly one membership. The recipe choice applies only to eligible recipes; the other choice transfers none. The source's plan, shopping and pantry are absent from the destination. Departure of an owner promotes the longest-serving remaining member. A last-member switch without acknowledgement, or one that became a last-member switch after preview, leaves the source intact. With the warning acknowledged, the source and its remaining shared data are deleted and its link becomes unavailable. Failed or repeated transitions cannot partially move data, duplicate copies or leave the user without a membership.
- **US1 / SC-005**: An offline or stale client cannot apply a household switch using an outdated source or replay source writes into the destination. After a lost response it can reconcile with the server and retry safely.
- **US2 / SC-002**: A removed member reconnects with queued writes: server denies old-household access; another member retains shared data.
- **US3 / SC-003**: Two co-members can share recipes but cannot read each other's diary or personal settings outside the agreed planning aggregate.
- **US4 / SC-004**: With two members selected, either member's allergen excludes a mapped candidate even when AI suggests it. With seven reviewed ingredients and one unresolved ingredient, automatic recommendations omit the recipe. Opening it for manual cooking shows “Mogući alergeni: nepoznata namirnica”. Selecting one member omits the other's inputs.
- **US5 / SC-005**: One member likes a food and another dislikes it; the conflict affects ranking without becoming a safety ban. A deleted recipe or departing member stops contributing favorites.
- **US6 / SC-006**: Co-members cannot read one another's raw personal settings; a foreign or removed participant ID yields no partial aggregate.
- **US7 / SC-007**: A preference or note a member has not shared never appears in another member's plan inputs, prompt or UI, for one or several participants; withdrawing consent removes it. An AI response that echoes a name, note or attributed allergy is rejected and never shown or stored.
- **US8 / SC-008**: With a member's allergen selected, no planning AI request, log, cached plan input or client plan response contains it (canary test across planner flows), and an allergenic recipe, a recipe with unresolved ingredients or a recipe outside the eligible pool cannot enter the initial personalized draft. If Dev 2 adds invented drafts later, apply the same server checks before any use.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

- Privacy: the preview reveals only the destination name from the target household to a signed-in bearer. Server-owned
  membership and RLS govern household data. Personal preferences, allergens,
  favorites, ratings and diary data retain their personal access rules.
- Abuse: a forwarded link allows repeated joins by signed-in bearers. Use an
  opaque random token, server-side rate limits and generic failures. Member
  removal ends access at the server. A separate ban or blocklist is outside
  the agreed flow.
- Credentials: keep the invite token out of diagnostics, analytics, public
  table reads and the sync payload. No new provider credential or AI work.
- Files: eligible recipe photos and snapshots require copies under verified
  private destination paths. Source objects for an empty household are deleted
  after the membership transition commits.
- Deployment: migrations and verification follow 012/013 with synthetic
  accounts. Hosted controls remain unverified.
- Ratings: recipe rating summaries expose only average and count to current
  household members; individual ratings and notes remain owner-only.

## Exact UI copy carried forward

“Domaćinstvo”, “Pozovi člana”, “Pridruži se”, “Ukusi i sklonosti”, “Omiljeni”, “Alergeni”, “Volim”, “Ne volim”, “Opis”, “Mogući alergeni: nepoznata namirnica”.

Switch confirmation: “Da li ste sigurni da želite da napustite domaćinstvo?”
Actions: “Da, ponesi moje recepte”, “Da, bez recepata”, “Ne, ostani ovde”.
Last-member warning: “Poslednji ste član ovog domaćinstva. Ako odete, domaćinstvo i podaci koji ostanu u njemu biće trajno obrisani.” Show the destination name and explain which recipes will be copied before confirmation.

The canvas copy supersedes the earlier code-entry wording (“Proveri pozivnicu”,
“Prelaziš u domaćinstvo …”) as of 2026-11-22. Profile shows “Domaćinstvo”,
“{n} član/člana/članova”, “Vlasnik · ti”, “Član”, “Izmeni domaćinstvo”, “Podeli
domaćinstvo” with “QR kod, kod ili link”, and “Pridruži se novom domaćinstvu”.
That row first opens a choice dialog titled “Pridruži se novom domaćinstvu”
with “Kreiraj novo domaćinstvo”, “Pridruži se postojećem domaćinstvu” and
“Odustani” (decision 2026-11-23, no canvas frame yet). Joining continues to the
join sheet below. Creating opens “Novo domaćinstvo” with only “Naziv
domaćinstva” (placeholder “Moje domaćinstvo”), “Odustani” and “Nastavi”
(offline: “Nema interneta. Za novo domaćinstvo je potrebna veza.”); the server
(`prepare_new_household`) creates an empty named household with an invite code,
and the rest is the same confirmation flow as joining, with “Novo domaćinstvo”
instead of “Pozvan si u” above the name. The creator becomes its owner.
The join sheet uses “Pridruži se domaćinstvu”, “Skeniraj QR kod sa telefona
člana ili unesi kod pozivnice.” (desktop: “Unesi kod pozivnice. Ako otvoriš
link iz poruke, kod je već upisan.”), “Skeniraj QR kod”, “ili”, “Kod
pozivnice”, “Odustani” and “Nastavi”. The confirmation shows “Pozvan si u”
above the destination name. The recipe choice explains “Možeš da poneseš
recepte koje si ti napravio i stare recepte bez poznatog autora.” When members
remain, it adds “Plan, nabavka i ostava ostaju u domaćinstvu „{name}“.” The
last-member step is titled “Trajno brisanje domaćinstva”, uses the warning above,
“Razumem da je brisanje trajno”, “Odustani” and a red “Pridruži se”.

The first sign-in step after the name is “Tvoje domaćinstvo”: “U domaćinstvu
deliš plan, nabavku, ostavu i recepte. Daj mu naziv ili se pridruži
domaćinstvu u koje si pozvan.”, “Naziv domaćinstva” (placeholder “Moje
domaćinstvo”), “Nastavi”, “ili”, “Pridruži se postojećem domaćinstvu”. Joining
from this step confirms with “U domaćinstvu delite plan, nabavku, ostavu i
recepte.”, “Pridruži se” and “Odustani”. Errors: “Nema interneta. Za ovaj korak
je potrebna veza.”, “Čuvanje nije uspelo. Pokušaj ponovo.”, “Naziv može imati
najviše 40 znakova.”

Sharing uses “Podeli domaćinstvo”, “Skeniraj QR u aplikaciji Tavli ili unesi kod
u „Pridruži se domaćinstvu“.” (desktop: “Skeniraj QR telefonom u aplikaciji
Tavli. Na računaru otvori link ili unesi kod.”), “Kod pozivnice”, “Pošalji
pozivnicu”, “Kopiraj link”, “Kopiraj kod”, “Kod je kopiran.”, “Link je
kopiran.”, owner-only “Napravi novu pozivnicu”, “Napraviti novu pozivnicu?”,
“Stari kod, QR i link prestaju da rade. Članovi ostaju u domaćinstvu.”,
“Napravi novu”, “Nova pozivnica je spremna.”, “Nema interneta. Nova pozivnica
se pravi uz vezu.”, “Nova pozivnica nije napravljena. Pokušaj ponovo.”, “Pozivnicu može da iskoristi svako ko dobije kod, zato je šalji samo
ljudima s kojima deliš domaćinstvo.”, “Pozivnica nije dostupna”, “Nema
interneta. Pozivnica se prikazuje uz vezu.” The share text is “Pridruži mi se u
domaćinstvu „{name}“ u aplikaciji Tavli: {link}” followed by “Kod pozivnice:
{code}”. The scanner uses “Skeniraj QR kod”, “Postavi QR kod u okvir”, “Kod se
čita sam, ne moraš ništa da pritiskaš.”, “Svetlo”, “Unesi kod”, “Zatvori” and
“Kamera nije dostupna. Dozvoli pristup kameri u podešavanjima telefona ili
unesi kod.”

Member management uses “Izmeni domaćinstvo”, “Naziv domaćinstva”, “Članovi”,
“Ukloni člana {name}”, “Ukloni člana?”, “Da li ste sigurni da želite da uklonite
člana {name} iz domaćinstva? Više neće videti zajednički plan, nabavku ni
ostavu.”, “Ukloni”, “Sačuvaj”, “Članovi trenutno nisu dostupni.”, “Člana
trenutno nije moguće ukloniti.”, “Nema interneta. Za uklanjanje je potrebna
veza.” and “Nema interneta. Naziv se menja uz vezu.” The removed member's
notice is “Više nisi u domaćinstvu „{old}“”, “Vlasnik te je uklonio iz
domaćinstva. Sada si u svom domaćinstvu „{new}“. Plan, nabavka, ostava i
recepti starog domaćinstva ostaju tamo.” with “U redu”.
Recovery uses “Prijavi se ponovo.”, “Članstvo se promenilo. Proveri pozivnicu ponovo.”,
“Prenos fotografija još nije uspeo. Pokušaj ponovo.”, or
“Prelazak nije uspeo. Pokušaj ponovo.” with “Pokušaj ponovo”. An offline
device shows “Nema interneta. Za prelazak je potrebna veza.” and a temporary
invite error shows “Pozivnica trenutno nije dostupna. Pokušaj ponovo.”

If the offline cache opens before the server confirms membership, Profile shows
“Sinhronizacija čeka proveru članstva.”

While waiting for old-household edits, show “Sinhronizujemo izmene…”. After
30 seconds, show “Neke izmene u starom domaćinstvu još nisu sačuvane na serveru.”
with “Nastavi da čekaš” and “Pređi bez nesinhronizovanih izmena”. Retry in the
meantime. A terminal rejection retains its diagnostic code locally and does
not block the switch. The explicit skip applies only to old-household edits,
and takes effect only after the server confirms the membership change.

### Tastes and allergens screen (variant A)

The screen follows the canvas “Predlog: Ukusi i alergeni”, variant A
(iOS and macOS artboards `Profil`, `Ukusi A`, `Dodaj omiljeni recept`,
`Dodaj namirnicu`). Route `/profile/tastes`, opened from Profil › Ishrana.
The free-text “O meni” note, the AI suggestion “Predloži iz mojih recepata”
and the “Deli opis” consent are deferred to the later note slice.

- Profil: section “Ishrana”, row “Ukusi i alergeni”, summary such as
  “2 alergena · 6 sviđanja · 3 omiljena recepta” (zero parts omitted;
  “Ništa nije izabrano” when nothing is chosen). “Sviđanja” counts liked dish
  kinds, cuisines and foods.
- Intro: “Tavli ovo koristi da predloži jela koja ti prijaju.”
- “Alergeni”, summary “Izabrano: {n}” or “Nijedan”, help “Jela sa ovim
  sastojcima ne ulaze u plan.” Labels: Gluten, Mleko,
  Jaja, Orašasti plodovi, Kikiriki, Riba, Rakovi, Mekušci, Soja, Susam, Celer,
  Slačica, Sulfiti, Lupina.
- “Vrste jela” with help “Dodirni jednom za Volim, još jednom za Ne volim.”;
  “Kuhinje” (Srpska, Italijanska, Japanska, Francuska, Meksička). Wide layout:
  “Vrste jela i kuhinje” with “Klik: Volim · još jednom: Ne volim”.
- “Omiljeni recepti” with “Dodaj”; wide empty state “Još nema omiljenih recepata.”
  Picker: “Omiljeni recepti”, “Izabrano: {n}”, “Pretraži recepte”, “Moji recepti”,
  “Gotovo”, “Nema recepta sa tim imenom.”; wide dialog “Klikni recept da ga dodaš
  ili ukloniš.”, “Samo omiljeni”, “Zatvori”. No recipes: “Još nema recepata” /
  “Dodaj recept u Receptima, pa ga označi kao omiljeni.” A recipe that left the
  household: “Recept više nije dostupan.” Heart button labels: “Dodaj u
  omiljene: {naziv}” and “Ukloni iz omiljenih: {naziv}”.
- “Namirnice” with help “Ono što ne voliš ne zabranjuje jelo, samo ga ređe
  predlažemo.”, groups “Volim” and “Ne volim”, chip action “Ukloni {naziv}”.
  Each group ends with a “Dodaj” pill that opens the picker (phone sheet,
  wide dialog) preset to that group: “Dodaj namirnicu”, “Pretraži namirnice”, “Već je u Volim”,
  “Već je u Ne volim”, “Ukloni”, “Nema te namirnice u katalogu.”; empty
  catalog “Katalog namirnica još nije preuzet” / “Namirnice stižu sa servera
  kad je aplikacija na mreži.” Wide layout: “Volim” and “Ne volim” labels
  on the left with the pills beside them (product owner review replaced the
  canvas search field and its keyboard shortcuts).
- “Plan domaćinstva”: switch “Deli ukuse i omiljene”, subtitle “Pomaže u
  preporuci recepata pomoću AI-a.”, lock note “Alergene plan uvek poštuje, i kad je
  deljenje isključeno.” Product owner review shortened the intro, allergen,
  sharing and lock copy from the canvas text. On a wide screen the page is
  centered and the two columns have a wider gap than the canvas.
- Consent confirmation before enabling (not on the canvas; required by the
  [contract](contracts/member-planning-inputs.md#disclosure-and-consent), which
  asks the consent text to name the AI provider; needs Dev 4 review):
  title “Deli ukuse i omiljene?”, message “Tvoji ukusi i omiljeni recepti
  pomažu kad Tavli pravi plan za celo domaćinstvo. Za taj plan šalju se AI
  servisu (Gemini, Groq ili OpenRouter), bez tvog imena. Ostali članovi ne
  vide tvoje izbore. Deljenje možeš da isključiš kad god želiš.”, actions
  “Otkaži” / “Deli”. Turning sharing off needs no confirmation.
- Consent errors: “Nema veze sa internetom. Deljenje nije promenjeno.”,
  “Deljenje je promenjeno na drugom uređaju. Proveri i pokušaj ponovo.”,
  “Deljenje nije promenjeno. Pokušaj ponovo.”; unreadable consent: notice
  “Deljenje se menja samo uz internet. Trenutno ne možemo da proverimo
  podešavanje.” with “Pokušaj ponovo”.

Deviations from the canvas, kept for the accessibility and icon rules of the
[UI standard](../../docs/development/ui-standard.md): hearts are outline
icons (no filled icons); chips keep the 44 px look inside a 48 px touch area,
and the removable food chip is 44 instead of 40 px tall; desktop chips keep
the phone size instead of the denser 34 px canvas size; the profile row uses
the plain list-row icon instead of a tinted square.

Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.
For ratings, the agreed phrases are “Da li ti se svidelo?” and “Oceni”. The
rating UI is intentionally a later design step; no modal or repeated prompt is
part of this contract.

## Dependencies and open decisions

The private dish-kind slice uses the existing taste-profile storage and sync.
Later slices follow the catalog, membership and [015 gateway](../015-ai-server-gateway/spec.md)
dependencies in the [implementation plan](plan.md).

- **Q1, resolved for direct join by Matija (Dev 3), 2026-11-20**: Copy
  caller-created and unknown-creator recipes when requested, promote the
  longest-serving remaining member, and permanently delete an empty source
  after warning and acknowledgement. Dev 1 reviews the technical contract,
  standalone leave/removal behavior and offline compatibility separately.
- **Q2**: Matija decided on 2026-11-20 that selected participants contribute favorites and all household members are selected by default. Allergens are separate groups linked to users and catalog foods; dislikes remain soft. Matija decided on 2026-11-21 that planner allergen data remains server-only. Matija confirmed using the existing catalog checker codes and keeping catalog mapping review with Dev 1. Food mappings, structured taste limits, consent implementation and server integration still require coordination. See [member planning inputs contract](contracts/member-planning-inputs.md).

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
