# CLAUDE.md

Guidance for working in this repo. Read this before changing code.

## What this is

**Workouts for Hevy** — a Garmin **Connect IQ** (Monkey C) watch-app that runs a
[Hevy](https://hevy.com) routine on a **Venu 2** (round, 416×416, AMOLED, touch):
pick a routine → exercise list with per-exercise set progress → guided
set / rest / duration flow with tappable REPS/KG steppers → log the workout back
to Hevy (`POST /v1/workouts`). It also records a Garmin strength activity so
heart rate / calories reach Garmin Connect.

The "why" behind the big decisions is in [`docs/adr/`](docs/adr/README.md) — read
those before reversing anything.

## Build & run

```bash
./build.sh                       # builds bin/HevyWorkout.prg for venu2
```

`build.sh` wraps `monkeyc` and expects the Connect IQ SDK at
`~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-<ver>` with a `developer_key.der` in
the project root.

Run in the simulator:

```bash
connectiq &                              # launch the CIQ simulator
monkeydo bin/HevyWorkout.prg venu2       # load the app into it
```

Deploy to a real watch: copy `bin/HevyWorkout.prg` to `GARMIN/APPS/` (USB / Android
File Transfer).

### Toolchain gotchas (macOS / Apple Silicon)

- The macOS SDK ships as a **`.dmg`**; the community `connect-iq-sdk-manager` CLI
  can't fetch it (errors `can't find filename for OS "darwin"`). Download the dmg
  directly from `developer.garmin.com/downloads/connect-iq/sdks/`, mount, copy.
- The compiler/sim read devices & fonts from
  `~/Library/Application Support/Garmin/ConnectIQ/{Devices,Sdks,Fonts}` — symlink
  these to `~/.Garmin/ConnectIQ/...`, or the sim crashes with
  `Invalid Font Specified`.
- `developer_key.{pem,der}` is a **private signing key** — never commit (see
  `.gitignore`). Generate with `openssl genrsa 4096` → pkcs8 DER (no login).
- SDK download itself needs a one-time `connect-iq-sdk-manager login`.

## Architecture

Entry: `HevyWorkoutApp.getInitialView()` → `SetupView` if no API key →
`PendingView` if an unsent workout is stored → else `RoutineListView`.

Navigation is a small state machine. Views don't push each other directly; the
`Flow` module + `WatchUi.switchToView` drive the guided sequence. The routine
`CardMenu` is the stack base — the exercise list is the only `pushView`, so
`popView` from the summary returns to it.

```
HevyWorkoutApp.mc   AppBase; holds the Recorder; onStop() saves/discards it;
                    onSettingsChanged() picks up a phone-entered key
HevyApi.mc          Hevy REST (paged getRoutines, postWorkout), key storage +
                    normalization, errorText(code), pending-workout storage
WorkoutSession.mc   state: exIndex/setIndex, per-set logged values, buildPayload()
Flow.mc             showCurrentSet() / afterSetConfirmed() — the exercise↔rest loop
Recorder.mc         Garmin ActivityRecording (STRENGTH_TRAINING) → Garmin Connect
Vitals.mc           live HR / calories via Activity.getActivityInfo()
Theme.mc            colors + drawing helpers (heart, chevron, check, header, fonts)
SetupView.mc        first-run API-key entry (chunked, validated, with preview)
PendingView.mc      resend/discard a workout that failed to reach Hevy
RoutineListView.mc  loads ALL routine pages; loading/error/empty states  (screen 1a)
ExerciseListView.mc CardMenu of exercises with progress + check marks    (screen 1b)
CardMenu.mc         dark CustomMenu / CustomMenuItem used by both lists
SetView.mc          two pages: big reps/weight steppers; swipe up for
                    the Next/Back pills (kg or lbs)                      (screen 2)
RestView.mc         rest countdown with +15 s / Skip pills                (rest)
DurationSetView.mc  two pages: timer for duration AND distance sets;
                    swipe up for the Next/Back pills                     (screen 3)
SummaryView.mc      end screen; POST to Hevy; saves the Garmin recording
SampleData.mc       bundled "Chest day" demo routine (fake template ids)
```

## Conventions & hard-won rules

- **Touch input:** custom screens use `WatchUi.InputDelegate`, NOT
  `BehaviorDelegate` — on Venu a tap arrives as `onSelect` (no coords) under a
  BehaviorDelegate. Implement `onTap` (hit-test coords) + `onKey` (physical
  buttons), and **always `return true` from `onTap`**. See ADR-0003. Native lists
  keep `Menu2InputDelegate`.
- **Back-swipe:** every in-workout screen MUST implement `onSwipe` (SWIPE_RIGHT →
  the same exit path as `KEY_ESC`). Unhandled, the system pops the view and the
  session + recording are orphaned — losing logged sets and blocking sleep
  tracking. Applies to Set/Rest/Duration delegates.
- **Every drawn control needs a matching hit zone, and vice versa** — no
  invisible tap targets (that bit us on the setup screen's error state).
- **Never invent set data.** A null `weight_kg` stays null unless the user
  touches the stepper; an untouched weight is logged verbatim from the routine
  (no kg→lb→kg round trip); distance sets carry `distance_meters` through and go
  to the timer screen. What the screen shows is exactly what gets logged.
  ADR-0009.
- **A finished set is never only in memory.** Anything that ends a workout must
  keep the logged sets: the summary persists them (`HevyApi.savePending`, a
  queue keyed by `start_time`), backing out of the exercise list routes to the
  summary rather than dropping them, and `AppBase.onStop` persists the live
  `app.session`. Add a new exit path → add persistence.
- **Guard API data before drawing it.** Titles, `sets`, `exercises`,
  `exercise_template_id` and set `type` can all be null/missing from
  API-created routines; `getTextWidthInPixels(null)` crashes mid-workout. Use
  `WorkoutSession.currentTitle()` and the existing null-coalescing patterns.
- **Lists:** subclass `CustomMenu`/`CustomMenuItem`; the item draw hook is
  **`draw(dc)`**, not `onDraw`. Don't reuse parent field names (`mTitle`,
  `mLabel`) — they're protected; prefix subclass fields.
- **Glyphs:** hearts / play / pause / check / chevron do NOT render in device
  fonts — draw them as shapes (`Theme.drawHeart` etc.).
- **Layout:** everything is a fraction of `screenWidth/Height`, kept inside the
  round bezel. Titles use `Theme.bestFont` (auto-shrink) + `Theme.fit`
  (ellipsis). Give text real spacing — don't cram.
- **Recording lifecycle (important):** a running `ActivityRecording` **blocks
  Garmin sleep tracking**. It MUST be ended on every workout exit — done in
  `SummaryView.onShow`, `ExerciseListDelegate.onBack`, and `AppBase.onStop`. See
  ADR-0006. Don't add a workout exit path without ending the recording.
- **API key:** never enter/handle the key on the user's behalf. It's read from
  `Storage` (watch entry) then `Properties` (phone settings), both normalized.
  The watch keyboard caps length, so the key is collected in chunks and hyphens
  are auto-inserted (`HevyApi.normalizeKey`). A 401/403 must always leave a way
  out (`Change key` clears Storage → `SetupView`). See ADR-0005.
- **User-facing strings live in resources**, English base in
  `resources/strings.xml`, German in `resources-deu/strings.xml`; load with
  `WatchUi.loadResource(Rez.Strings.X)`. Never hardcode UI text — the manifest
  declares both languages.
- **Error text:** never show a raw response code. `HevyApi.errorText(code)` maps
  negative transport codes to "Phone not connected" etc.; only 401/403 may
  suggest checking the key.
- **Permissions** (`manifest.xml`): `Communications` (Hevy) and `Fit`
  (ActivityRecording) only — live HR comes from `Activity.getActivityInfo()`,
  which needs no Sensor permission. Keep the list minimal.

## Hevy data shapes

- `GET /v1/routines?page=N&pageSize=10` → `{ page, page_count, routines: [ { id,
  title, exercises: [ { title, exercise_template_id, rest_seconds,
  sets: [ { type, weight_kg, reps, duration_seconds, distance_meters } ] } ] } ] }`.
  **pageSize is capped at 10** — page until `page_count` (we cap at
  `HevyApi.MAX_PAGES`). A duration set has `duration_seconds` and null `reps`; a
  distance set has `distance_meters` and null `reps`; bodyweight sets have null
  `weight_kg`. Routines built with a rep RANGE ("8–12") carry
  `rep_range: { start, end }` with `reps: null` — use
  `WorkoutSession.plannedReps(set)` instead of reading `reps` directly, both for
  the screen-type decision and for the stepper's initial value. Exercises may
  legitimately have `sets: []` — guard before indexing.
- `POST /v1/workouts` body: `{ workout: { title, start_time, end_time,
  is_private, exercises: [ { exercise_template_id, sets: [ { type, weight_kg,
  reps, duration_seconds, distance_meters } ] } ] } }`. Hevy has **no heart-rate
  field**. `is_private` follows the `privateWorkouts` setting (default true).

## Verifying UI changes

- Build, `monkeydo` into the sim, then screenshot the sim **window** (works across
  macOS Spaces, no clicking):
  ```bash
  # find the CIQ Simulator window id, then:
  screencapture -x -o -l <windowId> shot.png
  ```
- Automated taps into the sim are flaky (timing / focus / Spaces). For a specific
  screen, temporarily point `getInitialView()` at that view (mark it `// TEMP`)
  to verify deterministically, then revert. Grep for `TEMP` before committing.
- The sim needs the app's API key set via **Settings → Trigger App Settings**, or
  use the on-watch setup screen / "Start demo".
- A TEMP entry that calls `HevyApi.saveKey(...)` / `savePending(...)` leaves state
  in the simulator's app storage — clear it with `clearKey()`/`clearPending()` (or
  the sim's *File → Reset App Data*) before the next run, or later screens will
  show stale state.
