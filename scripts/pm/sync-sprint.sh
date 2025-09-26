#!/bin/bash

echo "🏃 E2E Captive Portal Sprint Sync"
echo "=================================="
echo ""

# Update all epic statuses based on GitHub
echo "📊 Sprint Board Status:"
echo ""

# Week 1 - Current Sprint (should be in progress)
echo "📅 WEEK 1 (Current Sprint - Sept 23-27):"
echo "----------------------------------------"
for issue in 50 52 53 54 43 44; do
  data=$(gh issue view $issue --json number,title,state 2>/dev/null)
  if [ $? -eq 0 ]; then
    state=$(echo "$data" | jq -r '.state')
    title=$(echo "$data" | jq -r '.title')

    # Update local status
    if [ "$state" = "CLOSED" ]; then
      local_status="completed"
      icon="✅"
    elif [ "$issue" = "52" ] || [ "$issue" = "43" ]; then
      local_status="in-progress"
      icon="🚧"
    else
      local_status="open"
      icon="⭕"
    fi

    echo "  $icon #$issue: $title"

    # Update local files
    if [ "$issue" = "50" ]; then
      sed -i '' "s/^status: .*/status: completed/" .claude/epics/issue-50/epic.md 2>/dev/null
    elif [ "$issue" = "52" ]; then
      sed -i '' "s/^status: .*/status: in-progress/" .claude/epics/issue-52/epic.md 2>/dev/null
    elif [ "$issue" = "53" ]; then
      sed -i '' "s/^status: .*/status: open/" .claude/epics/issue-53/epic.md 2>/dev/null
    elif [ "$issue" = "54" ]; then
      sed -i '' "s/^status: .*/status: open/" .claude/epics/issue-54/epic.md 2>/dev/null
    elif [ "$issue" = "43" ]; then
      sed -i '' "s/^status: .*/status: in-progress/" .claude/epics/issue-43/epic.md 2>/dev/null
    fi
  fi
done

echo ""
echo "📅 WEEK 2 (Sept 30 - Oct 4):"
echo "----------------------------"
for issue in 51 37 47 48; do
  data=$(gh issue view $issue --json number,title,state 2>/dev/null)
  if [ $? -eq 0 ]; then
    state=$(echo "$data" | jq -r '.state')
    title=$(echo "$data" | jq -r '.title')
    icon="⏳"
    echo "  $icon #$issue: $title"

    # These should be in backlog/planning
    if [ "$issue" = "51" ]; then
      sed -i '' "s/^status: .*/status: backlog/" .claude/epics/issue-51/epic.md 2>/dev/null
    elif [ "$issue" = "37" ]; then
      sed -i '' "s/^status: .*/status: backlog/" .claude/epics/e2e-captive-portal/37.md 2>/dev/null
    fi
  fi
done

echo ""
echo "📅 WEEK 3 (Oct 7-11):"
echo "--------------------"
for issue in 38 39; do
  data=$(gh issue view $issue --json number,title,state 2>/dev/null)
  if [ $? -eq 0 ]; then
    title=$(echo "$data" | jq -r '.title')
    icon="📋"
    echo "  $icon #$issue: $title"

    # Update to backlog
    sed -i '' "s/^status: .*/status: backlog/" .claude/epics/e2e-captive-portal/${issue}.md 2>/dev/null
  fi
done

echo ""
echo "📅 WEEK 4 (Oct 14-18):"
echo "---------------------"
issue=55
data=$(gh issue view $issue --json number,title,state 2>/dev/null)
if [ $? -eq 0 ]; then
  title=$(echo "$data" | jq -r '.title')
  icon="🎯"
  echo "  $icon #$issue: $title"
  sed -i '' "s/^status: .*/status: backlog/" .claude/epics/issue-55/epic.md 2>/dev/null
fi

echo ""
echo "📈 Progress Summary:"
echo "-------------------"

# Count statuses
completed=$(gh issue list --repo OWNER/REPO --state closed --label "epic" --json number | jq 'length')
in_progress=2  # We know #52 and #43 are in progress
todo=$(gh issue list --repo OWNER/REPO --state open --label "epic" --json number | jq 'length')

echo "  ✅ Completed: $completed epics"
echo "  🚧 In Progress: $in_progress epics (#52, #43)"
echo "  ⭕ To Do: $todo epics"
echo ""

# Priority order for Week 1
echo "🎯 Current Week Priority Order:"
echo "-------------------------------"
echo "  1. #43 - Configure RADIUS for external auth (IN PROGRESS)"
echo "  2. #52 - Auth Backend - RADIUS Integration (IN PROGRESS)"
echo "  3. #44 - Setup session management (TODO)"
echo "  4. #53 - Portal Redirect - Clean UX Flow (TODO)"
echo "  5. #54 - Auth Frontend - MetaMask/Privy UI (TODO)"
echo ""

echo "✅ Sprint sync complete!"
echo ""
echo "Next steps:"
echo "  • Complete #43 and #52 (currently in progress)"
echo "  • Start #44 (session management)"
echo "  • Review critical path items for Week 2"