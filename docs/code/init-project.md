# `init-project.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## Implementation notes

Initialize a Claude Code project per the organization standard.

Usage: ./init-project.sh <project> [owner/repo] [parent-folder]
[--type static|node|generic] [--pages] [--artefact] [--staging] [--no-…]

<project>          project name (folder created)
[owner/repo]      if given, configures the GitHub remote as a bare URL
[parent-folder]  default: ~/Documents/Claude

--no-lifecycle-docs  Does NOT write `SUIVI.md`.

The script does NOT create the PAT (to be done on github.com) nor does it push.

---

Under checks/, exactly where they live here — check.sh looks for them THERE, and dropping them at
the root left them shipped but never run: the path died where the file landed.

🔴 ALL of them, and that is the rule, not a convenience. Three used to be named here one by one,
and the other fifteen stayed behind for no stated reason beyond the order they were written in.
A check DETECTS whether its subject exists where it lands: present, it bites; absent, it says so
and returns 0. So the question "does this one deserve to travel?" has no addressee — the check
answers it itself, at the place, which no list written here can do.
The hooks travel too: they read an event, not a file, so they are universal by construction, and
a project that wants to wire them needs them on disk first.

---

⚠ The key is INJECTED HERE, not carried by the template: a template that hardcoded it
would point at a NONEXISTENT `develop` on a two-stage project — and Renovate without a valid
base opens NO PR at all, silently. The failure mode of a botched injection is the current
behavior (PR on main); the failure mode of the reverse is a dead bot.
The WHY of the key itself: the `description` block of templates/repo/.github/renovate.json.

---

Net 2/2 — placeholders the HUMAN must fill in, in VERSIONED files, so PUBLISHED.
These, the script CANNOT guess (`<contact>`, `<one line>`…) — it must especially not
invent them. But staying silent is worse: a published `SECURITY.md` saying "reach out to <contact>"
leaves a researcher WITHOUT any way to report a vulnerability. This is defect #3 (dead links), the
same as before. → they get LISTED, and going public requires them filled in (docs/repo-controls.md).
README deliberately EXCLUDED: it's obvious to fill in, and its HTML tags (<picture>, <p …>)
are false positives that would drown out the only message that matters — the one about `<contact>`.
LICENSE deliberately EXCLUDED too: its year and holder are substituted right above, so nothing
is left to fill — and the license text carries its own canonical URL between angle brackets,
which the pattern would report as a placeholder.

---

Lifecycle docs — default from the 1st commit (docs/METHODE.md).
A SKELETON, not just a title: an empty file doesn't get filled in, it gets ignored. The sections
below are exactly the questions someone — human or AI — asks when reopening the
project 6 months later and remembers nothing.

QUOTED heredoc ('EOF'): without the quotes, the shell interprets the backticks as a command
substitution and EMPTIES all the `paths` in the template. The project name is substituted afterward, by sed.

---

gitleaks pre-commit hook — ARMED AFTER the initial commit (docs/repo-controls.md). LOCAL config: a fresh
clone has to set it again. ⚠ AFTER, not before: the initial commit is clean BY CONSTRUCTION
(EXPLICIT list of files, never .env/.envrc), so there's nothing to scan there; arming it BEFORE
would require gitleaks to commit this scaffolding, and the hook HARD-FAILING in its absence would block
generation itself — the script would sabotage itself right after warning "gitleaks missing". The hook
protects DEV commits, not the scaffolding.
