# 9. Offline safety net and faithful set data

Date: 2026-08-04

## Status

Accepted

## Context

A pre-release review surfaced several ways the app could lose or corrupt the
user's training log — the one thing it exists to protect:

1. **Lost workouts.** The finished workout lived only in memory. Training with
   the phone in a locker (the normal gym case) meant `POST /v1/workouts` failed
   with a transport error and the only recourse was retrying *right then*; leaving
   the summary discarded an hour of training.
2. **Fabricated weights.** `SetView` defaulted to `20.0 kg` when a routine set had
   `weight_kg == null` (normal for pull-ups, dips, push-ups) and always logged it,
   writing fake load into the user's history.
3. **Fabricated reps.** Distance-based sets (Running, Farmers Walk — `distance_meters`
   set, no reps) fell through to the rep/weight screen, logging invented reps and
   dropping the distance entirely.
4. **Display ≠ logged.** Weight was rendered `%.1f` while the raw float was logged
   (22.25 shown as 22.3), and `2.5 kg` steps were forced on lb-unit users.
5. **Public by default.** `is_private` was hardcoded `false`, publishing every
   workout to the user's Hevy feed regardless of their habits.

## Decision

- **Persist before sending.** `SummaryView.onShow` stores `buildPayload()` in
  `Application.Storage` before the first attempt; the entry is removed only on
  HTTP 200/201, matched by `start_time` so the right workout is cleared. On the
  next launch, `PendingView` offers *Send now* / *Discard* (discard needs a
  second tap — it is unrecoverable). Demo sessions are never persisted.
- **The pending store is a queue**, not a single slot: finishing a second workout
  while the first is still unsent must not overwrite it (cap: `MAX_PENDING`).
- **No dead end when abandoning.** Backing out of the exercise list with logged
  sets goes to the summary ("finish early") instead of discarding: the sets are
  persisted and can be saved right away. `AppBase.onStop` persists the live
  session too, so killing the app mid-workout keeps the data. With zero logged
  sets the recording is discarded and the app just leaves.
- **Never invent data.** A null weight stays null unless the user touches the
  stepper (`mHasWeight` / `mTouchedW`); the box shows "–". Distance sets route to
  the timer screen and carry `distance_meters` through `logCurrent`/`buildPayload`.
- **Show what gets logged.** Weight is quantized on entry (0.25 kg / 0.5 lb) and
  rendered at the same precision; lb-unit devices display and step in lbs and
  convert back to kg for the API. A weight the user never touched is logged
  **verbatim from the routine** — a kg→lb→kg round trip would otherwise rewrite
  20.0 kg as 19.96 kg on statute devices.
- **Private by default.** `is_private` comes from the `privateWorkouts` setting,
  default `true`.

## Consequences

- A failed save is recoverable; the app can no longer silently lose a session.
- Logged sets match both the plan and what the watch displayed.
- One extra screen (`PendingView`) and a small amount of Storage per unsent
  workout; the pending payload is dropped if the user chooses *Discard*.
- Users who want their workouts in the Hevy feed must enable the setting.
