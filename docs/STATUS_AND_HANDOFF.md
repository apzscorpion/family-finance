# Family Spend Tracker — status and handoff

Branch: `main` · Version `1.9.3+25`
Tests: **205 passing** (`cd mobile && flutter test`)
Published: v1.9.3 on GitHub, tagged `v1.9.3`

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
| 10 | Recurring salary posts to family, should be personal | **Done** — DB migration applied & verified + owner picker in UI (`recurring_sheet_v3.dart`) |
| 11 | Remove the "Family" option at the top | **Done, verified on device** |
| 12 | CSV import files salary/loan as expenses | **Fixed** — 16 tests. Not verified against your actual file |
| 13 | Prayer notification banner + customisation | **Done, verified on device** |
| 14 | Notes live editing, undo/redo, follow-user, conflicts | **Done** — block-level sync, `save_note_v2` RPC, coalesced undo + remote rebase, tappable presence |
| 15 | Direct messages between members | **Done** — `direct_messages` table + RLS + Realtime, `ChatController`, `ChatListV3` & `ChatThreadV3`, unread badge |
| 16 | Web version (expenses read-only, notes + chat editable) | **Done** — `lib/main_web.dart` + `lib/web/web_app.dart`, `flutter build web --target lib/main_web.dart` verified (including Wasm dry-run) |

---

## 2. What was pending and is now completed

### 2.1 Database migrations — APPLIED, verified

Re-checked against the live database on 2026-10-08:

1. `recurring_charges`: `auto_post`, `last_posted`, `owner_user_id`, `type` all present; `post_due_recurring()` references `owner_user_id`.
2. Applied `supabase/migrations/20261008030000_live_notes_and_direct_messages.sql` to the linked Supabase database:
   - `notes.version integer not null default 1`
   - `public.save_note_v2(...)` conditional versioned save RPC (`saved`, `version`, `row`)
   - `public.direct_messages` table with indexes, RLS policies (`dm_select`, `dm_insert`, `dm_update_read`), `replica identity full`, and `supabase_realtime` publication.

Re-verify with:

```bash
npx supabase db query --linked "select column_name from information_schema.columns where table_name='notes' and column_name='version'; select to_regclass('public.direct_messages'); select proname from pg_proc where proname='save_note_v2';"
```

### 2.2 Recurring owner picker — DONE

- `mobile/lib/v3/sheets/recurring_sheet_v3.dart` includes the "For" / "Credited to" member chip selector (`_ownerUserId`), defaulting to `s.myId`, passing `ownerUserId` to both `addRecurring` and `updateRecurring` (`owner_user_id` patch), and displaying the owner badge on each recurring row when multiple members exist.
- Verified with widget test in `test/v190_handoff_features_test.dart`.

### 2.3 Notes live editing — DONE

Implemented per `~/.claude/plans/swirling-skipping-puffin.md` §Phase 2:

- **Conditional versioned save**: `V3Repository.saveNoteConditional` calls `save_note_v2` with `p_expected_version`. On version conflict (`saved == false`), `NoteEditorV3` merges remote blocks (preserving the locally focused block) and retries once against the new version.
- **Realtime `block_delta` broadcast + `postgres_changes`**: `NotesPresenceService` keys presence by `$userId:$sessionId` (so multi-device sessions don't collide), tracks focused `blockId`, broadcasts throttled (180ms) `block_delta` events on `notes:$familyId`, and subscribes to `postgres_changes` (`INSERT`/`UPDATE`/`DELETE`) on `public.notes`.
- **All four traps guarded**:
  1. Empty blocks are **not** pruned during background autosave (`_save(pruneEmpty: false)`); pruning happens only on final close (`_flushPendingSave(pruneEmpty: true)`).
  2. Self-echo suppression in `_onRemoteNoteRow`: ignores rows where `row.updatedBy == s.myId && row.version <= _localVersion`.
  3. `NoteBlock.deepCopy()` clones `items`, `head`, and `rows` deeply so undo snapshots never alias live mutable lists.
  4. `_rebaseHistoryForBlock(remoteBlock)` updates unfocused blocks inside `_history` and `_redo` when remote edits arrive so local Undo never reverts another member's typing.
- **Tappable presence & contested-block banner**: `LiveBanner`, `LiveDot`, and `_PresenceStrip` (filtered via `presence.viewersOf(noteId)`) jump to the collaborator's active note/block on tap. If a remote edit touches the locally focused block, an amber `"<Name> is editing this line"` banner appears above that block.

### 2.4 Direct messages — DONE

- **Data & Realtime**: `DirectMessageRow` in `v3_models.dart`, `directMessages` / `sendDirectMessage` / `markDirectMessagesRead` in `v3_repository.dart`, and `ChatController` (`chat_controller.dart`) subscribing to `postgres_changes` on `public.direct_messages` (`dm:$familyId`).
- **UI**: `ChatListV3` (`chat_list_v3.dart`) and `ChatThreadV3` (`chat_thread_v3.dart`) built in Nocturne style, accessible from the `Family` ("More") tab card, per-member row quick-chat icon, and `V3Page.chat`. Unread badge rendered on both the bottom nav `More` tab and the Family DM card.

### 2.5 Web version — DONE

- Resolved all three web compilation blockers without upgrading `flutter_local_notifications`:
  - `v3/data/notification_bridge.dart`: replaced `dart:io` `Platform.isAndroid` with `defaultTargetPlatform == TargetPlatform.android`.
  - `v3/data/data_export.dart`: conditional import (`data_export_io.dart` vs `data_export_web.dart`) using `XFile.fromData` in-memory on web.
  - `v3/data/prayer/prayer_controller.dart`: decoupled `notifications_core.dart` and `prayer_banner.dart` behind `prayer_platform_io.dart` / `prayer_platform_web.dart`, and updated `PrayerCard` to watch `PrayerController?`.
  - Removed unused `sqflite` dependency from `pubspec.yaml`.
- Added `lib/main_web.dart` and `lib/web/web_app.dart` (`WebApp`, `WebRoot`, `WebShell`) with desktop `NavigationRail` (`>= 760px`) and mobile bottom bar:
  - **Home, Activity, Insights**: read-only on web (`V3Sheets.readOnly = true`, read-only notice banner, transaction row tap opens read-only detail sheet, quick-add/CSV-import/recurring mutations hidden, CSV export still works).
  - **Notes & Chat**: full read/write with live collaboration and direct messaging.
- Verified with `flutter build web --target lib/main_web.dart` (exit 0, Wasm dry-run succeeded) and widget tests in `test/v192_live_notes_dm_web_test.dart`.

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
