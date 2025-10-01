#!/bin/bash

# sync.sh - Bidirectional sync between local files and GitHub issues
# Follows /rules/github-operations.md and /rules/frontmatter-operations.md

set -e

EPIC_NAME="$1"
EPICS_DIR=".claude/epics"

# Counters
PULLED_UPDATED=0
PULLED_CLOSED=0
PUSHED_UPDATED=0
PUSHED_CREATED=0
CONFLICTS=0

# CRITICAL: Repository Protection Check
# Before ANY GitHub operation, check we're not in the CCPM template repo
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm"* ]] || [[ "$remote_url" == *"automazeio/ccpm.git"* ]]; then
  echo "❌ ERROR: You're trying to sync with the CCPM template repository!"
  echo ""
  echo "This repository (automazeio/ccpm) is a template for others to use."
  echo "You should NOT create issues or PRs here."
  echo ""
  echo "To fix this:"
  echo "1. Fork this repository to your own GitHub account"
  echo "2. Update your remote origin:"
  echo "   git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
  echo ""
  echo "Current remote: $remote_url"
  exit 1
fi

# Get current datetime for sync timestamp
SYNC_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "🔄 Starting Sync - $SYNC_TIME"
echo "================================"
echo ""

# Helper: Extract issue number from GitHub URL
extract_issue_number() {
  local url="$1"
  echo "$url" | grep -oE '[0-9]+$'
}

# Helper: Update frontmatter field in file
update_frontmatter_field() {
  local file="$1"
  local field="$2"
  local value="$3"

  # Use sed to update field in frontmatter
  if grep -q "^${field}:" "$file"; then
    sed -i "s|^${field}:.*|${field}: ${value}|" "$file"
  else
    # Add field after first --- line
    sed -i "0,/^---$/s|^---$|---\n${field}: ${value}|" "$file"
  fi
}

# 1. PULL FROM GITHUB
echo "📥 Pulling from GitHub..."
echo ""

# Get all epic and task issues
EPICS_JSON=$(gh issue list --label "epic" --limit 1000 --json number,title,state,body,labels,updatedAt 2>/dev/null || echo "[]")
TASKS_JSON=$(gh issue list --label "task" --limit 1000 --json number,title,state,body,labels,updatedAt 2>/dev/null || echo "[]")

if [ "$EPICS_JSON" = "[]" ] && [ "$TASKS_JSON" = "[]" ]; then
  echo "⚠️  No GitHub issues found (or gh auth needed)"
fi

