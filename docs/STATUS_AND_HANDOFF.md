# Family Spend Tracker — status and handoff

Branch: `main` · Last commit `2f3db9a` · Version `1.9.1+23`
Tests: **198 passing** (`cd mobile && flutter test`)
Published: v1.9.1 on GitHub, tagged `v1.9.1`

Supersedes `docs/V1.9.0_HANDOFF.md` for anything they disagree on. That file
still holds the detailed root-cause write-ups for the earlier bugs.

---

## 1. Everything that was asked for

In the order it was raised, with honest status.

| # | Request | Status |
|---|---|---|
| 1 | Muslim prayer times, gated behind a settings toggle | **Done, verified on device** |
| 2 | Advanced styling widgets for prayer times | **Done, verified on device** |
| 3 | Prayer time notifications | **Done** (scheduling verified; a real alert firing at a prayer has not been watched) |
| 4 | Samsung "dynamic island" / lock-screen add-expense | **Not built.** Groundwork committed |
| 5 | Camera to scan a bill into an expense | **Not built.** Dependency removed after it crashed the app |
| 6 | Lightweight — no RAM/battery/heat cost | **Held so far** |
| 7 | Rebuild the notepad, Notion/Clover style | **Done by another agent** (`cfa81db`) |
| 8 | Paste text → one checkbox per line, or a table | **Done** — parser + 32 tests |
| 9 | AI for restructuring, configurable provider, Gemini | **Done** — provider layer + settings screen |
| 10 | Recurring salary posts to family, should be personal | **Fixed in code. Migration NOT applied to the database** |
| 11 | Remove the "Family" option at the top | **Done, verified on device** |
| 12 | CSV import files salary/loan as expenses | **Fixed** — 16 tests. Not verified against your actual file |
| 13 | Prayer notification banner + customisation | **Done, verified on device** |
| 14 | Notes live editing, undo/redo, follow-user, conflicts | **Planned in detail, not started** |
| 15 | Direct messages between members | **Planned in detail, not started** |
| 16 | Web version (expenses read-only, notes + chat editable) | **Planned in detail, not started** |

---

## 2. What is pending, in priority order

### 2.1 Apply the database migrations — **blocking, do this first**

The recurring-salary fix is **half-live**: the Dart side shipped, the schema
change never did. Until this runs, a recurring salary is still credited to
whichever family member opens the app first.

```bash
cd /d/Repos/family_finance
supabase db push
```

The Supabase CLI is installed (`%LOCALAPPDATA%\supabase-cli`, v2.120.0) and the
project `cmjirnwoyocfupgxuoeb` is already linked and authenticated.

Pending or suspect:

| Migration | Purpose |
|---|---|
| `20261006230000_recurring_income_support.sql` | `recurring_charges.type`; lets a recurring row be income |
| `20261007090000_recurring_owner.sql` | `recurring_charges.owner_user_id`; fixes attribution |

**Verify afterwards** — the income migration was found truncated to 0 bytes at
one point, and a migration pushed while empty is recorded as applied forever:

```sql
select column_name from information_schema.columns
 where table_name = 'recurring_charges'
   and column_name in ('type','owner_user_id','auto_post','last_posted');
```

Expect four rows. If `type` is missing, run that migration's body by hand.

**Then** build the recurring owner picker — see §2.2.

### 2.2 Recurring owner picker

The backfill in `20261007090000` deliberately only filled families with exactly
one active member. **Your family has three**, so existing recurring rows have a
null `owner_user_id` and still fall back to the old behaviour. There is no UI to
set it, so the reported bug cannot actually be cleared by the user yet.

- `RecurringRow.ownerUserId` and `V3State.addRecurring(ownerUserId:)` exist.
- Add a member picker to `mobile/lib/v3/sheets/recurring_sheet_v3.dart`,
  defaulting to the signed-in member, mirroring the "For" picker in the
  add-entry sheet.
- Include `owner_user_id` in the `updateRecurring` patch map.
- Show the owner on each recurring row so a wrong one is visible.

### 2.3 Notes live editing (large)

Full design in `~/.claude/plans/swirling-skipping-puffin.md` §Phase 2. Decisions
already taken: **block-level** sync, not a character-level CRDT.

Verified facts that change the shape of this work:

- **Undo/redo already exists** (`note_editor_v3.dart:861-868`). The bug is that
  `_pushHistory` runs on **every keystroke** with a 50-entry cap, so undo reaches
  back ~50 characters. It needs coalescing, not building.
- **`notes` is already in the `supabase_realtime` publication**
  (`20261005185939_v2_schema.sql:456`) with `replica identity full`. No migration
  needed to subscribe.
