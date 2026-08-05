# 2. Split data destinations: sets → Hevy, HR/calories → Garmin Connect

Date: 2026-08-04

## Status

Accepted

## Context

The app produces two kinds of data during a workout:

1. **Structured strength data** — per set: exercise, weight, reps, or duration.
2. **Physiological data** — heart rate, calories, elapsed time.

Neither destination accepts both:

- The **Hevy public API** (`POST /v1/workouts`) accepts exercises and sets
  (`weight_kg`, `reps`, `duration_seconds`, `rpe`, …) but has **no field for
  heart rate**.
- **Garmin Connect** receives data via a recorded FIT activity
  (`Toybox.ActivityRecording`). A `STRENGTH_TRAINING` session captures HR,
  calories and time automatically, but Connect IQ has **no supported way to
  write structured strength sets** into that FIT (confirmed as an unresolved
  Garmin forum request).

## Decision

Send each data type where it fits:

- **Sets → Hevy** via `POST /v1/workouts`, built from the values the user
  confirmed (`WorkoutSession.buildPayload`).
- **HR / calories / time → Garmin Connect** by running an `ActivityRecording`
  `STRENGTH_TRAINING` session for the duration of the workout (`Recorder`).

Live HR/calories for on-screen display come from `Activity.getActivityInfo()`
while the recording is active.

## Consequences

- The user gets a proper Hevy log **and** a Garmin Connect strength activity with
  HR — the best available from each platform.
- Requires only the `Fit` permission (for `ActivityRecording`). Live HR/calories
  come from `Toybox.Activity` / `Toybox.ActivityMonitor`, which the SDK's
  permission table does **not** list — the `Sensor` permission covers
  `Toybox.Sensor` (ANT+/sensor listeners), which this app never uses. Verified
  both ways: the compiler hard-errors on a missing permission (it did for `Fit`),
  and both the build and a runtime check in the simulator show HR rendering fine
  without `Sensor`.
- A running activity recording **blocks Garmin sleep tracking**, which forces a
  strict recording lifecycle — see [ADR-0006](0006-end-recording-on-exit.md).
- HR does not appear in Hevy (API limitation), and structured sets do not appear
  in the Garmin activity. This is accepted.