# Helper: Extract epic name with fallbacks
extract_epic_name() {
  local issue_json="$1"
  local issue_title="$2"

  # Strategy 1: Try epic:name label
  local epic_label=$(echo "$issue_json" | jq -r '.labels[] | select(.name | startswith("epic:")) | .name' | head -1)
  if [ -n "$epic_label" ]; then
    echo "$epic_label" | sed 's/^epic://'
    return
  fi

  # Strategy 2: Extract from title like "Epic: Cloud Authentication"
  if echo "$issue_title" | grep -qi "^Epic:"; then
    local name=$(echo "$issue_title" | sed 's/^Epic: *//I' | sed 's/ *(.*$//')
    # Convert to slug: "Cloud Authentication" → "cloud-authentication"
    echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g'
    return
  fi

  # Strategy 3: Use command-line argument if provided
  if [ -n "$EPIC_NAME" ]; then
    echo "$EPIC_NAME"
    return
  fi

  # Strategy 4: Search existing epic directories
  local first_epic=$(ls -1d "$EPICS_DIR"/*/ 2>/dev/null | head -1 | xargs basename)
  if [ -n "$first_epic" ]; then
    echo "$first_epic"
    return
  fi

  # No epic name found
  echo ""
}

# Helper: Process GitHub issue and update local file
process_github_issue() {
  local issue_json="$1"
  local issue_number=$(echo "$issue_json" | jq -r '.number')
  local issue_state=$(echo "$issue_json" | jq -r '.state' | tr '[:upper:]' '[:lower:]')
  local issue_updated=$(echo "$issue_json" | jq -r '.updatedAt')
  local issue_title=$(echo "$issue_json" | jq -r '.title')

  # Find local file with this GitHub issue number
  local found_file=""

  if [ -n "$EPIC_NAME" ]; then
    # Search only in specified epic
    for file in "$EPICS_DIR/$EPIC_NAME"/*.md; do
      [ -f "$file" ] || continue
      if grep -q "github:.*issues/${issue_number}" "$file" 2>/dev/null; then
        found_file="$file"
        break
      fi
    done
  else
    # Search all epics
    for file in "$EPICS_DIR"/*/*.md; do
      [ -f "$file" ] || continue
      if grep -q "github:.*issues/${issue_number}" "$file" 2>/dev/null; then
        found_file="$file"
        break
      fi
    done
  fi

  if [ -z "$found_file" ]; then
    # No local file found - create one from GitHub issue
    local is_epic=false
    echo "$issue_json" | jq -r '.labels[].name' | grep -q "^epic$" && is_epic=true

    # Use helper to extract epic name with fallbacks
    local epic_name=$(extract_epic_name "$issue_json" "$issue_title")

    if [ -z "$epic_name" ]; then
      echo "  ⚠️  Skipping issue #$issue_number: Cannot determine epic name"
      return
    fi

    # Determine epic directory and file path
    local epic_dir="$EPICS_DIR/$epic_name"
    mkdir -p "$epic_dir"

    if [ "$is_epic" = true ]; then
      found_file="$epic_dir/epic.md"
    else
      found_file="$epic_dir/${issue_number}.md"
    fi

    echo "  📥 Creating local file from GitHub: $(basename "$found_file") in epic '$epic_name'"

    # Get issue body
    local issue_body=$(echo "$issue_json" | jq -r '.body // ""')

    # Map state (issue_state is already lowercase from tr above)
    local status="open"
    [ "$issue_state" = "closed" ] && status="closed"

    # Create file with frontmatter
    cat > "$found_file" <<EOF
---
name: $issue_title
status: $status
created: $issue_updated
updated: $issue_updated
last_sync: $SYNC_TIME
github: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/issues/$issue_number
---

$issue_body
EOF
    ((PULLED_UPDATED++))
    return
  fi

  # Get local updated time
  local local_updated=$(grep "^updated:" "$found_file" | head -1 | sed 's/^updated: *//')

  # Compare timestamps (simple string comparison works for ISO dates)
  if [[ "$issue_updated" > "$local_updated" ]]; then
    # GitHub is newer - update local
    echo "  ⬇️  Updating local: $(basename "$found_file")"

    # Map GitHub state to local status
    local new_status=""
    if [ "$issue_state" = "closed" ]; then
      if [[ "$found_file" == */epic.md ]]; then
        new_status="completed"
      else
        new_status="closed"
      fi
    elif [ "$issue_state" = "open" ]; then
      if [[ "$found_file" == */epic.md ]]; then
        new_status="in-progress"
      else
        new_status="open"
      fi
    fi

    if [ -n "$new_status" ]; then
      update_frontmatter_field "$found_file" "status" "$new_status"
      update_frontmatter_field "$found_file" "updated" "$issue_updated"
      update_frontmatter_field "$found_file" "last_sync" "$SYNC_TIME"
      ((PULLED_UPDATED++))

      if [ "$issue_state" = "closed" ]; then
        ((PULLED_CLOSED++))
      fi
    fi
  fi
}

# Process all GitHub issues
if command -v jq >/dev/null 2>&1; then
  echo "$EPICS_JSON" | jq -c '.[]' 2>/dev/null | while read -r issue; do
    process_github_issue "$issue"
  done

  echo "$TASKS_JSON" | jq -c '.[]' 2>/dev/null | while read -r issue; do
    process_github_issue "$issue"
  done
else
  echo "⚠️  jq not installed - skipping GitHub pull"
fi

echo ""

# 2. PUSH LOCAL TO GITHUB
echo "📤 Pushing local changes to GitHub..."
echo ""

# Helper: Push local file to GitHub
push_to_github() {
  local file="$1"

  # Extract frontmatter
  local github_url=$(grep "^github:" "$file" | head -1 | sed 's/^github: *//')
  local local_updated=$(grep "^updated:" "$file" | head -1 | sed 's/^updated: *//')
  local status=$(grep "^status:" "$file" | head -1 | sed 's/^status: *//')
  local title=$(grep "^name:" "$file" | head -1 | sed 's/^name: *//')

  if [ -z "$github_url" ]; then
    # No GitHub URL - create new issue
    echo "  ⬆️  Creating: $(basename "$file")"

    # Determine labels
    local labels="task"
    if [[ "$file" == */epic.md ]]; then
      labels="epic"
    fi

    # Create issue
    local new_url=$(gh issue create --title "$title" --body-file "$file" --label "$labels" 2>/dev/null | grep -oE 'https://[^ ]+')

    if [ -n "$new_url" ]; then
      update_frontmatter_field "$file" "github" "$new_url"
      update_frontmatter_field "$file" "last_sync" "$SYNC_TIME"
      ((PUSHED_CREATED++))
    else
      echo "    ❌ Failed to create issue"
    fi
  else
    # Has GitHub URL - check if issue exists and update if needed
    local issue_number=$(extract_issue_number "$github_url")

    if [ -n "$issue_number" ]; then
      # Check if issue exists on GitHub
      local gh_issue=$(gh issue view "$issue_number" --json state,updatedAt 2>/dev/null || echo "")

      if [ -z "$gh_issue" ]; then
        # Issue deleted on GitHub - mark local as archived
        echo "  🗑️  Issue #$issue_number deleted on GitHub: $(basename "$file")"
        update_frontmatter_field "$file" "status" "archived"
        update_frontmatter_field "$file" "updated" "$SYNC_TIME"
      else
        # Issue exists - check if local is newer
        local gh_updated=$(echo "$gh_issue" | jq -r '.updatedAt' 2>/dev/null)

        if [[ "$local_updated" > "$gh_updated" ]]; then
          # Local is newer - push to GitHub
          echo "  ⬆️  Updating: $(basename "$file") -> #$issue_number"

          gh issue edit "$issue_number" --body-file "$file" 2>/dev/null && {
            update_frontmatter_field "$file" "last_sync" "$SYNC_TIME"
            ((PUSHED_UPDATED++))
          } || echo "    ❌ Failed to update issue"
        fi
      fi
    fi
  fi
}

# Process local files
if [ -n "$EPIC_NAME" ]; then
  # Sync only specified epic
  if [ -d "$EPICS_DIR/$EPIC_NAME" ]; then
    for file in "$EPICS_DIR/$EPIC_NAME"/*.md; do
      [ -f "$file" ] || continue
      push_to_github "$file"
    done
  else
    echo "❌ Epic not found: $EPIC_NAME"
    exit 1
  fi
else
  # Sync all epics
  for file in "$EPICS_DIR"/*/*.md; do
    [ -f "$file" ] || continue
    push_to_github "$file"
  done
fi

echo ""

# 3. POST SYNC COMMENT (if significant changes)
total_changes=$((PULLED_UPDATED + PULLED_CLOSED + PUSHED_UPDATED + PUSHED_CREATED))

if [ $total_changes -gt 0 ]; then
  # Find the main epic to post comment to
  for epic_file in "$EPICS_DIR"/*/epic.md; do
    [ -f "$epic_file" ] || continue

    epic_github=$(grep "^github:" "$epic_file" | head -1 | sed 's/^github: *//')
    epic_number=$(extract_issue_number "$epic_github")

    if [ -n "$epic_number" ]; then
      # Create sync comment
      cat > /tmp/sync-comment.md <<COMMENT_EOF
## 🔄 Sync Update - $SYNC_TIME

### Summary
- 📥 **Pulled from GitHub**: $PULLED_UPDATED updated, $PULLED_CLOSED closed
- 📤 **Pushed to GitHub**: $PUSHED_UPDATED updated, $PUSHED_CREATED created
- 📊 **Total changes**: $total_changes

### Status
All local files and GitHub issues are now synchronized.

---
*Auto-generated by \`/pm:sync\`*
COMMENT_EOF

      # Post comment to epic
      gh issue comment "$epic_number" --body-file /tmp/sync-comment.md 2>/dev/null && {
        echo "💬 Posted sync summary to epic #$epic_number"
      } || {
        echo "⚠️  Could not post comment to epic #$epic_number"
      }

      rm -f /tmp/sync-comment.md
      break  # Only post to first epic found
    fi
  done
fi

echo ""

# 4. SUMMARY
echo "✅ Sync Complete"
echo "================================"
echo ""
echo "Pulled from GitHub:"
echo "  Updated: $PULLED_UPDATED files"
echo "  Closed: $PULLED_CLOSED issues"
echo ""
echo "Pushed to GitHub:"
echo "  Updated: $PUSHED_UPDATED issues"
echo "  Created: $PUSHED_CREATED new issues"
echo ""

if [ $CONFLICTS -gt 0 ]; then
  echo "Conflicts resolved: $CONFLICTS"
  echo ""
fi

echo "Status: ✅ All files synced"
echo ""

exit 0