- **Presence exists but carries no content** — `NotesPresenceService` tracks
  presence and a `typing` broadcast only, never `postgres_changes`. That is
  exactly why others see nothing.
- **The live indicators are not buttons.** `LiveBanner` and `LiveDot`
  (`notes_widgets.dart:12`, `:168`) have no `onTap`.
- **`_PresenceStrip` filters `p.noteId != null`** (`:2105`) — anyone editing any
  note, not this one.
- **`saveNote` is a full-row, last-write-wins upsert** (`v3_repository.dart:545`).
  Two editors silently overwrite each other.

Four traps that will bite whoever implements it:

1. **Do not prune empty blocks on autosave.** `_save():158` drops `b.isEmpty`.
   Run every 1.2s that deletes a block the user just added and paused in.
   Prune only on the final flush when the note closes.
2. **Suppress the `postgres_changes` self-echo.** Your own row UPDATE comes back
   to you; without an `updated_by == myId` guard it clobbers your focused block
   one round-trip after every autosave.
3. **`NoteBlock.copyWith` aliases `items`/`head`/`rows` by reference**
   (`note_blocks.dart:157`), so history snapshots share mutable lists. Add a
   `deepCopy()` for history.
4. **Rebase history on remote edits**, or undo will revert someone else's typing.

### 2.4 Direct messages (medium)

Full schema, RLS, RPCs and the Dart layer are specified in the plan file
§Phase 3. Nothing exists today — no chat screens, no messages tables.

### 2.5 Web version (medium)

Plan file §Phase 4. Only three reachable files break the web build:

| File | Problem |
|---|---|
| `v3/data/notification_bridge.dart:2` | `import 'dart:io'` — swap for `defaultTargetPlatform` |
| `v3/data/data_export.dart:1,3,128` | `dart:io` + `path_provider` — needs a conditional import |
| `v3/data/notifications_core.dart:2` | `flutter_local_notifications` 17 pulls `dart:io` via its Linux package |

Approach: **a separate web entry point**, not a retrofit. `flutter create
--platforms=web .`, then `lib/main_web.dart` + `lib/web/web_app.dart` composing
only web-safe providers and never constructing `PrayerController`. Avoids an FLN
major upgrade and leaves mobile untouched. `sqflite` is declared but never
imported — removing it kills a web warning for free.

### 2.6 Deferred from the original list

- **Item 4 — lock-screen quick-add / Samsung Now Bar.** Groundwork is committed:
  the `ff_live` channel, `quickAddAction`/`quickAddInput` ids, the
  `@pragma('vm:entry-point')` background handler, the `ActionBroadcastReceiver`
  in the manifest, and `pending_quick_add.dart` (queue + a parser that turns
  `"250 groceries"` into an amount and category). **Samsung has no "Dynamic
  Island"** — that is Apple's. Samsung's is the **Now Bar** (One UI 7+), which
  surfaces ongoing notifications; an app cannot place itself there on demand.
- **Item 5 — bill scanning.** `image_picker` is still a dependency and is safe.
  ML Kit was **removed** because it crashed the app — see §4.2. Re-adding it
  requires the keep rules in `docs/V1.9.0_HANDOFF.md` §5.6 *and* a device launch
  test.

---

## 3. What was completed, with evidence

### 3.1 Prayer times (items 1–3) — `b088f66`

