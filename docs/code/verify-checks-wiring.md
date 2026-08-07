# `checks/verify-checks-wiring.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## The checks are declared, and the DOOR that runs them is where it belongs

🔴 The failure this exists for is silent in every direction. A check nobody calls passes no gate, and reads exactly like a check that found nothing. That has happened here more than once.

What it compares has changed with the door itself. There used to be three hand-written lists naming the checks one by one — the CI steps, the files `init-project.sh` copied, the table — and keeping three lists agreeing was the whole job. There is now ONE line, `check.sh --house`, behind which everything under `checks/` runs. So the question is no longer "is each check in each list" but "is the door there, in every workflow that gates a project".

It travels, like every other check, and it works on both sides of that trip:

· here, it sees the control table, the shipped workflow templates and the generator;
· in a generated project, none of those exist — but its `ci.yml` does, and the door must be in it.

Each part states whether it had anything to look at. A part with no subject says so.

## The three parts, and what each one alone would miss

**The hooks declare themselves.** A hook reads its payload from STDIN: started inside the parallel lot it competes for stdin with every sibling, and hangs with no output. Which checks are hooks is written in ONE place — their own `# hook: <event>` header — so the runner DETECTS rather than lists, and this part compares the detection against the declaration. It works in a generated project too, where the table is absent: the headers are there, and so is the runner.

**The runner reads every verdict back.** The parallel lot writes each check's exit code to a file, and a check with no `reap` line has that file dropped on the floor: it runs, it is documented, it gates nothing, and every part above still says "wired". **A check can sit in the table AND behind the door AND be unread.** TWO shapes count as read, because there are two: the parallel lot is replayed through `reap`, and whatever cannot join it — `verify-travel` generates a whole project — is invoked directly in the condition of an `if`. Demanding `reap` alone accused the one check that is correctly wired.

**The `# blocking:` headers.** The control matrix owns that comparison; what it does not carry is the measurement that made it necessary — three checks disagreed with themselves and nothing noticed, two of them announcing ADVISORY in their header for a full day after being made blocking.

## Why the door is searched on CODE lines only

A workflow that merely NAMES the door in a comment gates nothing: the step does not exist, the checks ship and never run — the exact defect this whole arrangement exists to prevent.

Section 2b already filtered comments before matching, for the same reason and with the reason written down; section 3, which guards the door itself, compared against the whole file text. The asymmetry was found by asking a fresh agent what the repo required when adding a check — it read the rule correctly, and reading the code afterwards showed a commented-out door would satisfy it.
Both sections now judge code lines only.
