#!/bin/bash

echo "🔄 Syncing All Submodule Status"
echo "================================"
echo ""

# Get the git root directory (if in a git repo)
if git rev-parse --git-dir > /dev/null 2>&1; then
  GIT_ROOT=$(git rev-parse --show-toplevel)
else
  GIT_ROOT="."
fi

# Collect status from each submodule
for submodule in images/ubi-proxy images/openwisp-radius images/openwisp-users images/openwisp_wifi-login-page MCP/just-do-it; do
  if [ -d "$GIT_ROOT/$submodule/.claude" ]; then
    echo "📦 $submodule:"
    if [ -f "$GIT_ROOT/$submodule/.claude/scripts/pm/standup.sh" ]; then
      echo "  Running standup..."
      (cd "$GIT_ROOT/$submodule" && bash .claude/scripts/pm/standup.sh 2>/dev/null | grep -E "(In Progress|Next Available|Quick Stats)" -A 3 | head -10)
    else
      echo "  No CCPM status available"
    fi
    echo ""
  fi
done

echo "✅ Submodule sync complete"
