#!/usr/bin/env bash
# The same fact stated twice, in different words.
#
# METHODE's rule is that a fact lives in ONE place. Verbatim copying is already covered — measured
# across the living documents it comes to two lines, both commands quoted where they are run. What
# was left uncovered is the RESTATEMENT: two passages carrying the same fact without sharing a
# sentence, which no diff and no copy-paste detector can see.
#
# 🔴 What was tried first, and does not work: sentence embeddings. Run over this corpus a static
# embedding model flagged 1840 pairs against this file's 45 — six percent of every possible pair —
# and the ones it alone reported were noise ("consequences not to miss" matched against "gitleaks
# on every ref", at 0.94). The reason is structural: every document here talks about GitHub, CI and
# security, so the shared domain vocabulary drowns the signal. Twelve prose linters were examined
# too; not one compares two passages at all, their "redundancy" being a pleonasm inside one phrase.
#
# What DOES work is cheaper: weigh each word by how RARE it is across the corpus, and compare
# paragraphs on that. Our restatements reuse the technical vocabulary — `develop`, `staging`,
# `--artefact` — so they give themselves away without anything needing to understand them.
#
# 🔴 The limit, measured rather than guessed. A restatement that changes vocabulary on purpose
# ("container runtime" for Docker) was planted and scored 0.32: RANKED FIRST against the paragraph
# it restated, but below the 0.40 default. The threshold is therefore a dial, not a verdict —
# 0.40 reports 20 pairs here, 0.30 reports 45 and catches that rewording. What must not be claimed
# is full coverage: the reworded restatement is seen only if the dial is lowered, and the rest is
# judgement, which METHODE says outright.
#
# 🔴 ADVISORY, and it must stay so. It draws a LIST; the reader decides. Some pairs are legitimate:
# a template's copy, a command quoted where it is executed. A guard that blocked on this would be
# wrong often enough to be turned off.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "  (no python3 — skipped)"; exit 0; }

ECHO_THRESHOLD=${ECHO_THRESHOLD:-0.40} python3 - <<'PY'
import re, subprocess, sys, os, glob, math, collections, pathlib

THRESHOLD = float(os.environ.get("ECHO_THRESHOLD", "0.40"))

def paragraphs(path):
    try:
        raw = pathlib.Path(path).read_text(encoding="utf-8")
    except Exception:
        return
    raw = re.sub(r"```.*?```", "", raw, flags=re.S)      # code blocks are quoted, not stated
    for p in re.split(r"\n\s*\n", raw):
        p = " ".join(p.split())
        # Short fragments and table rows match each other on structure alone.
        if len(p) > 180 and not p.startswith("|"):
            yield p

# A method rule follows the method, so the neighbouring workspace is read too — but each repository
# on its own: one is English, the other deliberately French, and cross-language pairs share no
# vocabulary, so comparing them would only ever produce silence dressed up as a verdict.
# 🔴 The documents are DETECTED, never listed. This used to read `docs/*.md` plus three names at
# the root, which presumes a project keeps its prose exactly where this one does — a project
# writing into `documentation/`, `guide/` or `wiki/` was invisible to it, entirely and quietly.
# What is read now is every tracked `.md`, minus what restating is the NATURE of:
#   · a CHANGELOG accumulates entries that legitimately echo each other;
#   · an archive is cold and immutable — its whole point is to keep the account of a closed stage;
#   · an issue or pull-request template is a form, and its fields repeat by design.
def tracked_md(root="."):
    out = subprocess.run(["git", "-C", root, "ls-files", "*.md"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        return []
    # What restating is the NATURE of. A CHANGELOG accumulates entries; an archive is cold;
    # an issue template is a form. CODE_OF_CONDUCT is the Contributor Covenant, third-party
    # text taken verbatim — its graduated sanctions restate each other by design, and it is
    # not ours to reword. Same reasoning as the licence exception in verify-tone.sh.
    skip = re.compile(r"(^|/)(CHANGELOG\.md$|CODE_OF_CONDUCT\.md$|archives?/|\.github/)")
    return sorted(f"{root}/{f}" if root != "." else f
                  for f in out.stdout.splitlines() if f and not skip.search(f))

# Grouped by the PROJECT a document belongs to, and compared inside a group only. `templates/`
# holds the documents of a project this one GENERATES: its AGENTS.md restating this repo's is the
# template working, not a defect. And the two repositories are written in different languages, so
# a cross-group pair would share no vocabulary and could only ever score silence.
here = tracked_md()
GROUPS = [("repo/", [f for f in here if not f.startswith("templates/")]),
          ("templates/", [f for f in here if f.startswith("templates/")])]
if pathlib.Path("../workspace").is_dir():
    # Every tracked `.md` there too: `workspace/docs/SUIVI.md` is where the generator puts the
    # tracking doc, so a project following the documented default sat outside this check's reach.
    GROUPS.append(("workspace/", tracked_md("../workspace")))
GROUPS = [(label, files) for label, files in GROUPS if files]

FRENCH = re.compile(r"\b(les|des|une|est|pour|dans|avec|qui|que|sur|pas|plus)\b", re.I)
def language(text):
    return "fr" if len(FRENCH.findall(text)) >= 4 else "en"

def words(s):
    return [w for w in re.findall(r"[a-zà-ÿ]{4,}", re.sub(r"[`*_#>\[\]()]", " ", s.lower()))]

total = 0
for label, files in GROUPS:
    docs = [(f, p) for f in files for p in paragraphs(f)]
    n = len(docs)
    if n < 2:
        continue
    toks = [words(p) for _, p in docs]
    df = collections.Counter()
    for t in toks:
        df.update(set(t))

    vecs = []
    for t in toks:
        tf = collections.Counter(t)
        v = {w: (1 + math.log(c)) * math.log(n / (1 + df[w])) for w, c in tf.items()}
        norm = math.sqrt(sum(x * x for x in v.values())) or 1.0
        vecs.append({w: x / norm for w, x in v.items()})

    pairs = []
    # Computed ONCE per paragraph, not once per PAIR. The loop below is quadratic, so a regex over
    # the full text was being rerun n²/2 times on the same strings — the single dominant cost of
    # this check, and of the gate that waits on it.
    langs = [language(d[1]) for d in docs]
    for i in range(n):
        for j in range(i + 1, n):
            # The README is bilingual by design, and its two halves restate each other on purpose.
            if langs[i] != langs[j]:
                continue
            s = sum(vecs[i][w] * vecs[j].get(w, 0.0) for w in vecs[i])
            if s >= THRESHOLD:
                pairs.append((s, i, j))
    pairs.sort(reverse=True)
    total += len(pairs)
    if pairs:
        print(f"  {label} {len(pairs)} pair(s) of paragraphs stating the same thing (≥ {THRESHOLD:.2f}):")
        for s, i, j in pairs[:10]:
            print(f"    {s:.2f}  {docs[i][0]}  ↔  {docs[j][0]}")
            print(f"          {docs[i][1][:96]}")
            print(f"          {docs[j][1][:96]}")
        if len(pairs) > 10:
            print(f"    … and {len(pairs) - 10} more (raise ECHO_THRESHOLD to narrow)")

if total == 0:
    print("✓ no paragraph restates another, in either repository")
sys.exit(1 if total else 0)
PY
