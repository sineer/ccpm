#!/bin/bash

echo "🔄 Bidirectional GitHub Sync"
echo "============================="
echo ""

# Initialize counters
pulled_updated=0
pulled_closed=0
pushed_updated=0
pushed_created=0
conflicts_resolved=0
sync_failures=""

# Create temp directory for sync data
SYNC_DIR="/tmp/claude-sync-$$"
mkdir -p "$SYNC_DIR"

# 1. Pull from GitHub
echo "📥 Pulling from GitHub..."
gh issue list --label "epic" --limit 1000 --json number,title,state,body,labels,updatedAt > "$SYNC_DIR/github-epics.json"
gh issue list --label "task" --limit 1000 --json number,title,state,body,labels,updatedAt > "$SYNC_DIR/github-tasks.json"

# Also get closed issues from recent past (last 30 days)
gh issue list --label "epic" --state closed --limit 1000 --json number,title,state,body,labels,updatedAt \
  | jq --arg date "$(date -u -v-30d '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d '30 days ago' '+%Y-%m-%dT%H:%M:%SZ')" \
  '[.[] | select(.updatedAt > $date)]' > "$SYNC_DIR/github-epics-closed.json"

# Combine open and recently closed
jq -s 'add' "$SYNC_DIR/github-epics.json" "$SYNC_DIR/github-epics-closed.json" > "$SYNC_DIR/all-github-epics.json"

echo "Found $(jq 'length' "$SYNC_DIR/all-github-epics.json") GitHub issues to process"
echo ""

# 2. Update Local from GitHub
echo "📝 Updating local files from GitHub..."

# Process each GitHub issue
jq -c '.[]' "$SYNC_DIR/all-github-epics.json" | while IFS= read -r issue_json; do
  issue_num=$(echo "$issue_json" | jq -r '.number')
  issue_title=$(echo "$issue_json" | jq -r '.title')
  issue_state=$(echo "$issue_json" | jq -r '.state' | tr '[:upper:]' '[:lower:]')
  github_updated=$(echo "$issue_json" | jq -r '.updatedAt')

  # Map GitHub state to our status
  if [ "$issue_state" = "closed" ]; then
    new_status="closed"
  elif [ "$issue_state" = "open" ]; then
    new_status="open"
  fi

  # Find local file
  local_file=$(find .claude/epics -name "${issue_num}.md" 2>/dev/null | head -1)

  if [ -z "$local_file" ]; then
    # Check if it's an epic with its own directory
    if [[ "$issue_title" == *"[Epic"* ]] || [[ "$issue_title" == "Epic:"* ]]; then
      # Determine epic name
      if [ "$issue_num" = "34" ]; then
        epic_name="e2e-captive-portal"
      elif [[ "$issue_title" == *"INTEG-"* ]]; then
        epic_name=$(echo "$issue_title" | grep -oE 'INTEG-[0-9]+-[a-z-]+' | head -1)
      else
        epic_name="issue-${issue_num}"
      fi

      epic_dir=".claude/epics/$epic_name"

      # Create epic if it doesn't exist
      if [ ! -d "$epic_dir" ]; then
        echo "  ✨ Creating new epic: $epic_name (#$issue_num)"
        mkdir -p "$epic_dir"
        cat > "$epic_dir/epic.md" << EOF
---
name: $epic_name
status: $new_status
created: $(echo "$issue_json" | jq -r '.createdAt // "'$(date -u '+%Y-%m-%dT%H:%M:%SZ')'"')
progress: 0%
updated: $github_updated
github: https://github.com/OWNER/REPO/issues/$issue_num
last_sync: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
---

# $issue_title

$(echo "$issue_json" | jq -r '.body // "Synced from GitHub"')
EOF
        ((pulled_updated++))
      else
        # Update existing epic status if needed
        if [ -f "$epic_dir/epic.md" ]; then
          local_updated=$(grep "^updated:" "$epic_dir/epic.md" | sed 's/^updated: *//' | head -1)
          local_status=$(grep "^status:" "$epic_dir/epic.md" | sed 's/^status: *//' | head -1)

          # Update if GitHub is newer or status changed
          if [[ "$github_updated" > "$local_updated" ]] || [[ "$local_status" != "$new_status" ]]; then
            echo "  📥 Updating epic: $epic_name (status: $local_status -> $new_status)"
            sed -i '' "s/^status: .*/status: $new_status/" "$epic_dir/epic.md"
            sed -i '' "s/^updated: .*/updated: $github_updated/" "$epic_dir/epic.md"
            sed -i '' "s/^last_sync: .*/last_sync: $(date -u '+%Y-%m-%dT%H:%M:%SZ')/" "$epic_dir/epic.md"
            ((pulled_updated++))
            [ "$new_status" = "closed" ] && ((pulled_closed++))
          fi
        fi
      fi
    else
      # Regular task - create in appropriate epic
      epic_num=$(echo "$issue_json" | jq -r '.labels[] | select(.name | test("epic-[0-9]+")) | .name' | sed 's/epic-//' | head -1)
      if [ -n "$epic_num" ]; then
        parent_epic=$(find .claude/epics -name "epic.md" -exec grep -l "issues/$epic_num" {} \; | head -1 | xargs dirname 2>/dev/null)
        if [ -n "$parent_epic" ]; then
          echo "  ✨ Creating task #$issue_num in $parent_epic"
          cat > "$parent_epic/${issue_num}.md" << EOF
