#!/usr/bin/env bash
set -euo pipefail

REPO="ericdahl-dev/spacebot-blog"
BRANCH="redesign/base-layout"
COMMIT_MSG="Redesign: minimal header, dark theme, centered layout, simple post list"

cd /data/agents/main/workspace/spacebot-blog

# get main commit sha
MAIN_COMMIT_SHA=$(curl -s -H "Authorization: token $GH_TOKEN" "https://api.github.com/repos/$REPO/git/ref/heads/main" | sed -n 's/.*"sha"[[:space:]]*:[[:space:]]*"\([a-f0-9]\{40\}\)".*/\1/p' | head -n1)
if [ -z "$MAIN_COMMIT_SHA" ]; then echo "Failed to get main commit sha" >&2; exit 1; fi

echo "main_commit=$MAIN_COMMIT_SHA"

MAIN_TREE_SHA=$(curl -s -H "Authorization: token $GH_TOKEN" "https://api.github.com/repos/$REPO/git/commits/$MAIN_COMMIT_SHA" | sed -n 's/.*"tree"[[:space:]]*:[[:space:]]*{[^}]*"sha"[[:space:]]*:[[:space:]]*"\([a-f0-9]\{40\}\)".*/\1/p' | head -n1)
if [ -z "$MAIN_TREE_SHA" ]; then echo "Failed to get main tree sha" >&2; exit 1; fi

echo "main_tree=$MAIN_TREE_SHA"

TMP_ENTRIES=$(mktemp)
FIRST=1

env LC_ALL=C find . -type f -not -path './.git/*' -print0 | while IFS= read -r -d '' file; do
  path=${file#./}
  echo "Processing: $path"
  b64=$(base64 -w0 "$file")
  # create blob
  resp=$(curl -s -X POST -H "Authorization: token $GH_TOKEN" -H "Content-Type: application/json" \
    -d "{\"content\":\"$b64\",\"encoding\":\"base64\"}" \
    "https://api.github.com/repos/$REPO/git/blobs")
  blob_sha=$(printf '%s' "$resp" | sed -n 's/.*"sha"[[:space:]]*:[[:space:]]*"\([a-f0-9]\{40\}\)".*/\1/p' | head -n1)
  if [ -z "$blob_sha" ]; then echo "Failed creating blob for $path: $resp" >&2; exit 1; fi
  mode="100644"
  if [ -x "$file" ]; then mode="100755"; fi
  esc_path=$(printf '%s' "$path" | sed -e 's/\\/\\\\/g' -e 's/"/\\\"/g')
  entry="{\"path\":\"$esc_path\",\"mode\":\"$mode\",\"type\":\"blob\",\"sha\":\"$blob_sha\"}"
  if [ $FIRST -eq 1 ]; then
    printf '%s' "$entry" >> "$TMP_ENTRIES"
    FIRST=0
  else
    printf ',%s' "$entry" >> "$TMP_ENTRIES"
  fi

done

TREE_PAYLOAD=$(mktemp)
printf '{"tree":[%s], "base_tree":"%s"}' "$(cat $TMP_ENTRIES)" "$MAIN_TREE_SHA" > "$TREE_PAYLOAD"

# create new tree
NEW_TREE_RESP=$(curl -s -X POST -H "Authorization: token $GH_TOKEN" -H "Content-Type: application/json" \
  -d @"$TREE_PAYLOAD" "https://api.github.com/repos/$REPO/git/trees")
NEW_TREE_SHA=$(printf '%s' "$NEW_TREE_RESP" | sed -n 's/.*"sha"[[:space:]]*:[[:space:]]*"\([a-f0-9]\{40\}\)".*/\1/p' | head -n1)
if [ -z "$NEW_TREE_SHA" ]; then echo "Failed to create new tree: $NEW_TREE_RESP" >&2; exit 1; fi

echo "new_tree=$NEW_TREE_SHA"

# create commit
NEW_COMMIT_RESP=$(curl -s -X POST -H "Authorization: token $GH_TOKEN" -H "Content-Type: application/json" \
  -d "{\"message\": \"$COMMIT_MSG\", \"tree\": \"$NEW_TREE_SHA\", \"parents\": [\"$MAIN_COMMIT_SHA\"]}" \
  "https://api.github.com/repos/$REPO/git/commits")
NEW_COMMIT_SHA=$(printf '%s' "$NEW_COMMIT_RESP" | sed -n 's/.*"sha"[[:space:]]*:[[:space:]]*"\([a-f0-9]\{40\}\)".*/\1/p' | head -n1)
if [ -z "$NEW_COMMIT_SHA" ]; then echo "Failed to create commit: $NEW_COMMIT_RESP" >&2; exit 1; fi

echo "new_commit=$NEW_COMMIT_SHA"

# create branch ref
REF_RESP=$(curl -s -X POST -H "Authorization: token $GH_TOKEN" -H "Content-Type: application/json" \
  -d "{\"ref\": \"refs/heads/$BRANCH\", \"sha\": \"$NEW_COMMIT_SHA\"}" \
  "https://api.github.com/repos/$REPO/git/refs")
# check for errors
if printf '%s' "$REF_RESP" | grep -q "Reference already exists"; then
  echo "Branch already exists; attempting to update ref"
  # update ref
  UPD_RESP=$(curl -s -X PATCH -H "Authorization: token $GH_TOKEN" -H "Content-Type: application/json" \
    -d "{\"sha\": \"$NEW_COMMIT_SHA\", \"force\": false}" \
    "https://api.github.com/repos/$REPO/git/refs/heads/$BRANCH")
  echo "$UPD_RESP" > /tmp/ref_resp
else
  echo "$REF_RESP" > /tmp/ref_resp
fi

# create pull request
PR_RESP=$(curl -s -X POST -H "Authorization: token $GH_TOKEN" -H "Content-Type: application/json" \
  -d "{\"title\": \"$COMMIT_MSG\", \"head\": \"$BRANCH\", \"base\": \"main\", \"body\": \"Automated PR: apply redesign changes (header, dark theme, layout, post list)\"}" \
  "https://api.github.com/repos/$REPO/pulls")
PR_URL=$(printf '%s' "$PR_RESP" | sed -n 's/.*"html_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
if [ -z "$PR_URL" ]; then echo "Failed to create PR: $PR_RESP" >&2; exit 1; fi

echo "PR created: $PR_URL"

# output summary
cat <<EOF
PR_URL=$PR_URL
BRANCH=$BRANCH
EOF
