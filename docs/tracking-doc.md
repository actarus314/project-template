# The tracking doc — the FORM its rows and folders take

> Reference. This document owns **one subject: the shape of the default tracking doc**, `SUIVI.md`, and of the stage folders beside it.
> **The ROLE is [`METHODE.md`](METHODE.md)'s** — what a tracking doc contains, what it never contains, and why one system is chosen rather than three. Nothing of that is repeated here.
> `verify-workspace.sh` arms what is binary here, and **a rule no guard reads says so where it stands**. Its thresholds and its perimeter are [`repo-controls.md`](repo-controls.md)'s, the measurements behind them [`docs/code/verify-workspace.md`](code/verify-workspace.md)'s.

**Why these rules exist at all**: a tracking doc is reread cold, months later, by whoever picks the work back up. A row that lies about where its detail lives, or a number that two stages share, costs exactly what the document was written to save.

## The rules, and where they apply

🔴 **These rules describe ONE shape — the `SUIVI.md` this template ships.** A project driven by another system has no file of that name, and the check says nothing there: it is not a fault, it is a different tool. The form is owned where the file is provided, and nowhere else.

### The open-work section

- A **closed item** does not sit in the open-work section: it belongs to the state section, or to an archive.
- A **chantier number is never reused** — neither by two open stages, nor by one that an archive already closed. A pointer written today has to keep resolving tomorrow.

### A row, and the task it holds

- A row carries **four columns**.
- A task **opens on the mark that says done or still to do**, so a row's state is read without reading its tasks. What identifies a task is its number, which is the only way a missing mark can be refused.
- **Only a cell's first segment may be a label.** Past it, a segment carrying neither mark nor number is a task that lost its form, never a note.
- A task is **numbered**, and **opens on an infinitive** — what is to be done, not what it is about.
- It holds **no link** and **no count**: both age faster than the row around them, and a stale figure reads as current.
- It fits in **72 characters**. What does not fit belongs to the stage's detail file.
- A chantier row **points at its detail file**, or carries the dash that says there is none. Pointing nowhere is the one form that cannot be told apart from an oversight.
- That detail column carries **one link, and one only** — the stage's `DETAILS.md` is the entry point, and points at its own sources from there. *(No guard.)*
- A chantier title **names without explaining, and fits on two lines** — a markdown column takes the width of its longest segment. *(No guard: where naming stops and explaining starts is a judgement.)*

### The closed-stage section

- A line there **carries its archive pointer, and nothing beyond it** — without one it states that a stage closed and gives no way to check it. *(No guard.)*

### The stage folders

- A stage folder **carries its chantier number as a prefix**, three digits then a separator, so the tracking doc and the folder answer to the same name.
- A stage folder is **never empty** — an empty one reads as something that disappeared from the tracking doc.
- A stage folder **holds a `DETAILS.md`**: its tasks otherwise have nowhere to be reasoned about.
- A `DETAILS.md` **never reasons a task the tracking doc does not carry**. That is a second backlog, and the second one is always the stale one that gets read first.
- A `DETAILS.md` **never empties**: it grows with its stage and leaves with its folder, so a finished action leaves behind more than its result. *(No guard: a legitimate shrink exists — a typo.)*
- A `DETAILS.md` **explains, it does not record**: the reason a task exists, the constraint that governs it, the pointer to the settled fact it touches. A measurement, a survey, a proof of execution goes in **a file of its own** in the same folder — which becomes the archive, where the evidence belongs. *(No guard: telling a reason from a record is a judgement.)*
- **Where a process specification sits beside the tracking doc**, it recalls the rule documents it applies and points at each one, **never copying them**. A rule document it names and the recall omits leaves a reader no way back to it. What is armed is the named DOCUMENT — recognising a rule inside a text is a judgement, and a guard does not judge.
- **A plan does not live here.** It prescribes one stage and belongs to the session running it; kept, it holds an execution state the tracking doc owns and a rationale the stage's `DETAILS.md` owns. **The tasks a plan carves out rise into the tracking doc** — the task, never its steps. What identifies a plan is the header its skill stamps, read in a file's head block, and an archive is exempt.
