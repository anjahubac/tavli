# Household invitations handoff

Resume on branch `008-household-join`. The active ticket is
[Trello #58](https://trello.com/c/lkL6PzXU) (D3-005 / FR-004). The
[spec](spec.md), [plan](plan.md), and [tasks](tasks.md) hold the full contract.
The invitation screen is [Trello #59](https://trello.com/c/zshRjGSY).
The join flow is [Trello #60](https://trello.com/c/GX84OkvD).

## Implemented

- The owner gets one reusable 12-character invite code in three groups of
  four. The QR payload is the plain code. The configured Supabase project's
  HTTPS endpoint redirects to `tavli://household/join`. The code travels in the
  URL fragment. Earlier 16- and 64-character codes still work.
- A signed-in recipient previews the destination name and confirms a direct
  switch. On request, copy the recipient's own recipes and recipes with an
  unknown creator, including history and private photos. The longest-serving
  member inherits ownership. An empty source household is deleted after
  explicit acknowledgement, and its photos are queued for cleanup.
- The Account and sync layers reconcile the confirmed membership and protect
  pending writes from crossing households. Changes are local to this branch
  and the test Supabase stack. Hosted verification is pending.
- Latest feature verification included 309 pgTAP checks, 394 affected Flutter
  tests, and a local HTTP smoke test for redirect, photo bytes, replay and
  source cleanup. See [implementation status](plan.md#implementation-status).

## Resume and finish

On the other machine, use an existing Tavli checkout and select the branch.

```sh
git fetch origin
git switch --track origin/008-household-join
flutter pub get
```

If the local branch already exists, use `git switch 008-household-join`.
Check the latest `origin/dev` before implementation or review. The branch
started at `6e560f6` and upstream has advanced. Use the local Supabase stack
and synthetic accounts for backend checks. Local credentials come from the
existing setup on the new machine. Follow the repo preference about app launches.

1. With Dev 4, agree the Profile and join screens. Wire sharing, QR display
   and scanning, and manual entry to the same preview and confirmation flow.
   Preserve the invite through sign-in. Use the Serbian copy in the spec.
2. Register and route `tavli://` on Android, iOS, macOS and Linux. On Linux
   the installer needs a `.desktop` entry for `x-scheme-handler/tavli`. Verify
   browser delivery when Tavli is closed and when it is already running.
   Windows registration belongs with the future Windows app.
3. Review and validate locally, then verify the hosted backend after the
   existing CI deploys the approved changes. Member removal is a later
   [Trello #61](https://trello.com/c/P32n3URr) slice.

Matija accepted the custom-scheme risk for the first release. Another
installed app can register the same scheme and receive the code. A signed-in
bearer with the code can rejoin while the invite remains active. Manual
entry and in-app scanning bypass the external redirect.
