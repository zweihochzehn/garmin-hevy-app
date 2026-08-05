# 3. Use `InputDelegate` (not `BehaviorDelegate`) for touch workout screens

Date: 2026-08-04

## Status

Accepted

## Context

The set screen needs fine-grained touch: tapping the top of a box increases a
value, the bottom decreases it, and dedicated regions are back / next. This
requires the **tap coordinates**.

The first implementation used `WatchUi.BehaviorDelegate` with both `onTap` and
`onSelect`. In testing, tapping anywhere on the box **confirmed the set** instead
of changing the value. Instrumentation showed that on the Venu 2 a screen tap is
delivered as the **`onSelect` behavior** (no coordinates) — `onTap` was never
called for the custom view. Because `onSelect` was wired to "confirm", every tap
advanced the workout. This exactly reproduced the user's "can't change
weight/reps" report.

## Decision

For the custom-drawn workout screens (set, rest, duration, summary, setup) use a
plain **`WatchUi.InputDelegate`** and implement:

- `onTap(clickEvent)` — hit-test `getCoordinates()` against the on-screen control
  rects (steppers, next, back, play).
- `onKey(keyEvent)` — map the physical buttons (`KEY_ENTER` = confirm,
  `KEY_ESC` = back).

`onTap` always returns `true` so an empty-area tap is consumed and never falls
through to a behavior. Native list screens keep using `Menu2InputDelegate`
(tap-to-select works there).

## Consequences

- Steppers and buttons work by coordinate as intended.
- We give up the automatic behavior mapping of `BehaviorDelegate`; physical
  buttons are handled explicitly via `onKey`.
- Every custom touch screen follows this one pattern, which keeps input handling
  predictable.
