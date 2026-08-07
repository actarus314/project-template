# `checks/verify-private-names.sh` — why it is written this way

> Convention: [`README.md`](README.md).

## The blind spot it covers

`gitleaks` matches token SHAPES — entropy, known prefixes, key formats. A **name** has no shape: a
private project called in a code comment as an example of a path looks exactly like any other word.
Flipping a repository to public exposes its whole history, and nothing in the stack reads it for
names.

Found the day this check was written: a private project name sat in `check.sh`, as an illustration
of what a parent directory looks like, published for two days on a public repository.

## The list lives OUTSIDE the repository it protects

`../workspace/private-names.txt`, never here — publishing the list of names to hide would publish
the names. The path is overridable (`PRIVATE_NAMES_FILE`) so the check can be exercised against a
fixture.

**No list is declared, never assumed clean**: the verdict says which file was read, or that none
was found. A silent pass would be indistinguishable from a sweep that found nothing.

## Why the patterns are regular expressions, and why that matters

An entry is an extended-regex alternative, matched case-insensitively across every **tracked** file.
The list carries its own warning, because the failure mode is not a missed name — it is a pattern so
broad that the guard fires on ordinary prose and gets worked around. A repository named after a
common English word is the case that breaks it, which is why the recommended form is the full
`owner/repo` slug or a `\b`-delimited name.

## What it cannot do

Rewriting a file removes nothing from the history already pushed. The check says so in its own
failure message rather than implying the problem is solved — removing a name from a published
history is a rewrite, and that decision belongs to the maintainer.
