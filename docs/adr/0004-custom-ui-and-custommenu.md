# 4. Custom-drawn workout screens + `CustomMenu` dark lists

Date: 2026-08-04

## Status

Accepted

## Context

The target look is the Hevy Apple-Watch app: a black AMOLED background, blue
accents, big numbers, and card-style lists with per-exercise progress. Two needs
pulled in different directions:

- **Lists** (routines, exercises) want native smooth scrolling.
- **Workout screens** (set, rest, plank, summary) want pixel control for large
  numbers, tappable +/− regions, and a play button — laid out to stay inside the
  round bezel.

The stock `WatchUi.Menu2` renders in the device's default (light) theme, which
clashed with the dark workout screens.

## Decision

- **Lists:** subclass `WatchUi.CustomMenu` / `CustomMenuItem` (`CardMenu`). This
  keeps native scrolling while drawing each row ourselves — dark cards, blue
  accent bar, and a green check on completed exercises. (Note: the draw hook on
  `CustomMenuItem` is `draw(dc)`, not `onDraw`.)
- **Workout screens:** plain `View.onUpdate(dc)` custom drawing. All positions
  are fractions of screen width/height; text auto-shrinks (`Theme.bestFont`) and
  truncates (`Theme.fit`) so titles fit the round display. Glyphs that don't
  render on-device (hearts, play/pause, checks, chevrons) are **drawn as shapes**
  in `Theme`.

Colors and helpers live in one `Theme` module.

## Consequences

- Consistent dark/blue look across every screen; round-safe layouts.
- More drawing code than a layout-XML approach, but full control and no theme
  surprises.
- Field names on `CustomMenu`/`CustomMenuItem` collide with protected parent
  members (`mTitle`, `mLabel`) — subclass fields are prefixed to avoid this.
