#!/bin/bash

echo "🔄 Syncing All Submodule Status"
echo "================================"
echo ""

# Collect status from each submodule
for submodule in images/ubi-proxy images/openwisp-radius images/openwisp-users images/openwisp_wifi-login-page; do
  if [ -d "$submodule/.claude" ]; then
    echo "📦 $submodule:"
    if [ -f "$submodule/.claude/scripts/pm/status.sh" ]; then
      (cd "$submodule" && bash .claude/scripts/pm/status.sh 2>/dev/null | head -5)
    else
      echo "  No CCPM status available"
    fi
    echo ""
  fi
done

echo "✅ Submodule sync complete"