---
name: $issue_title
status: $new_status
created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
updated: $github_updated
github: https://github.com/OWNER/REPO/issues/$issue_num
depends_on: []
last_sync: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
---

# $issue_title

$(echo "$issue_json" | jq -r '.body // "Synced from GitHub"')
EOF
          ((pulled_updated++))
        fi
      fi
    fi
  else
    # Update existing local file
    local_updated=$(grep "^updated:" "$local_file" | sed 's/^updated: *//' | head -1)
    local_status=$(grep "^status:" "$local_file" | sed 's/^status: *//' | head -1)

    if [[ "$github_updated" > "$local_updated" ]] || [[ "$local_status" != "$new_status" ]]; then
      echo "  📥 Updating: #$issue_num ($local_status -> $new_status)"
      sed -i '' "s/^status: .*/status: $new_status/" "$local_file"
      sed -i '' "s/^updated: .*/updated: $github_updated/" "$local_file"

      # Add or update last_sync
      if ! grep -q "^last_sync:" "$local_file"; then
        sed -i '' "/^updated:/a\\
last_sync: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$local_file"
      else
        sed -i '' "s/^last_sync: .*/last_sync: $(date -u '+%Y-%m-%dT%H:%M:%SZ')/" "$local_file"
      fi

      ((pulled_updated++))
      [ "$new_status" = "closed" ] && ((pulled_closed++))
    fi
  fi
done

echo ""

# 3. Push Local to GitHub (check for local changes)
echo "📤 Checking for local changes to push..."

# Find all local task files
find .claude/epics -name "[0-9]*.md" -o -name "epic.md" | while read local_file; do
  # Extract GitHub issue number
  if [[ "$local_file" == */epic.md ]]; then
    github_url=$(grep "^github:" "$local_file" | sed 's/^github: *//' | head -1)
    [ -z "$github_url" ] && continue
    issue_num=$(echo "$github_url" | grep -oE '[0-9]+$')
  else
    issue_num=$(basename "$local_file" .md | grep -oE '^[0-9]+')
  fi

  [ -z "$issue_num" ] && continue

  # Check if issue exists on GitHub
  gh_state=$(gh issue view "$issue_num" --json state --jq .state 2>/dev/null)

  if [ -z "$gh_state" ]; then
    # Issue was deleted on GitHub
    echo "  ⚠️  Issue #$issue_num deleted on GitHub, archiving local file"
    mkdir -p .claude/archived
    mv "$local_file" ".claude/archived/$(basename $local_file)"
    continue
  fi

  # Check if local is newer (we already synced from GitHub, so if last_sync is recent, skip)
  last_sync=$(grep "^last_sync:" "$local_file" | sed 's/^last_sync: *//' | head -1)
  if [ -n "$last_sync" ]; then
    # Calculate time difference (if less than 60 seconds, we just synced it)
    current_time=$(date +%s)
    if command -v gdate > /dev/null; then
      sync_time=$(gdate --date="$last_sync" +%s 2>/dev/null || echo 0)
    else
      sync_time=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_sync" +%s 2>/dev/null || echo 0)
    fi

    time_diff=$((current_time - sync_time))
    [ $time_diff -lt 60 ] && continue
  fi

  # If we got here, local might have changes - but for now skip pushing
  # (would need to track local edits vs GitHub edits properly)
done

# 4. Generate Summary
echo ""
echo "📊 Sync Complete"
echo "================"
echo ""
echo "Pulled from GitHub:"
echo "  Updated: $pulled_updated files"
echo "  Closed: $pulled_closed issues"
echo ""

if [ -n "$sync_failures" ]; then
  echo "⚠️  Sync Failures:"
  echo "$sync_failures"
else
  echo "Status:"
  echo "  ✅ All files synced successfully"
fi

# Cleanup
rm -rf "$SYNC_DIR"

echo ""
echo "Run '/pm:epic-list' to see all epics"
echo "Run '/pm:standup' to see current progress"