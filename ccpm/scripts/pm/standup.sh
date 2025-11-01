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
  # Count by type (grep -c outputs 0 when no matches, so no need for || echo 0)
  prd_count=$(echo "$recent_files" | grep -c "/prds/")
  epic_count=$(echo "$recent_files" | grep -c "/epic.md")
  task_count=$(echo "$recent_files" | grep -c "/[0-9][0-9]*.md")
  update_count=$(echo "$recent_files" | grep -c "/updates/")

  [ "$prd_count" -gt 0 ] && echo "  • Modified $prd_count PRD(s)"
  [ "$epic_count" -gt 0 ] && echo "  • Updated $epic_count epic(s)"
  [ "$task_count" -gt 0 ] && echo "  • Worked on $task_count task(s)"
  [ "$update_count" -gt 0 ] && echo "  • Posted $update_count progress update(s)"
else
  echo "  No activity recorded today"
fi

echo ""
echo "🔄 Currently In Progress:"
# Show active work items (check task files for in-progress status)
in_progress_found=false

# First, check epic-level work (epic.md files with active status)
for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  epic_file="$epic_dir/epic.md"
  [ -f "$epic_file" ] || continue

  status=$(grep "^status:" "$epic_file" | head -1 | sed 's/^status: *//')
  # Consider in-progress, testing as active work
  if [ "$status" = "in-progress" ] || [ "$status" = "testing" ]; then
    epic_name=$(basename "$epic_dir")
    github_url=$(grep "^github:" "$epic_file" | head -1 | sed 's/^github: *//')
    issue_num=$(echo "$github_url" | grep -oE '[0-9]+$')
    progress=$(grep "^progress:" "$epic_file" | head -1 | sed 's/^progress: *//')

    if [ -n "$issue_num" ]; then
      echo "  • #$issue_num [EPIC] ($epic_name) - $status ($progress)"
      in_progress_found=true
    fi
  fi
done

# Then, check task-level work
for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  epic_name=$(basename "$epic_dir")
  for task_file in "$epic_dir"/[0-9]*.md; do
    [ -f "$task_file" ] || continue
    status=$(grep "^status:" "$task_file" | head -1 | sed 's/^status: *//')
    # Handle both in-progress (hyphen) and in_progress (underscore) formats
    if [ "$status" = "in-progress" ] || [ "$status" = "in_progress" ]; then
      task_name=$(grep "^name:" "$task_file" | head -1 | sed 's/^name: *//')
      task_num=$(basename "$task_file" .md | grep -oE '^[0-9]+')
      echo "  • #$task_num [TASK] ($epic_name) - $task_name"
      in_progress_found=true
    fi
  done
done
[ "$in_progress_found" = false ] && echo "  (none)"

echo ""
echo "🚫 Blocked Tasks:"
# Show blocked tasks
blocked_found=false
for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  epic_name=$(basename "$epic_dir")
  for task_file in "$epic_dir"/[0-9]*.md; do
    [ -f "$task_file" ] || continue
    status=$(grep "^status:" "$task_file" | head -1 | sed 's/^status: *//')
    if [ "$status" = "blocked" ]; then
      task_name=$(grep "^name:" "$task_file" | head -1 | sed 's/^name: *//')
      task_num=$(basename "$task_file" .md)
      echo "  • #$task_num - $task_name"
      blocked_found=true
    fi
  done
done
[ "$blocked_found" = false ] && echo "  (none)"

echo ""
echo "⏭️ Next Available Tasks:"
# Show top 3 available tasks (backlog status, no dependencies)
count=0
for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  for task_file in "$epic_dir"/[0-9]*.md; do
    [ -f "$task_file" ] || continue
    status=$(grep "^status:" "$task_file" | head -1 | sed 's/^status: *//')
    # Only show backlog tasks (available to start)
    if [ "$status" != "backlog" ]; then
      continue
    fi

    # Extract dependencies from task file
    deps_line=$(grep "^depends_on:" "$task_file" | head -1)
    if [ -n "$deps_line" ]; then
      deps=$(echo "$deps_line" | sed 's/^depends_on: *//')
      deps=$(echo "$deps" | sed 's/^\[//' | sed 's/\]$//')
      # Trim whitespace and handle empty cases
      deps=$(echo "$deps" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      [ -z "$deps" ] && deps=""
    else
      deps=""
    fi
    if [ -z "$deps" ] || [ "$deps" = "depends_on:" ]; then
      task_name=$(grep "^name:" "$task_file" | head -1 | sed 's/^name: *//')
      task_num=$(basename "$task_file" .md)
      echo "  • #$task_num - $task_name"
      ((count++))
      [ $count -ge 3 ] && break 2
    fi
  done
done

echo ""
echo "📊 Quick Stats:"
# Count task-level work (handle both hyphen and underscore formats)
total_tasks=$(find .claude/epics -name "[0-9]*.md" ! -name "*-analysis.md" 2>/dev/null | wc -l)
open_tasks=$(find .claude/epics -name "[0-9]*.md" ! -name "*-analysis.md" -exec grep -l "^status: *\(backlog\|in-progress\|in_progress\)" {} \; 2>/dev/null | wc -l)
closed_tasks=$(find .claude/epics -name "[0-9]*.md" ! -name "*-analysis.md" -exec grep -l "^status: *\(closed\|completed\)" {} \; 2>/dev/null | wc -l)

# Count epic-level work
total_epics=$(find .claude/epics -name "epic.md" 2>/dev/null | wc -l)
open_epics=$(find .claude/epics -name "epic.md" -exec grep -l "^status: *\(backlog\|in-progress\|testing\)" {} \; 2>/dev/null | wc -l)
closed_epics=$(find .claude/epics -name "epic.md" -exec grep -l "^status: *\(closed\|completed\)" {} \; 2>/dev/null | wc -l)

echo "  Tasks: $open_tasks open, $closed_tasks closed, $total_tasks total"
echo "  Epics: $open_epics open, $closed_epics closed, $total_epics total"

exit 0