Pure-Dart `adhan`; no API key, no network, no background service. Device-local
config (not `user_preferences`, which is family-scoped and would push one
member's Fajr alert to everyone). City picker needs no permission;
"Use my location" takes one coarse fix. Hijri date is tabular with a ±2 day
adjustment and is labelled "approx." rather than presented as authoritative.
Exact alarms are opt-in; inexact is the default because exact alarms are the
battery cost.

44 tests. Verified on device: settings render, all icons correct, the home card
shows ring + countdown + Arabic + day rail.

### 3.2 Prayer banner (item 13) — `d890d5d`, fixed in `2f3db9a`

Ongoing notification posted **once per prayer**. Android renders the countdown
itself via `usesChronometer` + `chronometerCountDown`, so the app never wakes to
tick it.

Four content modes (next only · next and current · all times · current ends at)
and six backgrounds (Aurora follows the time of day, plus Dusk, Emerald,
Midnight, Sand, Minimal), a tint toggle and a lock-screen visibility toggle.

**On glassmorphism:** Android cannot blur what sits behind a notification, and
from API 31 it wraps custom layouts in its own template, so real glassmorphism is
not achievable. The expanded image is instead rendered in Dart — gradient ground,
soft blooms, translucent panels with a bright top edge — which gives full control
at the cost of only appearing when expanded.

Verified on device: `id=250001`, `channel=ff_prayer_banner`,
`flags=ONGOING|ONLY_ALERT_ONCE|SILENT`, `vis=PUBLIC`,
`template=BigPictureStyle`, `color=0xff7e8ce0` (the Fajr blue — correct, it was
past Isha). Expanded art renders correctly with Arabic.

Preview images for every theme and mode: `mobile/build/banner_preview/`
(regenerate with `flutter test test/prayer_banner_art_preview_test.dart`).

### 3.3 Notes paste structuring (item 8) — `9097c3b`

`Milk / Eggs / Bread` on separate lines now becomes three checkboxes. Prose is
protected: a run becomes a checklist only when the lines look like items — at
least two, each ≤90 chars, and most not ending in sentence punctuation. Tables
come only from genuinely delimited data; `Day 1: Tokyo` becomes a checklist, with
one-tap conversion to a table. 32 tests.

### 3.4 AI provider (item 9) — `033eddf`

Gemini by default (`gemini-2.5-flash`), plus Claude, OpenAI and any
OpenAI-compatible endpoint (OpenRouter, Groq, local Ollama). The key is the
user's own and stored **on the device**, not in Supabase — an API key is personal
and billed to one person. Model output is parsed into a fixed block shape and
anything unrecognised is dropped; model text is never treated as instructions.

### 3.5 Recurring owner + scope (items 10, 11) — `965a66c`

`post_due_recurring()` inserted with `auth.uid()` — whoever opened the app that
day — and `recurring_charges` had no owner column at all. Added `owner_user_id`,
set on creation, used by the posting function. **Migration still unapplied.**

Family chip removed from the home strip; scope defaults to the signed-in member,
with a `_scopeChosen` flag so a later refresh does not overwrite a deliberate
switch. Household totals remain on the Family tab and the "View finances for"
sheet. Verified on device.

### 3.6 CSV import (item 12) — `cbddc4c`

Two compounding faults. The real one: `_matchColumn` used a substring test, and
**`"description"` contains `"cr"`** — so on any CSV with a Description column the
credit column bound to the description, the debit/credit branch ran against a
text column, and direction inference was skipped entirely. Secondary: inference
only read a `type` column, so a row categorised `Salary` imported as a spend.
Also `_parsePositional` had `isIncome: amount > 0 && false`, which is never true.

16 tests. **Fixed against the described symptoms, not against your actual file** —
the CSV was never shared. Re-import to confirm.

---

## 4. Bugs introduced during this work, and what they teach

All three were release-only and invisible to the test suite. Worth reading
before touching the Android build.

### 4.1 v1.9.0 crashed on launch for every user

ML Kit installs a `ContentProvider` that runs **before the Flutter engine**, and
discovers components reflectively. R8 stripped the registrars' no-arg
constructors, the provider threw, and the process died. The dependency had been
added **ahead of the bill-scanning feature that needed it**, so it carried all
the risk and delivered nothing. Removed in `d2a362b`; v1.9.1 is the fix.

### 4.2 The boot receiver crashed on every app update

`flutter_local_notifications` reads scheduled notifications back with Gson via a
generic `TypeToken`. R8 erases generic signatures, so that read threw
`Missing type parameter` inside `ScheduledNotificationBootReceiver`, which fires
on `MY_PACKAGE_REPLACED`. `proguard-rules.pro` had been deleted along with ML
Kit, leaving no keep rules. **This is present in the published v1.9.1.** Fixed in
`2f3db9a` with `-keepattributes Signature`.

### 4.3 Fixing the notification icon disabled all notifications

`@mipmap/ic_launcher` as a small icon renders as a silhouette — on the emulator,
the Flutter logo. Replacing it with a vector was right, but the drawable is
referenced only by the runtime string `'@drawable/ic_notification'`, so Flutter's
release resource shrinking stripped it. `plugin.initialize()` threw
`PlatformException(invalid_icon)`, `AppNotifications` never became ready, and
**every** notification was silently skipped. Fixed with `res/raw/keep.xml`.

### The rule all three produce

**A green `flutter build apk` says nothing about whether the app runs.** R8 does
not run on debug builds, and the test suite never exercises the Android layer.
Before publishing:

```bash
adb install -r mobile/build/app/outputs/flutter-apk/app-standard-release.apk
adb logcat -c && adb shell am start -n com.familyfinance.family_finance/.MainActivity
sleep 60   # the app takes ~30s to reach first frame, see §5
adb logcat -d | grep -E "FATAL EXCEPTION|FF-ERROR"
adb shell pidof com.familyfinance.family_finance
```

A live pid, no `FATAL EXCEPTION` and no `FF-ERROR` is the minimum bar. Reinstall
over an existing install too, so `MY_PACKAGE_REPLACED` fires.

---

## 5. Known issues not yet addressed

- **~30 second cold start.** `main.dart` blocks on `await SupabaseService.ready`
  before `runApp()`, so nothing renders until Supabase initialises or times out
  (capped at 10s, but slower in practice). Measured on the emulator: v1.9.1
  32.5s, v1.8.3 34.6s — so it is **pre-existing, not a regression**, and probably
  far quicker on a real device. The fix is to render the UI first and let the
  auth screen await readiness.
- **APK is committed to git** (~58 MB per release, permanently in history).
  GitHub warns on every push. Git LFS or GitHub Releases would fix it; migrating
  later means rewriting history.
- **`ReminderService` is dead code** — defined, never called. Wire it up or
  delete it.
- **Three unused private widgets** in `notes_v3.dart` (`_folderChip`,
  `_LiveBanner`, `_FolderGrid`) that the analyzer warns about.
- `home_v3.dart` still has `if (s.isFamily && ...)` around the "Who spent" block,
  which is now rarely true since scope defaults to the member.

---

## 6. Environment and constraints

- **The app is sideloaded, not on Play.** `AndroidManifest.xml` deliberately
  strips permissions with `tools:node="remove"`, and the notification listener
  lives only in the `detect` flavour because Play Protect refuses to install an
  APK declaring `BIND_NOTIFICATION_LISTENER_SERVICE` from a browser. Read the
  comments in `android/app/build.gradle.kts` before touching either.
- **Lightweight is an explicit requirement**: no background services, no
  per-frame animation, disabled features build nothing and register no timers.
- **Device-local on purpose**: prayer config, AI keys, quick-add queue.
  `user_preferences` is family-scoped, so personal settings there would sync onto
  every member's phone.
- **Design system**: Nocturne (`lib/theme/nocturne.dart`) + Phosphor icons via
  `lib/v3/phosphor_icons.dart`. That icon file is generated — codepoints must come
  from `@phosphor-icons/web@2.1.1` and be verified present in the bundled font,
  not guessed.
- **Releases** go through `scripts/update_release.py`, which rewrites
  `UpdateService.currentVersion` from pubspec, builds, copies the APK, updates the
  README, commits, tags and pushes. Editing `pubspec.yaml` by hand bypasses that
  and leaves the app reporting the wrong version — that happened once already.
  Note the script does `git push origin main --force`.
- **Test accounts**: family "Cuddle", invite code `HKPJ9NAF`, three members
  (`asifmuhammed1998@gmail.com` is owner). A second account is already signed in
  on the emulator, which is what Phase 2 multi-user testing needs.
- **Supabase CLI** is installed and the project is linked. `supabase db query
  --linked "<sql>"` works for read-only checks.

---

## 7. Prompt for the next agent

Copy from here down.

---

You are taking over **Family Spend Tracker**, a Flutter + Supabase family finance
app at `D:\Repos\family_finance`, on branch `main` at commit `2f3db9a`.

**Read `docs/STATUS_AND_HANDOFF.md` first, then
`~/.claude/plans/swirling-skipping-puffin.md`** for the detailed designs of the
remaining phases. Do not re-derive what they record.

Start here, in order:

1. **Apply the pending Supabase migrations** (§2.1) and run the verification
   query. The recurring-salary fix is half-live without them. The CLI is
   installed and the project is already linked.
2. **Build the recurring owner picker** (§2.2). The migration's backfill
   deliberately skipped multi-member families, so the user cannot clear the bug
   from the UI yet. This is the smallest change with the most user-visible value.
3. **Notes live editing** (§2.3) — the user's loudest complaint. Block-level
   sync, autosave, undo coalescing, tappable presence, conflict surfacing. Read
   the four traps in §2.3 before writing code; two of them silently destroy user
   data.
4. **Direct messages** (§2.4), then **the web build** (§2.5), which depends on
   chat existing.

Non-negotiables:

- **Install and launch the release APK before claiming anything works.** Three
  separate release-only failures shipped during the previous session because a
  green build was treated as verification (§4). R8 does not run on debug builds.
- The app is **sideloaded** — do not add permissions or move the notification
  listener out of the `detect` flavour without reading the manifest comments.
- Honour the **lightweight constraint**: no background services, no per-frame
  animation, disabled features build nothing.
- Run `flutter test` before and after; **198 pass** at this commit. Add tests for
  behaviour you change — every bug fixed in the previous session was caught by
  first writing a test that reproduced the reported symptom.
- Use `scripts/update_release.py` for releases rather than editing `pubspec.yaml`
  by hand.

Be straight about what you cannot verify. There is no physical Samsung device, so
Now Bar placement cannot be confirmed; the CSV that triggered the import bug was
never shared, so that fix is against described symptoms only; and a prayer alert
actually firing at a prayer time has not been observed.
