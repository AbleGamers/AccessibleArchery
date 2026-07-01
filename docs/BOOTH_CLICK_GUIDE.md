# What to click — booth setup cheat sheet

One icon per line below. Nothing else on any machine needs opening.

Before the con: put a sticky note on each machine saying which one it is —
**STATION 1**, **STATION 2**, or **BACK MACHINE** — so there's no guessing
on the day.

---

## 🎯 STATION 1 machine

Double-click this **one** icon, in the `booth` folder:

> ### `start-station`

That's it. Nothing else to click on this machine.

---

## 🎯 STATION 2 machine

Double-click this **one** icon, in the `booth` folder:

> ### `start-station`

Same icon, same name as Station 1 — it's the identical file, just running on
a different machine. That's it.

---

## 🖥️ BACK MACHINE (the one with the big monitor)

This machine needs **two** icons clicked, in this order, both in the `booth`
folder:

> ### 1st: `start-server`
> ### 2nd: `start-display`

Both, every time. If you only click one, the leaderboard won't work.

---

## How to tell which file is which

Every machine's `booth` folder has six icons in it. Only click the ones
listed above for that machine — ignore the rest. The full list, so you can
double check you're not clicking the wrong one:

| Icon name | Click this on... |
|---|---|
| `start-station` | Station 1, Station 2 |
| `start-server` | Back machine only |
| `start-display` | Back machine only |

On **Windows** machines, the icon's name ends in `.bat`.
On **Mac** machines, the icon's name ends in `.command`.
Either way, the name before the dot is what matters — match it to the table
above.

---

## What "working" looks like

- **Stations**: the archery game opens full-screen. Ready to play.
- **Back machine, after both clicks**: one window says "server listening" in
  small text (that's `start-server` — can be minimized/ignored once it's
  up); the other becomes the big full-screen leaderboard (that's
  `start-display`).

If anything looks different from this, see `docs/BOOTH_RUNBOOK.md`.
