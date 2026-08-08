# `open-pr.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## The dispatch miss this script exists to close

The miss happens on a correct, unfiltered trigger, and was observed across repositories carrying an identical valid config — so it is not a misconfiguration to fix once, it has to be checked every time. This script is what makes that mechanical rather than remembered; the discipline itself is [`AGENTS.md`](../../AGENTS.md)'s.

## Why close/reopen, and not `workflow_dispatch`

A `workflow_dispatch` run is a real run, but it does not satisfy a required `pull_request` context — a ruleset still shows the PR as unchecked after it ran.

## Why it waits before opening, not just before checking

Opening straight after `git push` is the main cause of the miss: GitHub has not registered the head commit yet, so the event has nothing to attach a run to.

## 🔴 Why the FORM is refused here too, and not on the commits alone

**Which of the title and the branch's subjects survives a merge is a repository setting** — stated once, in [`verify-commit-form.md`](verify-commit-form.md). This script exists on the title's side of it.

🔴 **Detecting that setting here is deliberately not done**: it would cost a network call before a refusal that must fire offline, and it would change no verdict, since both carriers owe the same form.

It fires **before the push**: a refusal leaving a branch pushed has already done the irreversible half.

**The four refusals are `verify-commit-form.sh`'s**, word list included. Aligning them was a deliberate style decision — the narrative title *("The closing pass deletes…")* gives way to the imperative *("Delete a dead branch…")*.

**The owed sections are read from `.github/PULL_REQUEST_TEMPLATE.md` at run time, never listed here**: a second list would drift, and a project adapting its template adapts what its bodies owe with no code to change. Only the heading's presence is read; whether the section demonstrates anything is a judgement no script reaches.
