#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo " Téléchargement de la dernière release    "
echo "=========================================="

if ! command -v gh &>/dev/null; then
    echo "[-] GitHub CLI (gh) n'est pas installé." >&2
    exit 1
fi

REPO="${1:-}"
if [[ -z "$REPO" ]]; then
    # Try to detect git remote origin
    if git remote get-url origin &>/dev/null; then
        REPO=$(git remote get-url origin | sed -E 's/.*github\.com[:\/](.*)\.git/\1/' | sed 's/.*github\.com\///')
    else
        REPO="Nico7an/YouZgeg"
    fi
fi

echo "[*] Dépôt ciblé : $REPO"
echo "[*] Récupération de la dernière release..."

LATEST_TAG=$(gh release view --repo "$REPO" --json tagName -q .tagName 2>/dev/null || true)

if [[ -z "$LATEST_TAG" ]]; then
    echo "[-] Aucune release trouvée pour $REPO." >&2
    exit 1
fi

echo "[+] Dernière release trouvée : $LATEST_TAG"
echo "[*] Téléchargement de youtube-morphe.apk..."

gh release download "$LATEST_TAG" --repo "$REPO" --pattern "youtube-morphe.apk" --dir "$SCRIPT_DIR" --clobber

echo "=========================================="
echo "[+] Fichier mis à jour avec succès :"
echo "    -> $SCRIPT_DIR/youtube-morphe.apk ($(du -h "$SCRIPT_DIR/youtube-morphe.apk" | cut -f1))"
echo "=========================================="
