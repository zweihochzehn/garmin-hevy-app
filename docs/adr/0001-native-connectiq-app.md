# 1. Native Connect IQ (Monkey C) app for Venu 2

Date: 2026-08-04

## Status

Accepted

## Context

Hevy ships a workout companion for the Apple Watch but nothing for Garmin. The
goal is to run a Hevy routine from the wrist on a **Garmin Venu 2**: pick a
routine, work through exercises set by set (weight/reps, or a duration timer for
holds), and log the result back to Hevy.

Options considered:

- **Native Connect IQ app (Monkey C).** Full access to the touchscreen, on-wrist
  UI, heart-rate/activity APIs, and background-free execution while the workout
  is on screen.
- **Watch face / data field.** Wrong app type — no multi-screen navigation or
  input flow.
- **Phone-side companion only.** Defeats the purpose; the point is to drive the
  workout from the watch.

The Venu 2 is round, 416×416, AMOLED, primarily touch (plus two physical
buttons).

## Decision

Build a native **Connect IQ watch-app** in **Monkey C**, targeting the Venu 2
first. Layouts are computed relative to screen size so the code can extend to
other round devices later.

## Consequences

- Requires the Connect IQ SDK toolchain and a device profile; see the toolchain
  notes in the repo/memory. The macOS SDK now ships as a `.dmg` and the CLI SDK
  manager can't fetch it, so setup is partly manual.
- The app is distributed by sideloading `bin/HevyWorkout.prg` to
  `GARMIN/APPS/` (or via the Connect IQ Store later).
- Monkey C constraints shape later decisions (no `Date.now()`/randomness in some
  contexts, device-specific UI limits, permission model).
