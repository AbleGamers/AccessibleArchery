# Taking ownership of the AbleGamers GitHub organization

*A guide for AbleGamers staff. No programming knowledge needed — every step is
clicking through web pages. Budget about 20 minutes.*

## What you're taking over

GitHub is the website where this project's source code, downloads, and build
system live. There is an **organization** (a shared account) named
**AbleGamers** at:

> **https://github.com/AbleGamers**

It currently contains **AccessibleArchery** — the open-source,
accessibility-first archery game built for convention showcases. The org was
created by Benjamin (GitHub username **`bbaraga`**) specifically so it could be
handed to you. Once the steps below are done, AbleGamers fully owns and
controls everything, and no outside account has any special access.

Nothing here costs money. Everything runs on GitHub's free plan, including the
automated system that builds and tests the game.

## Step 1 — Create a GitHub account (per person)

1. Go to **https://github.com/signup**
2. Use a work email address (e.g. `yourname@ablegamers.org`)
3. Pick a username, verify the email
4. **Turn on two-factor authentication** (Settings → Password and
   authentication → Two-factor authentication). GitHub requires this for
   organization owners, and it protects the org if a password leaks.

At least **two** people at AbleGamers should do this, so no single lost
account can lock the org.

## Step 2 — Tell Benjamin your usernames

Send Benjamin the GitHub usernames created in Step 1. He will go to
*Organization Settings → People → Invite member* and invite each of you with
the **Owner** role.

You'll each get an invitation email — click **Accept**.

## Step 3 — Verify you have control

While signed in, visit https://github.com/AbleGamers — you should see a
**Settings** tab for the organization. If you can see org Settings, you are an
Owner. Done — you have full control.

## Step 4 — Point billing/contact at AbleGamers

In *Organization Settings → Billing and licensing* (or *General*), change the
**billing email** to an AbleGamers address. (Nothing is billed on the free
plan — this is just where GitHub sends administrative email.)

## Step 5 — Remove Benjamin's special access (when ready)

In *Organization Settings → People*: find `bbaraga` and either **Remove from
organization**, or change his role from Owner to **Member** if he's staying on
as a contributor. This step is yours to take whenever you're comfortable —
there's no rush, but after it, only AbleGamers controls the org.

## Optional but recommended — free nonprofit upgrade

GitHub gives verified nonprofits the paid "Team" plan for free:
**https://github.com/nonprofits** — apply with your 501(c)(3) details. Not
required for anything to work; it just unlocks extras.

---

## What's in the box (and what upkeep it needs: almost none)

| Thing | Where | What it is |
|---|---|---|
| The game's source code | github.com/AbleGamers/AccessibleArchery | Open source (MIT license) — anyone may read it; only people you allow can change it |
| **Downloads for booth PCs** | the repo's **Releases** page | The Windows booth package (game + launchers + printed guides), one zip, no login needed to download |
| Automated builds | the repo's **Actions** tab | Every code change is automatically rebuilt and test-run on a real Windows machine in the cloud, free. A green check = the booth build works |
| Booth instructions | `docs/` folder + inside the booth zip | Staff runbook, which-icon-to-click sheet, printable player guide |

**Ongoing maintenance required: none.** If nobody touches the code, the
downloads keep working and nothing expires. If someone does contribute code,
the automated system checks their work before it can break a booth build.

## Questions?

The repository's README and `docs/` folder explain the project itself. For
anything about this handover, ask Benjamin — and after the handover, GitHub's
own docs (https://docs.github.com) cover org management well.
