#!/bin/bash

echo "📅 Daily Standup - $(date '+%Y-%m-%d')"
echo "================================"
echo ""

today=$(date '+%Y-%m-%d')

echo "Getting status..."
echo ""
echo ""

echo "📝 Today's Activity:"
echo "===================="
echo ""

# Find files modified today
recent_files=$(find .claude -name "*.md" -mtime -1 2>/dev/null)

if [ -n "$recent_files" ]; then
  # Count by type
  prd_count=$(echo "$recent_files" | grep -c "/prds/" || true)
  epic_count=$(echo "$recent_files" | grep -c "/epic.md" || true)
  task_count=$(echo "$recent_files" | grep -c "/[0-9]*.md" || true)
  update_count=$(echo "$recent_files" | grep -c "/updates/" || true)

  # Ensure counts are valid integers
  prd_count=${prd_count:-0}
  epic_count=${epic_count:-0}
  task_count=${task_count:-0}
  update_count=${update_count:-0}

  [ "$prd_count" -gt 0 ] && echo "  • Modified $prd_count PRD(s)"
  [ "$epic_count" -gt 0 ] && echo "  • Updated $epic_count epic(s)"
  [ "$task_count" -gt 0 ] && echo "  • Worked on $task_count task(s)"
  [ "$update_count" -gt 0 ] && echo "  • Posted $update_count progress update(s)"
else
  echo "  No activity recorded today"
fi

echo ""
echo "🔄 Currently In Progress:"
# Show active work items
for updates_dir in .claude/epics/*/updates/*/; do
  [ -d "$updates_dir" ] || continue
  if [ -f "$updates_dir/progress.md" ]; then
    issue_num=$(basename "$updates_dir")
    epic_name=$(basename $(dirname $(dirname "$updates_dir")))
    completion=$(grep "^completion:" "$updates_dir/progress.md" | head -1 | sed 's/^completion: *//')

    # Get issue title from GitHub
    issue_title=$(gh issue view "$issue_num" --json title --jq .title 2>/dev/null || echo "Unknown")

    echo "  • #$issue_num: $issue_title"
    echo "    Epic: $epic_name | Progress: ${completion:-0%}"
  fi
done

echo ""
echo "⏭️ Next Available Tasks:"
# Show top 3 available tasks
count=0
for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue

  # Check if the epic itself is closed/completed
  epic_status=$(grep "^status:" "$epic_dir/epic.md" 2>/dev/null | head -1 | sed 's/^status: *//')
  if [ "$epic_status" = "completed" ] || [ "$epic_status" = "closed" ]; then
    continue  # Skip tasks from closed/completed epics
  fi

  for task_file in "$epic_dir"[0-9]*.md; do
    [ -f "$task_file" ] || continue
    status=$(grep "^status:" "$task_file" | head -1 | sed 's/^status: *//')
    [ "$status" != "open" ] && [ -n "$status" ] && continue

    deps=$(grep "^depends_on:" "$task_file" | head -1 | sed 's/^depends_on: *\[//' | sed 's/\]//')
    if [ -z "$deps" ] || [ "$deps" = "depends_on:" ]; then
      task_name=$(grep "^name:" "$task_file" | head -1 | sed 's/^name: *//')
      task_num=$(basename "$task_file" .md)

      # If it's an analysis file or regular task
      if [[ "$task_num" == *"-analysis" ]]; then
        issue_num=${task_num%-analysis}
        issue_title=$(gh issue view "$issue_num" --json title --jq .title 2>/dev/null || echo "$task_name")
        echo "  • #$task_num: Analysis for \"$issue_title\""
      else
        # Get GitHub issue title if it's a numeric issue
        if [[ "$task_num" =~ ^[0-9]+$ ]]; then
          issue_title=$(gh issue view "$task_num" --json title --jq .title 2>/dev/null || echo "$task_name")
          echo "  • #$task_num: $issue_title"
        else
          echo "  • #$task_num: $task_name"
        fi
      fi

      ((count++))
      [ $count -ge 3 ] && break 2
    fi
  done
done

echo ""
echo "📊 Quick Stats:"
total_tasks=$(find .claude/epics -name "[0-9]*.md" 2>/dev/null | wc -l)
open_tasks=$(find .claude/epics -name "[0-9]*.md" -exec grep -l "^status: *open" {} \; 2>/dev/null | wc -l)
closed_tasks=$(find .claude/epics -name "[0-9]*.md" -exec grep -l "^status: *closed" {} \; 2>/dev/null | wc -l)
echo "  Tasks: $open_tasks open, $closed_tasks closed, $total_tasks total"

exit 0
