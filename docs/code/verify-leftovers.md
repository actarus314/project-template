# `checks/verify-leftovers.sh` — why it is written this way

> Convention: [`README.md`](README.md).

**Two halves under one name, and the name is what they share**: an agent's work leaves things behind, and nothing reads them. A branch that never had an upstream is one; a worktree directory git never registered is the other. They are kept in one check because the question is identical — *does this exist anywhere but here, and is it worth keeping?* — and splitting them would have produced two guards answering it in two ways.

## The gap it fills, and why neither neighbour could have seen it

Two mechanisms already read branches, and a branch that **never had an upstream** is outside both by construction: `prune-dead-branches.sh` starts from `git branch -vv | grep ': gone]'`, and `verify-housekeeping.sh` looks at `git branch --show-current` alone. Neither is wrong — an orphan branch satisfies no condition the first knows, and the second is answering a different question.

🔴 **The failure was SILENT, and it was the absence from the SUMMARY that let it run.** Nine such branches sat in one repository for two months. Their own tracking doc came to hold them as work at risk of being lost, and a chantier was opened on that premise; the server held every line of their code. What made the wrong belief durable is that no verdict ever named the category — the pass reported on the branches whose upstream was gone, and read as covering the branches.

⚠️ **The signal was also prisoner of an unrelated threshold.** `verify-housekeeping.sh` mentions a never-pushed branch only after its own trigger fires — six commits of drift in the tracking doc. A repository whose tracking doc is up to date never hears it. That is why this lives in its own check rather than as one more line over there: the two subjects share no trigger.

## The three instruments, and what each one actually proves

| The instrument | Proves | Costs / misses |
|---|---|---|
| `git merge-base --is-ancestor <branch> <remote ref>` | the commits **are** on the server, without reservation | nothing — this is the cheap, exact half |
| `git cherry <default> <branch>` *(patch-id)* | the same patches landed under other SHAs — it sees through a **squash** | blind to a rebase that resolved a conflict, since the patch changed |
| every blob of the branch ∈ `git rev-list --objects <ref>` | the **content** exists in the server's history, whatever the graph did | answers on files, not commits — and it is too heavy to run at every commit |

**Only the first two are wired.** The third settled the real case by hand and stays a gesture of investigation: it is what to reach for when the first two disagree with the evidence.

🔴 **`git ls-tree` is NOT the third instrument, and mistaking one for the other produced a false positive of five files.** `ls-tree` lists the blobs of a **state** — the tip of a branch; `rev-list --objects` walks the **history**. Files living only in an intermediate commit read as unique under the first. What refuted it was `git fsck --unreachable` printing nothing: objects claimed missing cannot all be reachable.

**Order matters, and the error is always on the safe side**: a branch that fails both wired tests is announced as *the only copy*, never deleted. A rebase this cannot see costs a warning, never a loss.

## Why the branch being worked on is exempt

Working on a branch not pushed yet **is** ordinary work — it is most of a day, and judging it would make this speak at every commit. Why an exemption is owed at all, and why it is named rather than silent, is worked through in [`verify-stage-closure.md`](verify-stage-closure.md) on its own.

**What is specific here is WHICH case is legitimate, and it is a narrow one**: the branch under the cursor, and no other. Every remaining orphan is one nobody is working on — which is exactly the condition under which work gets forgotten.

## Why the age is published and never judged

A dormant orphan branch is the case that actually loses work, so *"inactive for N days"* is tempting as a trigger. **There is no measurement here that sets N**, and a threshold picked because it sounds reasonable is one this project refuses — it would be calibrated on the corpus it is meant to correct — the rule belongs to `METHODE.md`, and the 750-character changelog cap is what made the point. So reachability, which is **binary and provable**, is the only verdict; the age travels beside it as a fact the reader weighs.

## What it costs, and the shape that keeps it cheap

Measured at **0.04 s**: `is-ancestor` against every remote-tracking ref is nearly free, and `git cherry` runs against **one** reference only — the default branch as the server names it (`refs/remotes/origin/HEAD`, then `origin/main`, then `origin/master`). Running patch-id against every remote ref instead is what would make this quadratic on a repository holding many.

## The third route in `prune-dead-branches.sh`, and the bug the bench found

The same test arms the deletion: never pushed **and** content reachable → the branch goes, on the proof rather than on the maintainer's memory of having checked.

🔴 **Written first without `|| true` on the substitution that searches the remote refs, the script died mid-list under `set -e`** — the loop's last command fails whenever no remote ref contains the branch, which is the ordinary case for the branch it had just decided to KEEP. It exited non-zero, printed nothing, and examined none of the branches after it. A bench with three branches — one an ancestor, one squashed, one unique — caught it; the check alone would not have, since the two run different code over the same question.

⚠️ **The same motif bit a SECOND time, in the check, and only under CI** — worth stating because the two forms look nothing alike: `grep -c` exits 1 on zero lines, so `x="$(… | grep -c .)"` kills the script. **Zero local branches is the CI's ordinary state**: `actions/checkout` leaves a detached HEAD on a `pull_request`. Locally there is always a branch, so it passed here and failed there — caught by `check.sh` comparing the declared `# blocking: no` to the real exit code, which is the one reading a declaration cannot do. **Every substitution whose last command may legitimately fail carries `|| true`, and the reason is written where it sits.**

## The second half: the directory, and where the NATIVE tools stop

**Most of this is already handled, and that is why the remainder is narrow.** The harness removes a worktree it created if nothing changed in it; `git worktree prune` drops the entries whose directory is gone. What neither touches is a directory that was **modified** and that git **never registered** — absent from `worktree list`, therefore invisible to `prune`, and left on disk indefinitely.

Measured on this machine: two repositories held such directories — ten in one, two in the other — **1.5 GB together**, the oldest six weeks old, and in both cases every source file inside was already in the server's history. The bulk is `node_modules`, which a backup re-synchronises for as long as it sits there.

⚠️ **`du` runs on the STRAYS only.** It walks the tree, and these directories hold dependency trees; a repository with nothing left behind pays nothing for this half. That is also why the size is reported and not judged — the same reason the age is.

🔴 **`git worktree list`'s first line is the repository ITSELF.** Counting registered worktrees against it printed *"1 registered"* where no live worktree existed at all — a verdict that reads as reassuring while describing nothing. The count is now taken against the directories examined.

## Why it is advisory

Which orphan branch to submit, push or drop is a judgement only the maintainer makes, and the general reason that kind of verdict never blocks is set out in [`verify-stage-closure.md`](verify-stage-closure.md).

⚠️ **What blocking would cost HERE is its own thing**: the branch it complains about is, by construction, **not** the one being committed to. A gate refusing this commit over the state of some other branch stops work that has no relation to the fault — and the only way out is the bypass. *(What `blocking:` claims, and why it is about the exit code: [`README.md`](README.md).)*
