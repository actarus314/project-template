#!/usr/bin/env bash
# blocking: yes   (what this does with a verdict; compared to the control table AND to its real exit code)
# Flags two paragraphs stating the same fact in different words — not a verbatim copy, which
# METHODE's link rule already catches elsewhere. Why TF-IDF over embeddings, the threshold's
# measured limit, and why blocking: verify-echo.md.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root: this script lives in checks/

if [ "${1:-}" = "--version" ]; then
  echo "project-template $(git describe --tags --abbrev=0 2>/dev/null || echo unreleased)"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "  (no python3 — skipped)"; exit 0; }

# Adjustable. What 0.40 catches, what it lets through, and the count at 0.30: verify-echo.md.
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

# Documents are detected, never listed, and each repository is compared only against itself
# (one is English, the other deliberately French — see verify-echo.md).
def tracked_md(root="."):
    out = subprocess.run(["git", "-C", root, "ls-files", "*.md"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        return []
    # Excluded by NATURE, not by content: a CHANGELOG, an archive and a template accumulate
    # repeats by design, and CODE_OF_CONDUCT is third-party text not ours to reword (same
    # reasoning as the licence exception in verify-tone.sh).
    skip = re.compile(r"(^|/)(CHANGELOG\.md$|CODE_OF_CONDUCT\.md$|archives?/|\.github/|skills/)")
    return sorted(f"{root}/{f}" if root != "." else f
                  for f in out.stdout.splitlines() if f and not skip.search(f))

# Grouped by the project a document belongs to, compared inside a group only (why: verify-echo.md).
here = tracked_md()
GROUPS = [("repo/", [f for f in here if not f.startswith("templates/")]),
          ("templates/", [f for f in here if f.startswith("templates/")])]
neighbour = pathlib.Path("../workspace").is_dir()
if neighbour:
    GROUPS.append(("workspace/", tracked_md("../workspace")))

FRENCH = re.compile(r"\b(les|des|une|est|pour|dans|avec|qui|que|sur|pas|plus|du|aux|ses|leur|jamais|sans|selon|chaque|ainsi|donc|cette|cet)\b", re.I)
def language(text):
    # >= 2, not 4: a short technical paragraph carries few function words, so the bilingual
    # README's French half read as English and was compared against its own English half.
    return "fr" if len(FRENCH.findall(text)) >= 2 else "en"

def words(s):
    return [w for w in re.findall(r"[a-zà-ÿ]{4,}", re.sub(r"[`*_#>\[\]()]", " ", s.lower()))]

total = 0
read_out = []
for label, files in GROUPS:
    docs = [(f, p) for f in files for p in paragraphs(f)]
    n = len(docs)
    read_out.append(f"{label} {len(files)} file(s), {n} paragraph(s)")
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

    # A paragraph LINKING to the other document is the pointer METHODE prescribes, not a copy — a
    # good pointer names its target, so excluding it is what lets the rule's own shape go unpunished.
    import os.path
    def points_at(text, other_path):
        base = os.path.basename(other_path)
        return f"]({base}" in text or f"](./{base}" in text or f"`{base}`" in text

    pairs = []
    # Computed ONCE per paragraph, not once per PAIR: the loop below is quadratic.
    langs = [language(d[1]) for d in docs]
    for i in range(n):
        for j in range(i + 1, n):
            # The README is bilingual by design, and its two halves restate each other on purpose.
            if langs[i] != langs[j]:
                continue
            if points_at(docs[i][1], docs[j][0]) or points_at(docs[j][1], docs[i][0]):
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

if not neighbour:
    print("  (no ../workspace beside this repo — its group was not read)")
print("  read: " + "; ".join(read_out))
if total == 0:
    print("✓ no paragraph restates another")
sys.exit(1 if total else 0)
PY
