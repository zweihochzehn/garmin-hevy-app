# 6. End the activity recording on every workout exit

Date: 2026-08-04

## Status

Accepted

## Context

Per [ADR-0002](0002-data-destinations.md) the app runs a Garmin
`ActivityRecording` session during a workout so HR/calories reach Garmin Connect.

A running activity recording keeps the watch in "activity in progress" mode, and
**Garmin does not track sleep while an activity is recording**. In testing on the
real Venu 2, leaving the app mid-workout (swiping away without finishing) left the
recording running in the background and blocked overnight sleep tracking.

The recording therefore cannot be allowed to dangle. It must be ended (saved or
discarded) on *every* path out of a workout.

## Decision

The `Recorder` session is started when a routine is selected and is explicitly
ended on all exits:

- **Completed** → `SummaryView.onShow` saves it (the workout is done).
- **Abandoned** → `ExerciseListDelegate.onBack` ends it when the user leaves the
  exercise list: save if any set was logged, otherwise discard.
- **App exit** → `AppBase.onStop` saves it as a backstop.

`Recorder.saveAndClose` / `discard` are idempotent (no-op once the session is
closed).

## Consequences

- Normal use — finishing via the summary, or swiping back out — always ends the
  recording, so sleep tracking is not blocked.
- **Residual risk:** if the user leaves the app parked on a set/rest screen
  (without backing out) and walks away, the recording keeps running until
  `onStop` fires. The user accepted this trade-off to keep HR in Garmin Connect
  (2026-08-04). If it proves annoying, make recording opt-in (default off) or
  stop it on a timeout.
- Abandoned workouts with at least one logged set still create a (short) Garmin
  activity.
