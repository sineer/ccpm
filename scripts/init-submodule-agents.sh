#!/bin/bash

echo "🚀 Initializing Submodule AI Agents"
echo "===================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# List of submodules to process
SUBMODULES=(
  "images/ubi-proxy"
  "images/openwisp-radius"
  "images/openwisp-users"
  "images/openwisp_wifi-login-page"
)

# Step 1: Sync CCPM improvements to all submodules
echo -e "${BLUE}📋 Step 1: Syncing CCPM Scripts${NC}"
echo "--------------------------------"

for submodule in "${SUBMODULES[@]}"; do
  echo -e "Processing ${YELLOW}$submodule${NC}..."

  # Create .claude structure if it doesn't exist
  mkdir -p "$submodule/.claude/scripts/pm"
  mkdir -p "$submodule/.claude/epics"
  mkdir -p "$submodule/.claude/prds"

  # Copy improved scripts (preserve existing if they exist)
  if [ -d "$submodule/.claude/scripts/pm" ]; then
    # Copy new sync scripts
    cp .claude/scripts/pm/sync*.sh "$submodule/.claude/scripts/pm/" 2>/dev/null

    # Update standup with improvements
    if [ -f ".claude/scripts/pm/standup.sh" ]; then
      cp .claude/scripts/pm/standup.sh "$submodule/.claude/scripts/pm/standup.sh"
      echo -e "  ${GREEN}✓${NC} Updated standup.sh with GitHub integration"
    fi

    # Copy any missing scripts
    for script in .claude/scripts/pm/*.sh; do
      script_name=$(basename "$script")
      if [ ! -f "$submodule/.claude/scripts/pm/$script_name" ]; then
        cp "$script" "$submodule/.claude/scripts/pm/"
        echo -e "  ${GREEN}✓${NC} Added $script_name"
      fi
    done
  fi
done

echo ""

# Step 2: Create specialized CLAUDE.md for submodules that need it
echo -e "${BLUE}📝 Step 2: Creating Specialized CLAUDE.md Files${NC}"
echo "-----------------------------------------------"

# openwisp-radius specialization
if [ ! -f "images/openwisp-radius/.claude/CLAUDE.md" ] || [ ! -s "images/openwisp-radius/.claude/CLAUDE.md" ]; then
  cat > "images/openwisp-radius/.claude/CLAUDE.md" << 'EOF'
# CLAUDE.md - OpenWISP RADIUS Agent

You are the RADIUS Authentication Expert for the OpenWISP captive portal system.

## Primary Mission
Implement Privy JWT token validation and session management for Web3 authentication.

## Current Sprint Tasks
- #43: Configure RADIUS for external auth (30% complete)
- #44: Setup session management
- #47: Implement RADIUS callback handler

## Domain Expertise
- FreeRADIUS configuration and scripting
- Django REST Framework for API endpoints
- JWT token validation and parsing
- Session timeout management
- MAC address authentication

## Key Integration Points
- Receives: JWT tokens from wifi-login-page
- Validates: Against Privy API
- Creates: User sessions in OpenWISP
- Triggers: Router unlock via ubi-proxy

## Testing Requirements
- Unit tests for token validation
- Integration tests with Privy API
- Session timeout tests
- MAC address capture tests

## Commands
- `/pm:start 43` - Continue RADIUS configuration
- `/pm:test` - Run authentication tests
- `/pm:sync` - Sync with parent repo

## Next Actions
1. Complete external auth configuration
2. Test JWT validation flow
3. Implement session management
EOF
  echo -e "  ${GREEN}✓${NC} Created openwisp-radius CLAUDE.md"
fi

# wifi-login-page specialization
if [ ! -f "images/openwisp_wifi-login-page/.claude/CLAUDE.md" ] || [ ! -s "images/openwisp_wifi-login-page/.claude/CLAUDE.md" ]; then
  cat > "images/openwisp_wifi-login-page/.claude/CLAUDE.md" << 'EOF'
# CLAUDE.md - WiFi Login Page UI Agent

You are the Frontend UI Expert for the captive portal authentication interface.

## Primary Mission
Create mobile-optimized MetaMask/Privy authentication flow for WiFi access.

## Current Sprint Tasks
- #54: Auth Frontend - MetaMask/Privy UI
- #53: Portal Redirect - Clean UX Flow

## Domain Expertise
- React/Next.js development
- Privy SDK integration
- MetaMask wallet connection
- Mobile-first responsive design
- Captive portal detection

## Key Integration Points
- Detects: Captive portal redirect
- Connects: MetaMask wallet via Privy
- Sends: JWT token to openwisp-radius
- Displays: Connection status and errors

## Testing Requirements
- Cross-browser compatibility (Chrome, Safari, Firefox)
- Mobile device testing (iOS, Android)
- MetaMask connection tests
- Error handling scenarios

## Commands
- `/pm:start 54` - Begin Privy integration
- `/pm:test` - Run UI tests
- `/pm:sync` - Sync with parent repo

## Next Actions
1. Integrate Privy SDK
2. Create MetaMask connection flow
3. Implement mobile-optimized UI
EOF
  echo -e "  ${GREEN}✓${NC} Created wifi-login-page CLAUDE.md"
fi

echo ""

# Step 3: Initialize task tracking for active submodules
echo -e "${BLUE}🎯 Step 3: Initializing Task Tracking${NC}"
echo "-------------------------------------"

# Create task file for openwisp-radius #43
if [ ! -f "images/openwisp-radius/.claude/epics/radius-integration/43.md" ]; then
  mkdir -p "images/openwisp-radius/.claude/epics/radius-integration"
  cat > "images/openwisp-radius/.claude/epics/radius-integration/43.md" << 'EOF'
---
name: Configure RADIUS for external auth
status: in-progress
created: 2025-09-26T16:00:00Z
updated: 2025-09-26T16:00:00Z
github: https://github.com/Ubi-Tel/PROJECT_NAME/issues/43
progress: 30%
---

# Task: Configure RADIUS for external auth

## Current Status
Configuring FreeRADIUS to accept JWT tokens from Privy authentication.

## Completed
- Initial RADIUS configuration
- Research on external auth modules

## In Progress
- JWT validation endpoint
- Token parsing logic

## Next Steps
- Complete rlm_rest configuration
- Test with sample JWT
- Document configuration
EOF
  echo -e "  ${GREEN}✓${NC} Created task tracking for openwisp-radius #43"
fi

# Create task file for wifi-login-page #54
if [ ! -f "images/openwisp_wifi-login-page/.claude/epics/privy-integration/54.md" ]; then
  mkdir -p "images/openwisp_wifi-login-page/.claude/epics/privy-integration"
  cat > "images/openwisp_wifi-login-page/.claude/epics/privy-integration/54.md" << 'EOF'
---
name: Auth Frontend - MetaMask/Privy UI
status: open
created: 2025-09-26T16:00:00Z
updated: 2025-09-26T16:00:00Z
github: https://github.com/Ubi-Tel/PROJECT_NAME/issues/54
progress: 0%
---

# Task: Auth Frontend - MetaMask/Privy UI

## Description
Implement Privy SDK with MetaMask wallet connection for captive portal authentication.

## Acceptance Criteria
- [ ] Privy SDK integrated
- [ ] MetaMask connection flow
- [ ] Mobile-optimized UI
- [ ] Error handling
- [ ] Loading states

## Dependencies
- Privy API credentials
- MetaMask mobile app
EOF
  echo -e "  ${GREEN}✓${NC} Created task tracking for wifi-login-page #54"
fi

echo ""

# Step 4: Create cross-module sync script
echo -e "${BLUE}🔄 Step 4: Creating Cross-Module Sync${NC}"
echo "-------------------------------------"

cat > ".claude/scripts/pm/sync-submodules.sh" << 'EOF'
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
EOF

chmod +x .claude/scripts/pm/sync-submodules.sh
echo -e "  ${GREEN}✓${NC} Created sync-submodules.sh"

echo ""
echo -e "${GREEN}✨ Submodule AI Agents Initialized!${NC}"
echo ""
echo "Next steps:"
echo "  1. cd images/openwisp-radius && /pm:start 43"
echo "  2. cd images/ubi-proxy && /pm:test-runner"
echo "  3. cd images/openwisp_wifi-login-page && /pm:start 54"
echo ""
echo "Run '/pm:sync-submodules' to check all submodule status"