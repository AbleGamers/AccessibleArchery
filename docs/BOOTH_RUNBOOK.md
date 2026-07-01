# Booth staff runbook — Accessible Archery

One page. No technical background needed. If something below doesn't match
what you're seeing, it's safe to just power-cycle the machine in question —
everything reconnects on its own.

This assumes a technical person has already done the one-time-per-machine
setup (`booth/README.md`) — each machine already has a `Godot.app`/`Godot.exe`
and the `AccessibleArchery` folder sitting together, and the launch scripts
have been test-run once already. If a machine hasn't had that done yet, this
page won't be enough — find whoever set up the booth.

**For exactly which icon to double-click on which machine, use
`docs/BOOTH_CLICK_GUIDE.md` instead of this page** — it's the one-glance
version. This page is for what to do if something looks wrong.

## Setup (once, at the start of the day)

1. Plug all three machines (2 stations + 1 back machine) into the same
   switch/router with ethernet cables. Wired is more reliable than WiFi.
2. Power on in **any order** — it doesn't matter who starts first.
3. On the back machine, double-click **both** `start-server` and
   `start-display`.
4. On each station, double-click `start-station`.

## How to confirm all three are connected

- On the **display** monitor: the header shows "Connected to <ip address>"
  under the title. If it says "Connecting…", give it a few seconds — it
  reconnects automatically.
- On a **station**: bank a test score (press **L** after a shot) and check
  it shows up on the display monitor within a second or two.
- If a score doesn't show up immediately, don't worry — see "offline" below.

## Resetting today's board

Today's leaderboard resets on its own, automatically, overnight — no action
needed between days of a multi-day con. Best-of-show scores are never reset.
There's no manual "reset now" button yet; if you need one mid-day, that's a
code change (ask whoever built this).

## Where backups land

On the back machine (the one running `start-server`), inside the game's save
folder (ask a technical staffer to find `user://` — on macOS
that's `~/Library/Application Support/Godot/app_userdata/Accessible
Archery/`, on Windows `%APPDATA%/Godot/app_userdata/Accessible Archery/`):

- `leaderboard.json` — the live board (today + best-of-show), always current.
- `leaderboard_archive/` — one file per day plus a full backup, written
  automatically at each overnight rollover.

## If a station shows "offline"

Nothing to do — it keeps working. The station still runs, still lets people
play, and still saves scores locally. Once the network comes back it
automatically sends over anything that piled up while it was offline. If it's
been offline for a long time, just check the ethernet cable / switch.

## If the display shows "Connecting…" for a long time

Check that `start-server` is actually running on the back machine (its
window/terminal should say "server listening on port 4433"). If it crashed,
just double-click `start-server` again — the display and stations will find
it automatically.

## End of day

Just leave everything running overnight if the venue allows it — the daily
rollover happens on its own. If you do need to power off, any order is fine;
everything reconnects the next time it's powered on.
