# 7. Bundled demo routine as offline fallback

Date: 2026-08-04

## Status

Accepted

## Context

The app depends on the Hevy API, which needs a Pro key and existing routines.
During development the account had zero routines, and the developer must never
handle the user's key. We still needed a way to exercise the full UI flow in the
simulator and to give a new user something to try before configuring anything.

## Decision

Ship a bundled **"Chest day" demo routine** (`SampleData`) mirroring the Hevy
Apple-Watch screenshot (barbell press with reps/weight sets + a plank with
duration sets). It is reachable via **"Start demo"** on the setup screen and from
the routine-list error/empty states.

A demo session is explicitly marked (`routine id == "demo"` →
`WorkoutSession.isDemo()`), and `SummaryView` refuses to post it **even when a
valid API key is configured** — the summary shows a disabled "Demo only" button
instead of a save action that could only fail. Demo payloads are never persisted
as a pending workout. The template ids are deliberately fake (`DEMO000x`).

## Consequences

- The whole guided flow — routine list, exercise progress, set/rest/duration
  screens, summary — is demonstrable and testable with no key and no network.
- A demo workout can never reach the user's real Hevy history, and the demo path
  can never dead-end in a retry loop that cannot succeed.
- Keeps a small amount of sample data in the app bundle.
