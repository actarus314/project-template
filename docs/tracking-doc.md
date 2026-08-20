# The tracking doc — the FORM its rows and folders take

> Reference. This document owns **one subject: the shape of the default tracking doc**, `SUIVI.md`, and of the stage folders beside it.
> **The ROLE is [`METHODE.md`](METHODE.md)'s** — what a tracking doc contains, what it never contains, and why one system is chosen rather than three. Nothing of that is repeated here.
> `verify-workspace.sh` arms every rule below. Its thresholds and its perimeter are [`repo-controls.md`](repo-controls.md)'s, the measurements behind them [`docs/code/verify-workspace.md`](code/verify-workspace.md)'s.

**Why these rules exist at all**: a tracking doc is reread cold, months later, by whoever picks the work back up. A row that lies about where its detail lives, or a number that two stages share, costs exactly what the document was written to save.

## What is armed, and where it applies

🔴 **These rules describe ONE shape — the `SUIVI.md` this template ships.** A project driven by another system has no file of that name, and the check says nothing there: it is not a fault, it is a different tool. The form is owned where the file is provided, and nowhere else.

### The open-work section

- A **closed item** does not sit in the open-work section: it belongs to the state section, or to an archive.
- A **chantier number is never reused** — neither by two open stages, nor by one that an archive already closed. A pointer written today has to keep resolving tomorrow.

### A row, and the task it holds

- A row carries **four columns**.
- A task is **numbered**, and **opens on an infinitive** — what is to be done, not what it is about.
- It holds **no link** and **no count**: both age faster than the row around them, and a stale figure reads as current.
- It fits in **72 characters**. What does not fit belongs to the stage's detail file.
- A chantier row **points at its detail file**, or carries the dash that says there is none. Pointing nowhere is the one form that cannot be told apart from an oversight.

### The stage folders

- A stage folder **carries its chantier number as a prefix**, three digits then a separator, so the tracking doc and the folder answer to the same name.
- A stage folder is **never empty** — an empty one reads as something that disappeared from the tracking doc.
- A stage folder **holds a `DETAILS.md`**: its tasks otherwise have nowhere to be reasoned about.
- A `DETAILS.md` **never reasons a task the tracking doc does not carry**. That is a second backlog, and the second one is always the stale one that gets read first.
