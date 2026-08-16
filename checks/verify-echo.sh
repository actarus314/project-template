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

# Yields (paragraph, is_header) — a header being what stands before the first section, and only
# where such a section EXISTS: otherwise a file without one is read as all header, and leaves in
# silence. Why headers are exempt at all, and what it cost to find out: verify-echo.md.
def split_paragraphs(raw):
    raw = re.sub(r"```.*?```", "", raw, flags=re.S)      # code blocks are quoted, not stated
    blocks = re.split(r"\n\s*\n", raw)
    sectioned = any(re.match(r"^##+ ", b.strip()) for b in blocks)
    seen_section = not sectioned
    for b in blocks:
        if re.match(r"^##+ ", b.strip()):
            seen_section = True
        p = " ".join(b.split())
        # Short fragments and table rows match each other on structure alone.
        if len(p) > 180 and not p.startswith("|"):
            yield p, not seen_section


def paragraphs(path):
    try:
        raw = pathlib.Path(path).read_text(encoding="utf-8")
    except Exception:
        return
    yield from split_paragraphs(raw)


# The WEIGHTING is read from HEAD; what is JUDGED stays the working tree. The anchor is the
# instrument, not the object — a neighbour's uncommitted writing moved a score by 0.078, enough to
# refuse a commit over what someone else was typing, and moves it by 0.0000 here. Why: verify-echo.md.
def head_paragraphs(root="."):
    names = subprocess.run(["git", "-C", root, "ls-tree", "-r", "--name-only", "HEAD"],
                           capture_output=True, text=True)
    if names.returncode != 0:                            # a repository with no commit yet
        return None
    files = [f for f in names.stdout.split("\n") if f.endswith(".md") and not SKIP.search(f)]
    if not files:
        return None
    blobs = subprocess.run(["git", "-C", root, "cat-file", "--batch"],
                           input="\n".join(f"HEAD:{f}" for f in files).encode(),
                           capture_output=True).stdout   # BYTES: the sizes git prints are bytes
    out, pos = [], 0
    for f in files:
        head = blobs.index(b"\n", pos)
        fields = blobs[pos:head].split()
        if len(fields) < 3:                              # `<sha> missing` — nothing to weigh
            pos = head + 1
            continue
        size = int(fields[2])
        path = f"{root}/{f}" if root != "." else f
        # A header WEIGHS like any other text — it is corpus. It is only barred from being COMPARED.
        out += [(path, p) for p, _ in split_paragraphs(blobs[head + 1:head + 1 + size].decode("utf-8", "replace"))]
        pos = head + 1 + size + 1
    return out

# Excluded by NATURE, not by content: a CHANGELOG, an archive and a template accumulate
# repeats by design, and CODE_OF_CONDUCT is third-party text not ours to reword (same
# reasoning as the licence exception in verify-tone.sh).
SKIP = re.compile(r"(^|/)(CHANGELOG\.md$|CODE_OF_CONDUCT\.md$|archives?/|\.github/|skills/)")


# Documents are detected, never listed, and each repository is compared only against itself
# (one is English, the other deliberately French — see verify-echo.md).
def tracked_md(root="."):
    out = subprocess.run(["git", "-C", root, "ls-files", "*.md"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        return []
    return sorted(f"{root}/{f}" if root != "." else f
                  for f in out.stdout.splitlines() if f and not SKIP.search(f))

# Grouped by the project a document belongs to, compared inside a group only (why: verify-echo.md).
# A group is split the same way on both sides — the tree it judges, and the HEAD it weighs with.
def own(files):
    return [f for f in files if not f.startswith("templates/")]


def tpl(files):
    return [f for f in files if f.startswith("templates/")]


here, head_here = tracked_md(), head_paragraphs()
GROUPS = [("repo/", own(here), None if head_here is None else [d for d in head_here if not d[0].startswith("templates/")]),
          ("templates/", tpl(here), None if head_here is None else [d for d in head_here if d[0].startswith("templates/")])]
neighbour = pathlib.Path("../workspace").is_dir()
if neighbour:
    GROUPS.append(("workspace/", tracked_md("../workspace"), head_paragraphs("../workspace")))

FRENCH = re.compile(r"\b(les|des|une|est|pour|dans|avec|qui|que|sur|pas|plus|du|aux|ses|leur|jamais|sans|selon|chaque|ainsi|donc|cette|cet)\b", re.I)
def language(text):
    # >= 2, not 4: a short technical paragraph carries few function words, so the bilingual
    # README's French half read as English and was compared against its own English half.
    return "fr" if len(FRENCH.findall(text)) >= 2 else "en"

def words(s):
    # A link's TARGET is a path, not prose — its folder name scored two paragraphs at 0.40 on words
    # neither author wrote. The link TEXT stays. Pointer detection reads the raw paragraph, not this.
    s = re.sub(r"\]\([^)]*\)", "] ", s)
    return [w for w in re.findall(r"[a-zà-ÿ]{4,}", re.sub(r"[`*_#>\[\]()]", " ", s.lower()))]

total = 0
read_out = []
for label, files, weighed_on in GROUPS:
    docs = [(f, p, header) for f in files for p, header in paragraphs(f)]
    n = len(docs)
    # Two DISTINCT fallbacks, worded apart: one wording for both once had a committed repository
    # report itself as having no commit at all. An anchor nobody can see reads as reproducible.
    tree = [(f, p) for f, p, _ in docs]
    if weighed_on is None:
        anchor, anchored = tree, "the working tree (no commit yet)"
    elif not weighed_on:
        anchor, anchored = tree, "the working tree (nothing committed in this group yet)"
    else:
        anchor, anchored = weighed_on, f"HEAD ({len(weighed_on)} paragraph(s))"
    # What was exempted is published: an exemption nobody counts grows until it covers the corpus.
    heads = sum(1 for d in docs if d[2])
    read_out.append(f"{label} {len(files)} file(s), {n} paragraph(s), weighed on {anchored}, "
                    f"{heads} header(s) not compared")
    if n < 2:
        continue
    df = collections.Counter()
    for _, p in anchor:
        df.update(set(words(p)))
    weights = len(anchor)

    vecs = []
    for _, p in tree:
        tf = collections.Counter(words(p))
        v = {w: (1 + math.log(c)) * math.log(weights / (1 + df[w])) for w, c in tf.items()}
        norm = math.sqrt(sum(x * x for x in v.values())) or 1.0
        vecs.append({w: x / norm for w, x in v.items()})

    # NOTHING is exempted for carrying a link: a pointer REPLACES the fact, it does not accompany
    # it, and the exemption protected seven passages that pointed AND restated. Why: verify-echo.md.

    # An INVERTED INDEX rather than every pair: two paragraphs sharing no word score zero, so they
    # are never visited, and headers and the bilingual halves leave it outright. 4x faster.
    langs = [language(d[1]) for d in docs]        # computed once per paragraph, never per pair
    postings = collections.defaultdict(list)
    for idx, (_, _, header) in enumerate(docs):
        if header:
            continue
        for w, x in vecs[idx].items():
            postings[(langs[idx], w)].append((idx, x))

    acc = collections.defaultdict(float)
    for lot in postings.values():
        for p in range(len(lot)):
            ip, xp = lot[p]
            for q in range(p + 1, len(lot)):
                iq, xq = lot[q]
                acc[(ip, iq) if ip < iq else (iq, ip)] += xp * xq

    pairs = [(s, i, j) for (i, j), s in acc.items() if s >= THRESHOLD]
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
