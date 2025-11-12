#!/usr/bin/env bash
set -euo pipefail

# Promotion script: copy manifests from one env to another and create PR

SRC_ENV=${1:-dev}
DST_ENV=${2:-stage}
APP=${3:-guestbook}

BRANCH="promote/${APP}/${SRC_ENV}-to-${DST_ENV}-$(date +%s)"

echo "==========================================="
echo " Promoting $APP: $SRC_ENV → $DST_ENV"
echo "==========================================="

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found. Install: https://cli.github.com/"
    exit 1
fi

# Create promotion branch
echo "Creating branch: $BRANCH"
git checkout -b "$BRANCH"

# Copy patch-image.yaml
SRC_PATH="clusters/${SRC_ENV}/apps/${APP}/patch-image.yaml"
DST_PATH="clusters/${DST_ENV}/apps/${APP}/patch-image.yaml"

if [ ! -f "$SRC_PATH" ]; then
    echo "❌ Source file not found: $SRC_PATH"
    exit 1
fi

mkdir -p "$(dirname "$DST_PATH")"
cp "$SRC_PATH" "$DST_PATH"

echo "✅ Copied $SRC_PATH → $DST_PATH"

# Commit changes
git add "$DST_PATH"
git commit -m "chore: promote ${APP} from ${SRC_ENV} to ${DST_ENV}"

# Push branch
echo "Pushing branch..."
git push origin "$BRANCH"

# Create PR
echo "Creating pull request..."
gh pr create \
    --title "Promote ${APP}: ${SRC_ENV} → ${DST_ENV}" \
    --body "Automated promotion of ${APP} from ${SRC_ENV} to ${DST_ENV}

**Changes:**
- Updated image reference in ${DST_ENV}

**Review checklist:**
- [ ] Image tag is correct
- [ ] Tests passed in ${SRC_ENV}
- [ ] Ready for ${DST_ENV} deployment" \
    --base main \
    --head "$BRANCH"

echo ""
echo "==========================================="
echo "✅ Promotion PR created!"
echo "==========================================="
echo "Merge the PR to deploy to ${DST_ENV}"
