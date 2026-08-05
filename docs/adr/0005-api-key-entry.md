# 5. API-key entry: phone settings + on-watch chunked entry

Date: 2026-08-04

## Status

Accepted

## Context

The Hevy API needs a per-user key (format `8-4-4-4-12`, e.g.
`a123456a-1rw4-4235-9443-98444da270d8`). Connect IQ's normal mechanism is an app
**setting edited in the Garmin Connect phone app** (`settings.xml` /
`properties.xml`). But the user wanted to be able to enter the key **on the
watch** too, with a clear first-run screen.

Two device constraints surfaced:

- The watch keyboard (`WatchUi.TextPicker`) **caps input length** below the 36
  characters of a full key, and offers no hyphen.
- Typing 36 characters on a character-wheel is tedious.

## Decision

Support **both** entry paths, reading the key as: `Storage` (watch-entered) →
falls back to `Properties` (phone-entered).

On-watch entry (`SetupView`, shown at startup when no key is set):

- The key is **collected in chunks**: each keyboard round appends its
  letters/digits to a buffer, showing progress `X / 32`.
- The user types **alphanumerics only**; the app inserts the hyphens
  automatically once 32 are gathered (`HevyApi.normalizeKey`), then stores and
  proceeds.
- Input is normalized and validated (`HevyApi.normalizeKey`), for the phone value
  too, so paste artifacts (stray spaces, missing hyphens) can't cause a silent
  401. A reset option clears the buffer.

A rejected key must always be replaceable: on 401/403 the routine list offers
**Change key**, which clears the key from **both** stores (Storage *and* the
phone-settings property) and opens `SetupView(force = true)`. The force flag
suppresses the auto-forward that normally fires when a key is present —
otherwise the setup screen would bounce straight back to the error and the user
could never enter a new one.

## Consequences

- Works regardless of the keyboard length cap, and the user never types a hyphen.
- Assumes a 32-alphanumeric core — correct for current Hevy keys; would need
  revisiting if the key format changes.
- The app never handles the key on the developer's behalf — the user always
  types/pastes it themselves, on the watch or in the phone app.
