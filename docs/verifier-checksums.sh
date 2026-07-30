#!/usr/bin/env bash
# Garde-fou anti-dérive entre docs/X.md (source de vérité) et docs/X.html (mise en page à la main).
#
# Chaque docs/X.html qui porte une ligne `checksum-source-md: sha256:<hash>` dans son commentaire
# d'en-tête déclare "je suis la vue de docs/X.md à CE hash-là". Ce script recalcule le sha256 du
# .md et le compare à celui inscrit dans le .html. Pas de ligne `checksum-source-md:` dans un
# .html -> ce fichier n'est pas concerné, silencieux (c'est le cas de tout projet généré, qui n'a
# aucun de ces fichiers).
#
# Usage :
#   docs/verifier-checksums.sh          # vérifie ; sort en erreur (1) si un .md a dérivé
#   docs/verifier-checksums.sh --maj    # recalcule et réécrit le checksum dans chaque .html
set -euo pipefail
cd "$(dirname "$0")/.."   # racine du repo, quel que soit le cwd d'appel

maj=0
[ "${1:-}" = "--maj" ] && maj=1

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'   # macOS n'a pas sha256sum de base
  fi
}

fail=0
shopt -s nullglob
for html in docs/*.html; do
  stocke=$(grep -o 'checksum-source-md: sha256:[0-9a-f]*' "$html" | awk -F: '{print $3}' || true)
  [ -n "$stocke" ] || continue   # pas de marqueur -> ce .html n'est pas concerné

  md="${html%.html}.md"
  if [ ! -f "$md" ]; then
    echo "✗ $html référence $md, introuvable" >&2
    fail=1
    continue
  fi

  actuel=$(sha256 "$md")

  if [ "$maj" = 1 ]; then
    sed -i.bak "s/checksum-source-md: sha256:[0-9a-f]*/checksum-source-md: sha256:$actuel/" "$html"
    rm -f "$html.bak"
    echo "✓ $html : checksum mis à jour ($actuel)"
    continue
  fi

  if [ "$actuel" = "$stocke" ]; then
    echo "✓ $html à jour avec $md"
  else
    echo "✗ $md a changé depuis la dernière mise à jour de $html — reporter le changement, puis mettre à jour le checksum avec : docs/verifier-checksums.sh --maj" >&2
    fail=1
  fi
done

exit "$fail"
