#!/bin/bash
# One-time setup: create the repository signing key, store it as the
# REPO_SIGNING_KEY Actions secret and keep a local backup.
set -euo pipefail
REPO=${1:-uroni/urbackup-grub}
BACKUP=${2:-$HOME/urbackup-grub-repo-signing-key.asc}
export GNUPGHOME=$(mktemp -d)
trap 'rm -rf "$GNUPGHOME"' EXIT
gpg --batch --passphrase '' --quick-gen-key "UrBackup GRUB APT repository" ed25519 sign never
FPR=$(gpg --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')
(umask 077; gpg --armor --export-secret-keys "$FPR" > "$BACKUP")
gh secret set REPO_SIGNING_KEY -R "$REPO" < "$BACKUP"
echo "Key $FPR stored as secret in $REPO; backup at $BACKUP"
