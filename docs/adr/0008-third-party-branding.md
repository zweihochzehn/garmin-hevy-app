# 8. Third-party branding: "Workouts for Hevy", own icon, unofficial disclaimer

Date: 2026-08-04

## Status

Accepted

## Context

The app was originally called **"Hevy Workout"**, shipped a white "H" launcher
icon on a Hevy-blue rounded square, and drew a large **"HEVY"** wordmark on the
loading screen. Together those read as an *official* Hevy product.

This is a third-party app built on Hevy's public API, with no affiliation. Before
a public Connect IQ Store release that combination is a real risk:

- Garmin's developer agreement requires the publisher to warrant rights to all
  marks used in the app and its listing.
- Store review rejects listings that look like an official app of another brand.
- Hevy could request takedown *after* launch — the worst outcome for the
  developer's reputation.

The README's "not affiliated" footer never reaches the store listing or the watch.

## Decision

Adopt the established third-party naming pattern, where the other brand is a
referent rather than the brand of the app:

- **Name:** "Workouts for Hevy" (`Rez.Strings.AppName`, used by the manifest and
  the setup screen).
- **Icon:** an original dumbbell mark instead of the H lettermark.
- **Loading screen:** shows the app's own name, not a "HEVY" wordmark.
- **Listing:** store description states "Unofficial app for Hevy — not affiliated
  with Hevy or Garmin"; the README keeps the same disclaimer.

## Consequences

- Substantially lower trademark/impersonation risk, and a listing that passes
  review on its own merits.
- Slightly less immediate recognition than the brand name would give.
- If Hevy ever objects to the referential use, the fallback is to drop "Hevy"
  from the name and describe compatibility only in the listing text.
