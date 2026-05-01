#!/usr/bin/env bash
# Activate the project-versioned git hooks under .githooks/.
# Idempotent.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

current=$(git config --local --get core.hooksPath 2>/dev/null || true)

if [ "$current" = ".githooks" ]; then
    echo "[OK]    core.hooksPath already set to .githooks"
else
    git config --local core.hooksPath .githooks
    echo "[OK]    core.hooksPath set to .githooks"
fi

# Make sure the hooks are executable (in case Git stripped the bit on clone).
chmod +x .githooks/* 2>/dev/null || true

echo "[INFO]  Hooks active for this clone:"
find .githooks -maxdepth 1 -type f -printf '        - %f\n' | sort
