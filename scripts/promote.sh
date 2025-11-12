#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

SRC_ENV=${1:-dev}
DST_ENV=${2:-stage}
APP=${3:-guestbook}
BRANCH="ci/promote-${APP}-${SRC_ENV}-to-${DST_ENV}-$(date +%s)"

echo "Promoting ${APP} from ${SRC_ENV} -> ${DST_ENV} (branch ${BRANCH})"
echo "Repo root: ${REPO_ROOT}"

# Paths relative to repo root
SRC="${REPO_ROOT}/clusters/${SRC_ENV}/apps/${APP}/patch-image.yaml"
DST="${REPO_ROOT}/clusters/${DST_ENV}/apps/${APP}/patch-image.yaml"

if [ ! -f "$SRC" ]; then
  echo "❌ Source patch not found: $SRC"
  exit 1
fi

# Are we inside a git repo?
inside_git_repo=false
if git rev-parse --is-inside-work-tree &>/dev/null; then
  inside_git_repo=true
fi

if $inside_git_repo; then
  echo "Git repo detected."

  # Try fetch origin only if origin exists
  if git remote get-url origin &>/dev/null; then
    echo "Fetching origin..."
    git fetch origin || echo "⚠ Could not fetch origin (network or no origin)"
  else
    echo "No 'origin' remote found; skipping fetch."
  fi

  git checkout -b "$BRANCH"
else
  echo "Not inside a git repo. Creating local branch logic only (no push/PR)."
  # If not a git repo, create a temp git repo in REPO_ROOT to commit the change (non-invasive)
  ( cd "$REPO_ROOT" && git init >/dev/null 2>&1 || true )
  git checkout -b "$BRANCH" || git switch -c "$BRANCH"
fi

mkdir -p "$(dirname "$DST")"
cp "$SRC" "$DST"
git add "$DST"
git commit -m "ci: promote ${APP} ${SRC_ENV} -> ${DST_ENV}" || echo "No changes to commit (file identical?)"

# Only attempt to push if 'origin' remote exists
if $inside_git_repo && git remote get-url origin &>/dev/null; then
  echo "Pushing branch to origin..."
  git push --set-upstream origin "$BRANCH" || echo "⚠ Git push failed (check remote auth)"
else
  echo "Skipping git push (no origin remote or not a git repo)."
fi

# Create PR only if gh CLI exists and we pushed to origin
if command -v gh >/dev/null 2>&1 && $inside_git_repo && git remote get-url origin &>/dev/null; then
  echo "Creating PR with gh..."
  gh pr create --title "Promote: ${APP} ${SRC_ENV} → ${DST_ENV}" --body "Automated promotion PR" --base main || echo "⚠ gh PR create failed (check gh auth/permissions)"
  echo "PR created (or attempted)."
else
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found; skipping PR creation. Install from https://cli.github.com/"
  else
    echo "Skipping PR creation (no origin remote or not a git repo)."
  fi
fi

echo "✅ Promotion script completed. Branch: ${BRANCH}"
