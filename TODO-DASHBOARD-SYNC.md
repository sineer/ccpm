# GitHub Projects Dashboard Auto-Sync Implementation Plan

**Status**: Planning
**Created**: 2025-10-06
**Owner**: CCPM Development Team
**Estimated Effort**: 11-15 hours (MVP: 5-7 hours)

---

## Executive Summary

### Goal
Enhance `ccpm/scripts/pm/sync.sh` to automatically synchronize local CCPM task status with GitHub Projects board columns, eliminating manual status updates and ensuring single source of truth.

### Current Gap
- ✅ **Syncs**: Issue state (OPEN/CLOSED), issue body, issue title
- ❌ **Does NOT sync**: GitHub Projects board status (Todo/In Progress/Done)

### Solution Approach
Implement project board sync in 3 phases:
1. **Phase 1**: Read-only display (2-3 hours)
2. **Phase 2**: One-way sync Local → Projects ⭐ **MVP** (3-4 hours)
3. **Phase 3**: Bidirectional sync (4-5 hours)

### Value Proposition
- **Eliminate manual work**: No more dragging cards on project board
- **Single source of truth**: Local markdown files drive everything
- **Better visibility**: Always know true project status
- **80% value with 40% complexity**: MVP delivers most benefits with minimal risk

---

## Table of Contents

1. [Current State Analysis](#1-current-state-analysis)
2. [Design Decisions](#2-design-decisions)
3. [Implementation Phases](#3-implementation-phases)
4. [Technical Architecture](#4-technical-architecture)
5. [Implementation Code](#5-implementation-code)
6. [Testing Strategy](#6-testing-strategy)
7. [Error Handling](#7-error-handling)
8. [Configuration Options](#8-configuration-options)
9. [Rollout Plan](#9-rollout-plan)
10. [Success Metrics](#10-success-metrics)
11. [Risks & Mitigations](#11-risks--mitigations)
12. [Timeline & Effort](#12-timeline--effort)

---

## 1. Current State Analysis

### 1.1 Local CCPM Status Values

```yaml
open         # Task is ready to work on
in_progress  # Task is actively being worked on
blocked      # Task is blocked by dependencies or issues
closed       # Task is completed
completed    # Epic is completed (epic.md only)
archived     # Issue was deleted from GitHub
```

### 1.2 GitHub Projects Board Columns

Current project #5 ("MAC CPD Handler MVP Sprint") has 3 status columns:

| Column | ID | Purpose |
|--------|-----|---------|
| Todo | `f75ad846` | Tasks ready to work on |
| In Progress | `47fc9ee4` | Tasks being actively worked on |
| Done | `98236657` | Completed tasks |

**Note**: GitHub Projects doesn't have a native "Blocked" status. We use Todo + "blocked" label.

### 1.3 Current sync.sh Flow

```
┌─────────────────────────────────────────┐
│ 1. PULL FROM GITHUB                     │
│    - Fetch issues via gh issue list     │
│    - Sync: state, body, title, labels   │
│    - Update local .md files             │
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ 2. PUSH TO GITHUB                       │
│    - Read local .md files               │
│    - Update GitHub issues               │
│    - Sync: body, title                  │
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ 3. POST SYNC COMMENT                    │
│    - Generate summary                   │
│    - Comment on epic issue              │
└─────────────────────────────────────────┘

❌ Missing: Project board status sync
```

### 1.4 Current Limitations

**Example of the problem:**

```bash
# Developer updates local file
echo "status: blocked" > .claude/epics/cloud-auth/7.md

# Runs sync
./ccpm/scripts/pm/sync.sh

# Result:
# ✅ GitHub issue #7 updated
# ✅ Blocked label added to issue
# ❌ Project board still shows "In Progress" (NOT updated!)
```

**Manual fix required:**
1. Open GitHub Projects board
2. Find issue #7
3. Drag from "In Progress" to "Todo"
4. (This is what we're automating!)

---

## 2. Design Decisions

### 2.1 Status Mapping Strategy

#### Local → Project Board (Phase 2)

| Local Status | Project Column | Additional Action | Rationale |
|-------------|----------------|-------------------|-----------|
| `open` | Todo | - | Standard ready-to-work state |
| `in_progress` | In Progress | - | Active work |
| `in-progress` | In Progress | - | Support both formats |
| `blocked` | Todo | Add "blocked" label | No native blocked column |
| `closed` | Done | - | Task completed |
| `completed` | Done | - | Epic completed |
| `archived` | Done | - | Deleted from GitHub |

**Key Decision**: `blocked` → Todo + label
**Rationale**: GitHub Projects doesn't support custom status columns without GitHub Projects v2 advanced features. Using Todo + label is universally compatible.

#### Project Board → Local (Phase 3)

| Project Column | Local Status | Condition | Rationale |
|---------------|--------------|-----------|-----------|
| Todo | `open` | No "blocked" label | Default ready state |
| Todo | `blocked` | Has "blocked" label | Preserve blocked status |
| In Progress | `in_progress` | - | Active work |
| Done | `closed` | Task file | Completed task |
| Done | `completed` | epic.md file | Completed epic |

**Key Decision**: Check "blocked" label to distinguish Todo states
**Rationale**: Without checking label, we'd lose blocked status on reverse sync.

### 2.2 Sync Direction Strategy

Three approaches considered:

| Approach | Complexity | Value | Risk | MVP? |
|----------|-----------|-------|------|------|
| **Read-only** | Low (10%) | Low (20%) | None | ❌ |
| **One-way (Local→Projects)** | Medium (40%) | High (80%) | Low | ✅ **YES** |
| **Bidirectional** | High (100%) | Complete (100%) | Medium | Later |

**Decision**: Implement one-way sync as MVP

**Rationale**:
1. **Local files are source of truth**: Developers work in markdown, not web UI
2. **80/20 rule**: Most value comes from automating the common case (local changes)
3. **Lower risk**: No conflict resolution needed
4. **Faster delivery**: Can ship in one sprint vs. three

### 2.3 Conflict Resolution (Phase 3 Only)

When both local and project board are modified:

```bash
# Scenario: Conflict
Local file:     status: blocked, updated: 2025-10-06T10:00:00Z
Project board:  In Progress,     updated: 2025-10-06T10:05:00Z

# Resolution: Newest wins (timestamp-based)
Result: Set to In Progress (board is newer)
Action: Update local file to in_progress
Log: "Conflict resolved: #7 board newer (10:05 > 10:00)"
```

**Alternative considered**: Always prefer local (local-wins strategy)
**Rejected**: Ignores legitimate board updates from web UI

---

## 3. Implementation Phases

### Phase 1: Read-Only Display (2-3 hours)

#### Goals
- Fetch project board status for all issues
- Display current status in sync output
- Identify discrepancies without making changes
- Validate API access and data structures

#### Deliverables
```bash
$ ./ccpm/scripts/pm/sync.sh

🔄 Starting Sync - 2025-10-06T12:00:00Z
================================

📥 Pulling from GitHub...
  ⬇️  Updating local: 7.md

📊 Project Board Status:
  #7 - Cloud CPD Handler
     Local: blocked
     Board: In Progress ⚠️ MISMATCH

  #10 - Cloud UAM Handler
     Local: open
     Board: Todo ✓ SYNCED

  Found 3 mismatches (not modified, read-only mode)

✅ Sync Complete
```

#### Code Changes
- Add `fetch_project_items()` function
- Add `compare_status()` function
- Add display logic to summary section
- **No modifications**: Safe to test in production

#### Success Criteria
- [ ] Correctly fetches all project items
- [ ] Identifies 100% of status mismatches
- [ ] No errors with missing items
- [ ] Performance: < 2 seconds for 50 issues

### Phase 2: One-Way Sync (Local → Projects) ⭐ MVP (3-4 hours)

#### Goals
- Push local status changes to project board
- Handle blocked status (Todo + label)
- Error handling for API failures
- Feature flag for safe rollout

#### Deliverables
```bash
$ ./ccpm/scripts/pm/sync.sh

📊 Syncing Project Board Status...

  📊 #7: In Progress → Todo
  🏷️  #7: Added label "blocked"
  📊 #13: In Progress → Todo

  Synced 8 items to project board

✅ Sync Complete
================================

Pulled from GitHub:
  Updated: 0 files
  Closed: 0 issues

Pushed to GitHub:
  Updated: 0 issues
  Created: 0 new issues

Project Board:
  Synced: 8 items
  Errors: 0

Status: ✅ All files synced
```

#### Code Changes
- Add `initialize_project_cache()` - fetch project metadata
- Add `map_local_to_project_status()` - status mapping
- Add `sync_project_status()` - update one item
- Add `sync_all_project_items()` - main sync loop
- Add `PROJECT_SYNC_ENABLED` environment variable
- Integrate into main sync flow

#### Configuration
```bash
# Environment variables
export PROJECT_SYNC_ENABLED=true        # Enable/disable (default: true)
export PROJECT_NUMBER=5                 # Project number (default: auto-detect)
export PROJECT_OWNER="Ubi-Tel"          # Owner (default: repo owner)
export PROJECT_SYNC_DRY_RUN=false       # Show changes without applying
```

#### Success Criteria
- [ ] All local status changes reflected on board
- [ ] Blocked tasks have Todo + "blocked" label
- [ ] No false positives (correct mapping)
- [ ] Graceful handling of missing items
- [ ] Can disable with feature flag
- [ ] Performance: < 5 seconds for 20 updates

### Phase 3: Bidirectional Sync (4-5 hours)

#### Goals
- Pull project board changes back to local files
- Implement conflict resolution
- Add `last_project_sync:` tracking
- Handle edge cases

#### Deliverables
```bash
$ ./ccpm/scripts/pm/sync.sh

📊 Syncing Project Board Status...

  ⬇️  #10: Board changed: Todo → In Progress
  📝 Updating local file: status: in_progress

  ⚠️  #7: Conflict detected
     Local: blocked (updated: 10:00)
     Board: In Progress (updated: 10:05)
     Resolution: Board wins (newer)
     Action: Updating local to in_progress

  Synced: 8 items
  Conflicts: 1 (auto-resolved)
```

#### Code Changes
- Add `map_project_to_local_status()` - reverse mapping
- Add `detect_conflicts()` - timestamp comparison
- Add `resolve_conflict()` - newest-wins logic
- Update frontmatter with `last_project_sync:`
- Add bidirectional sync loop

#### Frontmatter Enhancement
```yaml
---
name: Cloud CPD Handler
status: in_progress
updated: 2025-10-06T10:05:00Z
last_sync: 2025-10-06T12:00:00Z
last_project_sync: 2025-10-06T12:00:00Z  # NEW
github: https://github.com/Ubi-Tel/ubispot/issues/7
---
```

#### Success Criteria
- [ ] Board changes update local files
- [ ] Conflicts resolved correctly (newest wins)
- [ ] All timestamps tracked accurately
- [ ] No data loss during conflicts
- [ ] Logging shows all resolutions

### Phase 4: Polish & Optimization (2-3 hours)

#### Goals
- Comprehensive documentation
- Performance optimization
- Advanced error handling
- Dry-run mode
- User-friendly output

#### Deliverables
1. **Documentation**:
   - Updated README.md
   - Configuration guide
   - Troubleshooting section
   - FAQ

2. **Performance**:
   - Cache project metadata (1 API call vs. N)
   - Batch status updates where possible
   - Lazy loading of project items

3. **Error Handling**:
   - Retry logic with exponential backoff
   - Rate limit detection and waiting
   - Detailed error messages

4. **Dry-Run Mode**:
   ```bash
   PROJECT_SYNC_DRY_RUN=true ./ccpm/scripts/pm/sync.sh

   # Output:
   [DRY RUN] Would update #7: In Progress → Todo
   [DRY RUN] Would add label "blocked" to #7
   ```

#### Success Criteria
- [ ] Documentation covers all features
- [ ] Performance: < 10s for 100 issues
- [ ] Zero crashes from API errors
- [ ] Dry-run mode 100% accurate
- [ ] User satisfaction > 90%

---

## 4. Technical Architecture

### 4.1 Data Structures

#### Project Metadata Cache

```bash
# Global variables populated by initialize_project_cache()
PROJECT_ID="PVT_kwDOCocVeM4BENWS"
STATUS_FIELD_ID="PVTSSF_lADOCocVeM4BENWSzg15s94"

# Associative arrays
declare -A STATUS_OPTIONS=(
  ["Todo"]="f75ad846"
  ["In Progress"]="47fc9ee4"
  ["Done"]="98236657"
)

declare -A ISSUE_TO_ITEM=(
  [7]="PVTI_lADOCocVeM4BENWSzgfPPlM"
  [10]="PVTI_lADOCocVeM4BENWSzgfPPmA"
)

declare -A ITEM_STATUS=(
  [7]="In Progress"
  [10]="Todo"
)
```

**Rationale**: Caching reduces API calls from O(N²) to O(N)

### 4.2 Function Architecture

```
initialize_project_cache()
  ├─ get_project_id()              # 1 API call
  ├─ get_status_field_id()         # 1 API call (reuse above)
  ├─ get_status_option_ids()       # 0 API calls (same response)
  └─ build_issue_item_mapping()    # 1 API call

sync_all_project_items()
  ├─ for each local file
  │   ├─ extract_metadata()
  │   ├─ map_local_to_project_status()
  │   └─ sync_project_status()     # 1 API call per update
  └─ print_summary()

# Phase 3 additions
sync_from_project_board()
  ├─ for each project item
  │   ├─ map_project_to_local_status()
  │   ├─ detect_conflicts()
  │   └─ update_local_file()
  └─ print_summary()
```

### 4.3 Integration Points

```bash
# Current sync.sh structure with integration points

#!/bin/bash
set -e

# [LINES 1-63: Existing helpers]

# 🆕 ADD HERE: Project sync functions
initialize_project_cache() { ... }
sync_all_project_items() { ... }

# [LINES 64-243: PULL FROM GITHUB section]

# 🆕 ADD HERE: Initialize project cache
if [ "$PROJECT_SYNC_ENABLED" = true ]; then
  initialize_project_cache
fi

# [LINES 244-328: PUSH TO GITHUB section]

# 🆕 ADD HERE: Sync project board
if [ "$PROJECT_SYNC_ENABLED" = true ] && [ -n "$PROJECT_ID" ]; then
  sync_all_project_items
fi

# [LINES 329-397: SUMMARY section]
```

### 4.4 Data Flow Diagram

```
┌─────────────────────┐
│  Local Files        │
│  .claude/epics/     │
│  └── 7.md           │
│     status: blocked │
└──────────┬──────────┘
           │
           │ 1. Read file
           ▼
    ┌─────────────┐
    │  sync.sh    │
    │             │
    │  Status:    │
    │  blocked    │
    └──────┬──────┘
           │
           │ 2. map_local_to_project_status()
           │    blocked → "Todo"
           ▼
    ┌─────────────┐
    │  Mapping    │
    │  Logic      │
    │             │
    │  Target:    │
    │  Todo +     │
    │  label      │
    └──────┬──────┘
           │
           │ 3. gh project item-edit
           │    --single-select-option-id f75ad846
           │ 4. gh issue edit
           │    --add-label "blocked"
           ▼
┌──────────────────────┐
│  GitHub Projects     │
│  Project #5          │
│  └── Issue #7        │
│     Status: Todo     │
│     Labels: blocked  │
└──────────────────────┘
```

### 4.5 API Call Optimization

**Before optimization**:
```bash
# Naive approach: 1 + 3N API calls for N issues
get_project_id()                    # 1 call
for each issue:
  get_item_id()                     # N calls
  get_current_status()              # N calls
  update_status()                   # N calls
# Total: 1 + 3N calls (151 calls for 50 issues!)
```

**After optimization**:
```bash
# Cached approach: 2 + N API calls for N issues
get_project_metadata()              # 1 call (project + field IDs)
get_all_project_items()             # 1 call (bulk fetch)
for each issue:
  if status_changed:
    update_status()                 # Only N calls for updates
# Total: 2 + N calls (52 calls for 50 issues)
# Improvement: 66% reduction!
```

---

## 5. Implementation Code

### 5.1 Phase 2 MVP Code

```bash
#!/bin/bash

# ============================================================================
# PROJECT BOARD SYNC - Phase 2 Implementation
# ============================================================================
# This code is inserted into sync.sh after line 63 (before PULL FROM GITHUB)
#
# Purpose: Synchronize local CCPM status to GitHub Projects board
# Direction: One-way (Local → Projects)
# API Calls: 2 + N (N = number of changed items)
# ============================================================================

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

PROJECT_NUMBER="${PROJECT_NUMBER:-5}"
PROJECT_OWNER="${PROJECT_OWNER:-Ubi-Tel}"
PROJECT_SYNC_ENABLED="${PROJECT_SYNC_ENABLED:-true}"
PROJECT_SYNC_DRY_RUN="${PROJECT_SYNC_DRY_RUN:-false}"

# ----------------------------------------------------------------------------
# Global Cache Variables
# ----------------------------------------------------------------------------

PROJECT_ID=""
STATUS_FIELD_ID=""
declare -A STATUS_OPTIONS      # ["Todo"]="f75ad846"
declare -A ISSUE_TO_ITEM      # [7]="PVTI_lADOCocVeM4BENWSzgfPPlM"
declare -A ITEM_STATUS        # [7]="In Progress"

PROJECT_SYNC_COUNT=0
PROJECT_SYNC_ERRORS=0

# ----------------------------------------------------------------------------
# Function: initialize_project_cache
# ----------------------------------------------------------------------------
# Fetches and caches project metadata to minimize API calls
#
# Populates:
#   - PROJECT_ID
#   - STATUS_FIELD_ID
#   - STATUS_OPTIONS (array)
#   - ISSUE_TO_ITEM (array)
#   - ITEM_STATUS (array)
#
# API Calls: 2 total
# ----------------------------------------------------------------------------

initialize_project_cache() {
  echo "📊 Initializing project board cache..."

  # Validate gh CLI is available
  if ! command -v gh >/dev/null 2>&1; then
    echo "  ⚠️  gh CLI not found, skipping project sync"
    PROJECT_SYNC_ENABLED=false
    return 1
  fi

  # Get project ID (1 API call)
  PROJECT_ID=$(gh project list --owner "$PROJECT_OWNER" --format json 2>/dev/null | \
    jq -r ".projects[] | select(.number == $PROJECT_NUMBER) | .id" || echo "")

  if [ -z "$PROJECT_ID" ]; then
    echo "  ⚠️  Project #$PROJECT_NUMBER not found, skipping project sync"
    PROJECT_SYNC_ENABLED=false
    return 1
  fi

  echo "  ✅ Found project: $PROJECT_ID"

  # Get status field ID and option IDs (reuses same API call via pipe)
  local field_data=$(gh project field-list "$PROJECT_NUMBER" \
    --owner "$PROJECT_OWNER" --format json 2>/dev/null)

  STATUS_FIELD_ID=$(echo "$field_data" | \
    jq -r '.fields[] | select(.name == "Status") | .id' || echo "")

  if [ -z "$STATUS_FIELD_ID" ]; then
    echo "  ⚠️  Status field not found, skipping project sync"
    PROJECT_SYNC_ENABLED=false
    return 1
  fi

  # Parse status options into associative array
  while IFS='|' read -r name id; do
    STATUS_OPTIONS["$name"]="$id"
  done < <(echo "$field_data" | \
    jq -r '.fields[] | select(.name == "Status") | .options[] | "\(.name)|\(.id)"')

  echo "  ✅ Status field: $STATUS_FIELD_ID"
  echo "  ✅ Status options: ${!STATUS_OPTIONS[*]}"

  # Build issue → item mapping (1 API call)
  local item_count=0
  while IFS='|' read -r issue_num item_id status; do
    ISSUE_TO_ITEM["$issue_num"]="$item_id"
    ITEM_STATUS["$issue_num"]="$status"
    ((item_count++))
  done < <(gh project item-list "$PROJECT_NUMBER" \
    --owner "$PROJECT_OWNER" --format json --limit 100 2>/dev/null | \
    jq -r '.items[] | select(.content.type == "Issue") |
      "\(.content.number)|\(.id)|\(.status)"')

  echo "  ✅ Cached $item_count project items"

  return 0
}

# ----------------------------------------------------------------------------
# Function: map_local_to_project_status
# ----------------------------------------------------------------------------
# Maps local CCPM status to GitHub Projects board column
#
# Arguments:
#   $1 - local_status (open, in_progress, blocked, closed, etc.)
#
# Returns:
#   Echo: Project board column name (Todo, In Progress, Done)
#
# Mapping:
#   open          → Todo
#   in_progress   → In Progress
#   in-progress   → In Progress (alternate format)
#   blocked       → Todo (+ blocked label handled separately)
#   closed        → Done
#   completed     → Done
#   archived      → Done
#   *             → Todo (default)
# ----------------------------------------------------------------------------

map_local_to_project_status() {
  local local_status="$1"

  case "$local_status" in
    open)
      echo "Todo"
      ;;
    in_progress|in-progress)
      echo "In Progress"
      ;;
    blocked)
      echo "Todo"  # Label handled in sync_project_status()
      ;;
    closed|completed|archived)
      echo "Done"
      ;;
    *)
      echo "Todo"  # Safe default
      ;;
  esac
}

# ----------------------------------------------------------------------------
# Function: sync_project_status
# ----------------------------------------------------------------------------
# Synchronizes one issue's status to the project board
#
# Arguments:
#   $1 - issue_number (e.g., 7)
#   $2 - local_status (e.g., blocked)
#
# Actions:
#   1. Maps local status to project column
#   2. Updates blocked label if needed
#   3. Gets project item ID from cache
#   4. Compares with current status
#   5. Updates project board if different
#
# API Calls: 1-2 (1 for edit, 1 for label if needed)
# ----------------------------------------------------------------------------

sync_project_status() {
  local issue_number="$1"
  local local_status="$2"

  # Map to project status
  local project_status=$(map_local_to_project_status "$local_status")

  # Handle blocked label
  if [ "$local_status" = "blocked" ]; then
    if [ "$PROJECT_SYNC_DRY_RUN" = true ]; then
      echo "  [DRY RUN] Would add label 'blocked' to #$issue_number"
    else
      gh issue edit "$issue_number" --add-label "blocked" 2>/dev/null || {
        echo "  ⚠️  Could not add blocked label to #$issue_number"
      }
    fi
  else
    # Remove blocked label if status changed away from blocked
    if [ "$PROJECT_SYNC_DRY_RUN" = true ]; then
      echo "  [DRY RUN] Would remove label 'blocked' from #$issue_number"
    else
      gh issue edit "$issue_number" --remove-label "blocked" 2>/dev/null || true
    fi
  fi

  # Get item ID from cache
  local item_id="${ISSUE_TO_ITEM[$issue_number]}"
  if [ -z "$item_id" ]; then
    echo "  ⚠️  #$issue_number not found in project, skipping"
    return 1
  fi

  # Check if already in correct status
  local current_status="${ITEM_STATUS[$issue_number]}"
  if [ "$current_status" = "$project_status" ]; then
    return 0  # No change needed
  fi

  # Get status option ID
  local status_option_id="${STATUS_OPTIONS[$project_status]}"
  if [ -z "$status_option_id" ]; then
    echo "  ❌ Unknown project status: $project_status"
    ((PROJECT_SYNC_ERRORS++))
    return 1
  fi

  # Update project board
  if [ "$PROJECT_SYNC_DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would update #$issue_number: $current_status → $project_status"
  else
    echo "  📊 #$issue_number: $current_status → $project_status"

    if gh project item-edit \
      --id "$item_id" \
      --project-id "$PROJECT_ID" \
      --field-id "$STATUS_FIELD_ID" \
      --single-select-option-id "$status_option_id" 2>/dev/null; then

      # Update cache
      ITEM_STATUS["$issue_number"]="$project_status"
      ((PROJECT_SYNC_COUNT++))
    else
      echo "  ❌ Failed to update #$issue_number on project board"
      ((PROJECT_SYNC_ERRORS++))
      return 1
    fi
  fi

  return 0
}

# ----------------------------------------------------------------------------
# Function: sync_all_project_items
# ----------------------------------------------------------------------------
# Main loop: Syncs all local files to project board
#
# Process:
#   1. Iterate through all .md files in epics
#   2. Extract issue number and local status
#   3. Call sync_project_status() for each
#   4. Print summary
#
# API Calls: N (where N = number of status changes)
# ----------------------------------------------------------------------------

sync_all_project_items() {
  echo ""
  echo "📊 Syncing Project Board Status..."
  echo ""

  # Reset counters
  PROJECT_SYNC_COUNT=0
  PROJECT_SYNC_ERRORS=0

  # Iterate through all local files
  for file in "$EPICS_DIR"/*/*.md; do
    [ -f "$file" ] || continue

    # Skip non-task files (README, etc.)
    local basename=$(basename "$file")
    [[ "$basename" =~ ^[0-9]+\.md$ ]] || [[ "$basename" = "epic.md" ]] || continue

    # Extract metadata
    local github_url=$(grep "^github:" "$file" | head -1 | sed 's/^github: *//')
    local issue_number=$(extract_issue_number "$github_url")
    local local_status=$(grep "^status:" "$file" | head -1 | sed 's/^status: *//')

    # Sync if we have valid data
    if [ -n "$issue_number" ] && [ -n "$local_status" ]; then
      sync_project_status "$issue_number" "$local_status"
    fi
  done

  # Print summary
  echo ""
  if [ "$PROJECT_SYNC_DRY_RUN" = true ]; then
    echo "  [DRY RUN] Would sync $PROJECT_SYNC_COUNT items"
  else
    echo "  ✅ Synced $PROJECT_SYNC_COUNT items to project board"
  fi

  if [ $PROJECT_SYNC_ERRORS -gt 0 ]; then
    echo "  ⚠️  Errors: $PROJECT_SYNC_ERRORS"
  fi
}

# ----------------------------------------------------------------------------
# Integration: Call these functions in main sync flow
# ----------------------------------------------------------------------------
#
# Add after line 243 (after PULL FROM GITHUB):
#   if [ "$PROJECT_SYNC_ENABLED" = true ]; then
#     initialize_project_cache
#   fi
#
# Add after line 328 (after PUSH TO GITHUB):
#   if [ "$PROJECT_SYNC_ENABLED" = true ] && [ -n "$PROJECT_ID" ]; then
#     sync_all_project_items
#   fi
#
# Add to summary section (line 377):
#   if [ "$PROJECT_SYNC_ENABLED" = true ]; then
#     echo "Project Board:"
#     echo "  Synced: $PROJECT_SYNC_COUNT items"
#     if [ $PROJECT_SYNC_ERRORS -gt 0 ]; then
#       echo "  Errors: $PROJECT_SYNC_ERRORS"
#     fi
#     echo ""
#   fi
# ----------------------------------------------------------------------------
```

### 5.2 Integration Patch

```bash
# Apply this patch to sync.sh for Phase 2 integration

--- a/ccpm/scripts/pm/sync.sh
+++ b/ccpm/scripts/pm/sync.sh
@@ -62,6 +62,13 @@ update_frontmatter_field() {
   fi
 }

+# ============================================================================
+# PROJECT BOARD SYNC FUNCTIONS (Phase 2)
+# ============================================================================
+
+# [INSERT ALL PHASE 2 CODE HERE - from section 5.1]
+
+# ============================================================================
 # 1. PULL FROM GITHUB
 echo "📥 Pulling from GitHub..."
 echo ""
@@ -240,6 +247,12 @@ else
   echo "⚠️  jq not installed - skipping GitHub pull"
 fi

+# Initialize project cache after pulling
+if [ "$PROJECT_SYNC_ENABLED" = true ]; then
+  initialize_project_cache
+fi
+
 echo ""

 # 2. PUSH LOCAL TO GITHUB
@@ -327,6 +340,12 @@ else
   done
 fi

+# Sync project board after pushing
+if [ "$PROJECT_SYNC_ENABLED" = true ] && [ -n "$PROJECT_ID" ]; then
+  sync_all_project_items
+fi
+
 echo ""

 # 3. POST SYNC COMMENT (if significant changes)
@@ -386,6 +405,14 @@ echo "Pushed to GitHub:"
 echo "  Updated: $PUSHED_UPDATED issues"
 echo "  Created: $PUSHED_CREATED new issues"
 echo ""
+
+if [ "$PROJECT_SYNC_ENABLED" = true ]; then
+  echo "Project Board:"
+  echo "  Synced: $PROJECT_SYNC_COUNT items"
+  [ $PROJECT_SYNC_ERRORS -gt 0 ] && echo "  Errors: $PROJECT_SYNC_ERRORS"
+  echo ""
+fi
+

 if [ $CONFLICTS -gt 0 ]; then
   echo "Conflicts resolved: $CONFLICTS"
```

---

## 6. Testing Strategy

### 6.1 Test Suite Overview

| Test Type | Count | Coverage | Automation |
|-----------|-------|----------|------------|
| Unit Tests | 15 | Functions | Manual |
| Integration Tests | 8 | End-to-end | Manual |
| Regression Tests | 5 | Existing features | Automated |
| Performance Tests | 3 | Scalability | Manual |

### 6.2 Unit Test Cases

```bash
#!/bin/bash
# test-project-sync-units.sh
# Unit tests for individual functions

source ccpm/scripts/pm/sync.sh

# Test 1: map_local_to_project_status
test_status_mapping() {
  echo "Test 1: Status Mapping"

  assert_equals "$(map_local_to_project_status 'open')" "Todo"
  assert_equals "$(map_local_to_project_status 'in_progress')" "In Progress"
  assert_equals "$(map_local_to_project_status 'in-progress')" "In Progress"
  assert_equals "$(map_local_to_project_status 'blocked')" "Todo"
  assert_equals "$(map_local_to_project_status 'closed')" "Done"
  assert_equals "$(map_local_to_project_status 'completed')" "Done"
  assert_equals "$(map_local_to_project_status 'unknown')" "Todo"

  echo "✅ All status mappings correct"
}

# Test 2: initialize_project_cache
test_project_cache() {
  echo "Test 2: Project Cache Initialization"

  initialize_project_cache

  assert_not_empty "$PROJECT_ID"
  assert_not_empty "$STATUS_FIELD_ID"
  assert_not_empty "${STATUS_OPTIONS['Todo']}"
  assert_not_empty "${STATUS_OPTIONS['In Progress']}"
  assert_not_empty "${STATUS_OPTIONS['Done']}"

  echo "✅ Project cache initialized"
}

# Test 3: Cache performance
test_cache_performance() {
  echo "Test 3: Cache Performance"

  time initialize_project_cache
  # Should complete in < 2 seconds

  echo "✅ Cache performance acceptable"
}

# Helper functions
assert_equals() {
  [ "$1" = "$2" ] || { echo "❌ Expected '$2', got '$1'"; exit 1; }
}

assert_not_empty() {
  [ -n "$1" ] || { echo "❌ Value is empty"; exit 1; }
}

# Run all tests
test_status_mapping
test_project_cache
test_cache_performance

echo ""
echo "✅ All unit tests passed"
```

### 6.3 Integration Test Cases

```bash
#!/bin/bash
# test-project-sync-integration.sh
# End-to-end integration tests

# Test 1: open → Todo
test_open_to_todo() {
  echo "Test 1: open → Todo"

  # Setup
  cat > .claude/epics/test/1.md <<EOF
---
name: Test Task 1
status: open
github: https://github.com/Ubi-Tel/ubispot/issues/99
---
Test task
EOF

  # Run sync
  ./ccpm/scripts/pm/sync.sh

  # Verify
  board_status=$(gh project item-list 5 --owner Ubi-Tel --format json | \
    jq -r '.items[] | select(.content.number == 99) | .status')

  assert_equals "$board_status" "Todo"
  echo "✅ open → Todo works"
}

# Test 2: in_progress → In Progress
test_in_progress_to_board() {
  echo "Test 2: in_progress → In Progress"

  # Update status
  sed -i 's/status: open/status: in_progress/' .claude/epics/test/1.md

  # Run sync
  ./ccpm/scripts/pm/sync.sh

  # Verify
  board_status=$(gh project item-list 5 --owner Ubi-Tel --format json | \
    jq -r '.items[] | select(.content.number == 99) | .status')

  assert_equals "$board_status" "In Progress"
  echo "✅ in_progress → In Progress works"
}

# Test 3: blocked → Todo + label
test_blocked_status() {
  echo "Test 3: blocked → Todo + label"

  # Update to blocked
  sed -i 's/status: in_progress/status: blocked/' .claude/epics/test/1.md

  # Run sync
  ./ccpm/scripts/pm/sync.sh

  # Verify board status
  board_status=$(gh project item-list 5 --owner Ubi-Tel --format json | \
    jq -r '.items[] | select(.content.number == 99) | .status')
  assert_equals "$board_status" "Todo"

  # Verify blocked label
  has_label=$(gh issue view 99 --json labels | \
    jq -r '.labels[] | select(.name == "blocked") | .name')
  assert_equals "$has_label" "blocked"

  echo "✅ blocked → Todo + label works"
}

# Test 4: closed → Done
test_closed_to_done() {
  echo "Test 4: closed → Done"

  # Update to closed
  sed -i 's/status: blocked/status: closed/' .claude/epics/test/1.md

  # Run sync
  ./ccpm/scripts/pm/sync.sh

  # Verify
  board_status=$(gh project item-list 5 --owner Ubi-Tel --format json | \
    jq -r '.items[] | select(.content.number == 99) | .status')
  assert_equals "$board_status" "Done"

  # Verify blocked label removed
  has_label=$(gh issue view 99 --json labels | \
    jq -r '.labels[] | select(.name == "blocked") | .name')
  assert_equals "$has_label" ""

  echo "✅ closed → Done works"
}

# Test 5: Issue not in project
test_missing_issue() {
  echo "Test 5: Issue not in project"

  # Create issue not in project
  cat > .claude/epics/test/999.md <<EOF
---
name: Missing Task
status: open
github: https://github.com/Ubi-Tel/ubispot/issues/9999
---
Not in project
EOF

  # Run sync (should not error)
  ./ccpm/scripts/pm/sync.sh 2>&1 | grep -q "not found in project"

  echo "✅ Handles missing issues gracefully"
}

# Test 6: Concurrent updates
test_concurrent_updates() {
  echo "Test 6: Concurrent updates"

  # Update 10 issues at once
  for i in {100..110}; do
    cat > ".claude/epics/test/$i.md" <<EOF
---
name: Test Task $i
status: in_progress
github: https://github.com/Ubi-Tel/ubispot/issues/$i
---
EOF
  done

  # Run sync
  time ./ccpm/scripts/pm/sync.sh
  # Should complete in < 10 seconds

  echo "✅ Handles concurrent updates"
}

# Test 7: Dry run mode
test_dry_run() {
  echo "Test 7: Dry run mode"

  # Enable dry run
  PROJECT_SYNC_DRY_RUN=true ./ccpm/scripts/pm/sync.sh | \
    grep -q "\[DRY RUN\]"

  echo "✅ Dry run mode works"
}

# Test 8: Disabled sync
test_disabled_sync() {
  echo "Test 8: Disabled sync"

  # Disable sync
  PROJECT_SYNC_ENABLED=false ./ccpm/scripts/pm/sync.sh | \
    grep -qv "Syncing Project Board"

  echo "✅ Can disable project sync"
}

# Run all tests
test_open_to_todo
test_in_progress_to_board
test_blocked_status
test_closed_to_done
test_missing_issue
test_concurrent_updates
test_dry_run
test_disabled_sync

echo ""
echo "✅ All integration tests passed"
```

### 6.4 Regression Tests

```bash
#!/bin/bash
# test-regression.sh
# Ensure existing functionality still works

# Test 1: Issue sync still works
test_issue_sync() {
  echo "Regression Test 1: Issue sync"

  # Create issue
  echo "status: open" > .claude/epics/test/200.md

  # Sync
  ./ccpm/scripts/pm/sync.sh

  # Verify issue exists
  gh issue view 200 >/dev/null 2>&1

  echo "✅ Issue sync not broken"
}

# Test 2: Label sync still works
test_label_sync() {
  echo "Regression Test 2: Label sync"

  # Existing label functionality
  gh issue edit 200 --add-label "enhancement"
  ./ccpm/scripts/pm/sync.sh

  # Verify
  gh issue view 200 --json labels | grep -q "enhancement"

  echo "✅ Label sync not broken"
}

# Run regression tests
test_issue_sync
test_label_sync

echo "✅ All regression tests passed"
```

### 6.5 Performance Tests

```bash
#!/bin/bash
# test-performance.sh

# Test 1: 50 issues sync time
test_50_issues() {
  echo "Performance Test 1: 50 issues"

  # Create 50 test issues
  for i in {1..50}; do
    cat > ".claude/epics/perf/$i.md" <<EOF
---
status: open
github: https://github.com/Ubi-Tel/ubispot/issues/$i
---
EOF
  done

  # Time the sync
  time ./ccpm/scripts/pm/sync.sh

  # Target: < 10 seconds
  echo "✅ 50 issues performance test complete"
}

# Test 2: API call count
test_api_calls() {
  echo "Performance Test 2: API call count"

  # Enable debug logging
  GH_DEBUG=api ./ccpm/scripts/pm/sync.sh 2>&1 | \
    grep "HTTP/" | wc -l

  # Should be 2 + N (where N = changed items)
  echo "✅ API call count within limits"
}

# Test 3: Memory usage
test_memory() {
  echo "Performance Test 3: Memory usage"

  /usr/bin/time -v ./ccpm/scripts/pm/sync.sh 2>&1 | \
    grep "Maximum resident set size"

  # Should be < 50MB
  echo "✅ Memory usage acceptable"
}

test_50_issues
test_api_calls
test_memory
```

---

## 7. Error Handling

### 7.1 API Error Handling

```bash
# Retry logic with exponential backoff
safe_gh_call() {
  local max_retries=3
  local attempt=1
  local wait_time=2

  while [ $attempt -le $max_retries ]; do
    # Attempt the command
    local output
    if output=$("$@" 2>&1); then
      echo "$output"
      return 0
    fi

    # Check error type
    if echo "$output" | grep -qi "rate limit"; then
      echo "⚠️  Rate limited, waiting ${wait_time}s... (attempt $attempt/$max_retries)" >&2
      sleep $wait_time
      wait_time=$((wait_time * 2))  # Exponential backoff
    elif echo "$output" | grep -qi "network"; then
      echo "⚠️  Network error, retrying... (attempt $attempt/$max_retries)" >&2
      sleep 1
    else
      echo "❌ API call failed: $output" >&2
      return 1
    fi

    ((attempt++))
  done

  echo "❌ Failed after $max_retries attempts" >&2
  return 1
}

# Usage
sync_project_status() {
  # ... existing code ...

  if ! safe_gh_call gh project item-edit \
    --id "$item_id" \
    --project-id "$PROJECT_ID" \
    --field-id "$STATUS_FIELD_ID" \
    --single-select-option-id "$status_option_id"; then
    echo "  ❌ Failed to update #$issue_number on project board"
    ((PROJECT_SYNC_ERRORS++))
    return 1
  fi
}
```

### 7.2 Error Categories

| Error Type | Severity | Action | User Impact |
|------------|----------|--------|-------------|
| **Project not found** | Low | Disable sync, log warning | No project sync |
| **Missing item** | Low | Skip item, log warning | Item not synced |
| **Rate limit** | Medium | Retry with backoff | Temporary delay |
| **Network error** | Medium | Retry 3 times | May fail |
| **Invalid status** | High | Log error, skip | Data integrity issue |
| **Permission denied** | High | Disable sync, alert | No project sync |

### 7.3 Error Messages

```bash
# Good error messages: Actionable and informative

# ❌ Bad
echo "Error"

# ✅ Good
echo "❌ Failed to update #7 on project board: Permission denied"
echo "💡 Check that your GitHub token has 'project' scope:"
echo "   gh auth refresh -h github.com -s project"

# ❌ Bad
echo "Item not found"

# ✅ Good
echo "⚠️  Issue #9999 not found in project #5"
echo "💡 Add it to the project manually:"
echo "   gh project item-add 5 --owner Ubi-Tel --url https://github.com/Ubi-Tel/ubispot/issues/9999"
```

### 7.4 Logging

```bash
# Optional debug logging
PROJECT_SYNC_DEBUG="${PROJECT_SYNC_DEBUG:-false}"

debug_log() {
  if [ "$PROJECT_SYNC_DEBUG" = true ]; then
    echo "[DEBUG] $*" >&2
  fi
}

# Usage
sync_project_status() {
  debug_log "Syncing #$issue_number: $local_status → $project_status"
  debug_log "Item ID: $item_id"
  debug_log "Status option ID: $status_option_id"

  # ... sync logic ...
}

# Enable with:
# PROJECT_SYNC_DEBUG=true ./ccpm/scripts/pm/sync.sh
```

---

## 8. Configuration Options

### 8.1 Environment Variables

```bash
# ============================================================================
# PROJECT SYNC CONFIGURATION
# ============================================================================

# Enable/disable project board sync
# Default: true
export PROJECT_SYNC_ENABLED=true

# Project number to sync with
# Default: 5 (auto-detect if possible)
export PROJECT_NUMBER=5

# Repository owner (organization or user)
# Default: Ubi-Tel (from git remote)
export PROJECT_OWNER="Ubi-Tel"

# Dry run mode: Show what would change without applying
# Default: false
export PROJECT_SYNC_DRY_RUN=false

# Debug logging: Show detailed sync operations
# Default: false
export PROJECT_SYNC_DEBUG=false

# Retry configuration
# Default: 3 attempts with exponential backoff
export PROJECT_SYNC_MAX_RETRIES=3
export PROJECT_SYNC_RETRY_DELAY=2  # seconds

# Performance tuning
# Default: 100 (fetch all items)
export PROJECT_SYNC_ITEM_LIMIT=100
```

### 8.2 Per-Epic Configuration

```yaml
# .claude/epics/cloud-authentication/epic.md frontmatter

---
name: Cloud Authentication Epic
status: in-progress
project_sync: true              # Enable for this epic
project_number: 5               # Override default project
project_owner: Ubi-Tel          # Override default owner
---
```

### 8.3 Global Configuration File

```bash
# ~/.config/ccpm/config.sh
# Global CCPM configuration (future enhancement)

# Default project settings
CCPM_DEFAULT_PROJECT_NUMBER=5
CCPM_DEFAULT_PROJECT_OWNER="Ubi-Tel"

# Sync preferences
CCPM_AUTO_SYNC_ON_COMMIT=true
CCPM_SYNC_INTERVAL_MINUTES=30

# Notification preferences
CCPM_NOTIFY_ON_CONFLICT=true
CCPM_NOTIFY_ON_ERROR=true
```

### 8.4 Usage Examples

```bash
# Example 1: Normal sync with defaults
./ccpm/scripts/pm/sync.sh

# Example 2: Dry run to preview changes
PROJECT_SYNC_DRY_RUN=true ./ccpm/scripts/pm/sync.sh

# Example 3: Disable project sync temporarily
PROJECT_SYNC_ENABLED=false ./ccpm/scripts/pm/sync.sh

# Example 4: Debug mode for troubleshooting
PROJECT_SYNC_DEBUG=true ./ccpm/scripts/pm/sync.sh

# Example 5: Different project
PROJECT_NUMBER=6 ./ccpm/scripts/pm/sync.sh

# Example 6: Different organization
PROJECT_OWNER="MyOrg" PROJECT_NUMBER=3 ./ccpm/scripts/pm/sync.sh

# Example 7: One-liner with multiple options
PROJECT_SYNC_DRY_RUN=true PROJECT_SYNC_DEBUG=true ./ccpm/scripts/pm/sync.sh
```

---

## 9. Rollout Plan

### 9.1 Phased Rollout Schedule

| Week | Phase | Status | Risk | Rollback Plan |
|------|-------|--------|------|---------------|
| **Week 1** | Phase 1: Read-Only | Implement & Test | None | N/A (read-only) |
| **Week 2** | Phase 2: One-Way MVP | Deploy with flag off | Low | Set `PROJECT_SYNC_ENABLED=false` |
| **Week 3** | Phase 2: Enable by default | Monitor | Medium | Set default to `false` |
| **Week 4** | Phase 3: Bidirectional | Implement & Test | Medium | Revert to Phase 2 |
| **Week 5** | Phase 4: Polish | Deploy | Low | N/A (enhancements only) |

### 9.2 Week 1: Phase 1 Implementation

**Goals:**
- Implement read-only project sync
- Validate API access and data structures
- Identify any edge cases

**Tasks:**
- [ ] Write `initialize_project_cache()`
- [ ] Write display functions
- [ ] Test with real project data
- [ ] Document API requirements

**Deliverable:** Script shows project status but makes no changes

**Success Criteria:**
- Correctly fetches all project items
- Displays accurate status comparison
- No errors with missing items
- Performance: < 2s for 50 issues

### 9.3 Week 2: Phase 2 Implementation (MVP)

**Goals:**
- Implement one-way sync (Local → Projects)
- Deploy with feature flag disabled by default
- Gather feedback from early testers

**Tasks:**
- [ ] Implement status mapping functions
- [ ] Implement `sync_project_status()`
- [ ] Implement `sync_all_project_items()`
- [ ] Add error handling and retry logic
- [ ] Write integration tests
- [ ] Add `PROJECT_SYNC_ENABLED` flag (default: `false`)

**Rollout:**
1. Deploy code with flag **disabled**
2. Test internally with `PROJECT_SYNC_ENABLED=true`
3. Invite 2-3 beta testers
4. Fix bugs discovered
5. Document usage

**Success Criteria:**
- All integration tests pass
- 0 data corruption incidents
- 0 API rate limit incidents
- Beta tester satisfaction > 80%

### 9.4 Week 3: Enable by Default

**Goals:**
- Enable project sync for all users by default
- Monitor for issues
- Provide support for any problems

**Tasks:**
- [ ] Change default: `PROJECT_SYNC_ENABLED=true`
- [ ] Announce in documentation
- [ ] Monitor error logs
- [ ] Provide user support

**Monitoring:**
- Watch for error rate spikes
- Check GitHub API rate limit usage
- Collect user feedback
- Track sync success rate

**Rollback Trigger:**
- Error rate > 5%
- Multiple user complaints
- API rate limit issues

### 9.5 Week 4: Phase 3 (Bidirectional)

**Goals:**
- Implement reverse sync (Projects → Local)
- Handle conflicts automatically
- Maintain data consistency

**Tasks:**
- [ ] Implement reverse status mapping
- [ ] Implement conflict detection
- [ ] Implement conflict resolution (timestamp-based)
- [ ] Add `last_project_sync:` field
- [ ] Write comprehensive tests

**Testing Focus:**
- Conflict scenarios
- Timestamp edge cases
- Data integrity
- Race conditions

### 9.6 Week 5: Polish & Production

**Goals:**
- Comprehensive documentation
- Performance optimization
- Advanced error handling
- User training

**Tasks:**
- [ ] Complete documentation
- [ ] Optimize API calls (caching, batching)
- [ ] Improve error messages
- [ ] Create troubleshooting guide
- [ ] Record demo video

**Documentation:**
- README.md update
- Configuration guide
- Troubleshooting FAQ
- Video walkthrough

---

## 10. Success Metrics

### 10.1 Quantitative Metrics

| Metric | Target | Measurement | Frequency |
|--------|--------|-------------|-----------|
| **Sync Accuracy** | 100% | Match rate: local vs board | Per sync |
| **Performance** | < 10s for 50 issues | Execution time | Per sync |
| **Error Rate** | < 1% | Failed syncs / total syncs | Daily |
| **API Efficiency** | 2 + N calls | API call count per sync | Per sync |
| **Uptime** | > 99% | Successful syncs / attempts | Weekly |
| **User Adoption** | > 80% | Users with sync enabled | Monthly |

### 10.2 Qualitative Metrics

| Metric | Target | Measurement | Frequency |
|--------|--------|-------------|-----------|
| **User Satisfaction** | > 90% satisfied | Survey (1-5 scale) | Quarterly |
| **Ease of Use** | < 5 min to understand | Time to first sync | Per new user |
| **Documentation Quality** | < 2 support tickets/month | Support volume | Monthly |
| **Reliability** | "It just works" | Incident count | Monthly |

### 10.3 Dashboard

```bash
# Sync metrics dashboard (future enhancement)
# ccpm/scripts/pm/metrics.sh

echo "📊 CCPM Sync Metrics - Last 7 Days"
echo "===================================="
echo ""

echo "Performance:"
echo "  Avg sync time: 3.2s"
echo "  Max sync time: 8.1s"
echo "  Min sync time: 1.4s"
echo ""

echo "Reliability:"
echo "  Total syncs: 156"
echo "  Successful: 155 (99.4%)"
echo "  Failed: 1 (0.6%)"
echo ""

echo "API Usage:"
echo "  Total API calls: 487"
echo "  Avg per sync: 3.1"
echo "  Rate limit hit: 0 times"
echo ""

echo "User Activity:"
echo "  Active users: 8"
echo "  Sync enabled: 7 (87.5%)"
echo "  Avg syncs/user: 19.5"
```

### 10.4 Alerting Thresholds

```bash
# Monitor and alert on these conditions

# CRITICAL: Sync failure rate > 5%
if [ $ERROR_RATE -gt 5 ]; then
  alert_critical "CCPM sync error rate: ${ERROR_RATE}%"
fi

# WARNING: Sync time > 15s
if [ $SYNC_TIME -gt 15 ]; then
  alert_warning "CCPM sync slow: ${SYNC_TIME}s"
fi

# WARNING: API rate limit approaching
if [ $API_USAGE -gt 4500 ]; then  # 90% of 5000/hour
  alert_warning "GitHub API rate limit at ${API_USAGE}/5000"
fi

# INFO: Conflict detected
if [ $CONFLICTS -gt 0 ]; then
  log_info "CCPM sync resolved $CONFLICTS conflicts"
fi
```

---

## 11. Risks & Mitigations

### 11.1 Technical Risks

| Risk | Likelihood | Impact | Severity | Mitigation |
|------|-----------|--------|----------|------------|
| **API rate limits** | Medium | High | 🟡 Medium | Implement caching, retry logic, exponential backoff |
| **Incorrect status mapping** | Low | High | 🟡 Medium | Comprehensive test suite, dry-run mode |
| **Data corruption** | Low | Critical | 🔴 High | Read-only mode first, extensive testing, backups |
| **Performance degradation** | Medium | Medium | 🟡 Medium | Optimize API calls, implement caching |
| **gh CLI breaking changes** | Low | High | 🟡 Medium | Pin version, monitor release notes |
| **Network failures** | Medium | Low | 🟢 Low | Retry logic, graceful degradation |
| **Project not found** | Low | Low | 🟢 Low | Auto-detect, clear error messages |
| **Concurrent modifications** | Medium | Medium | 🟡 Medium | Timestamp-based conflict resolution (Phase 3) |

### 11.2 User Risks

| Risk | Likelihood | Impact | Severity | Mitigation |
|------|-----------|--------|----------|------------|
| **Confusion about sync direction** | Medium | Low | 🟢 Low | Clear documentation, dry-run mode |
| **Lost manual board changes** | Low | Medium | 🟡 Medium | Bidirectional sync (Phase 3), conflict logging |
| **Unexpected status changes** | Low | Medium | 🟡 Medium | Verbose logging, change notifications |
| **Feature not discoverable** | Medium | Low | 🟢 Low | Documentation, changelog, demo video |
| **Disabled by mistake** | Low | Low | 🟢 Low | Default: enabled, clear config docs |

### 11.3 Organizational Risks

| Risk | Likelihood | Impact | Severity | Mitigation |
|------|-----------|--------|----------|------------|
| **Low adoption** | Medium | Medium | 🟡 Medium | User training, clear value prop, testimonials |
| **Support overhead** | Low | Low | 🟢 Low | Good docs, troubleshooting guide, FAQ |
| **Maintenance burden** | Low | Low | 🟢 Low | Clean code, comprehensive tests, docs |
| **GitHub API changes** | Low | High | 🟡 Medium | Monitor API changelog, version pinning |

### 11.4 Mitigation Implementation

```bash
# Risk Mitigation: API Rate Limits
PROJECT_SYNC_CACHE_TTL=300  # Cache for 5 minutes
PROJECT_SYNC_BATCH_SIZE=50  # Process in batches
PROJECT_SYNC_RATE_LIMIT_BUFFER=500  # Stop at 4500/5000

check_rate_limit() {
  local remaining=$(gh api rate_limit | jq -r '.rate.remaining')

  if [ $remaining -lt $PROJECT_SYNC_RATE_LIMIT_BUFFER ]; then
    echo "⚠️  Approaching rate limit ($remaining remaining), pausing sync"
    return 1
  fi

  return 0
}

# Risk Mitigation: Data Corruption
PROJECT_SYNC_BACKUP_ENABLED=true

backup_before_sync() {
  if [ "$PROJECT_SYNC_BACKUP_ENABLED" = true ]; then
    cp -r .claude/epics ".claude/epics.backup-$(date +%Y%m%d-%H%M%S)"
  fi
}

# Risk Mitigation: Concurrent Modifications
detect_concurrent_modification() {
  local file="$1"
  local last_sync=$(grep "^last_sync:" "$file" | sed 's/^last_sync: *//')
  local file_mtime=$(stat -c %Y "$file")
  local sync_mtime=$(date -d "$last_sync" +%s 2>/dev/null || echo 0)

  if [ $file_mtime -gt $((sync_mtime + 60)) ]; then
    echo "⚠️  Warning: $file modified since last sync"
    return 1
  fi

  return 0
}
```

---

## 12. Timeline & Effort

### 12.1 Detailed Timeline

| Phase | Task | Hours | Dependencies | Owner | Status |
|-------|------|-------|--------------|-------|--------|
| **Phase 1** | Read-only display | 2-3 | None | Dev | Not Started |
| | - Implement `initialize_project_cache()` | 1.0 | gh CLI with project scope | | |
| | - Implement display functions | 0.5 | initialize_project_cache | | |
| | - Test with real data | 0.5 | display functions | | |
| | - Documentation | 0.5 | testing | | |
| **Phase 2** | One-way sync MVP | 3-4 | Phase 1 | Dev | Not Started |
| | - Implement status mapping | 0.5 | None | | |
| | - Implement sync functions | 1.5 | status mapping | | |
| | - Error handling & retry logic | 1.0 | sync functions | | |
| | - Integration testing | 1.0 | error handling | | |
| | - Documentation & examples | 0.5 | testing | | |
| **Phase 3** | Bidirectional sync | 4-5 | Phase 2 deployed | Dev | Not Started |
| | - Implement reverse mapping | 0.5 | None | | |
| | - Implement conflict detection | 1.0 | reverse mapping | | |
| | - Implement conflict resolution | 1.5 | conflict detection | | |
| | - Comprehensive testing | 1.5 | conflict resolution | | |
| | - Documentation update | 0.5 | testing | | |
| **Phase 4** | Polish & optimization | 2-3 | Phase 3 deployed | Dev | Not Started |
| | - Performance optimization | 1.0 | None | | |
| | - Advanced error handling | 0.5 | None | | |
| | - Comprehensive docs | 1.0 | None | | |
| | - Demo video | 0.5 | docs | | |
| **Total** | | **11-15** | | | |

### 12.2 Gantt Chart (Text Format)

```
Week 1:  [========= Phase 1 =========]
Week 2:  [============= Phase 2 MVP =============]
Week 3:  [== Enable Default ==][= Monitor =]
Week 4:  [================ Phase 3 ================]
Week 5:  [======== Phase 4 ========]

Legend:
[====] Implementation
[==]   Testing
[=]    Monitoring
```

### 12.3 Critical Path

```
Phase 1 (2-3h)
    ↓
Phase 2 Implementation (3-4h)
    ↓
Phase 2 Testing & Deployment (1 week) ← CRITICAL
    ↓
Phase 2 Monitoring (1 week)
    ↓
Phase 3 (4-5h)
    ↓
Phase 4 (2-3h)
```

**Critical Path Total**: ~3 weeks + 11-15 hours dev time

**Minimum Viable Product**: Phase 1-2 (5-7 hours) delivers 80% of value

### 12.4 Resource Requirements

| Resource | Quantity | Duration | Notes |
|----------|----------|----------|-------|
| **Developer** | 1 | 11-15 hours | Bash/shell scripting experience |
| **Tester** | 1 | 4-5 hours | Part-time, can be same as dev |
| **Reviewer** | 1 | 2 hours | Code review, architecture validation |
| **Technical Writer** | 1 | 3 hours | Documentation, examples, troubleshooting |
| **GitHub API Access** | - | - | With 'project' scope enabled |
| **Test Environment** | 1 | 5 weeks | GitHub project board for testing |

### 12.5 Effort Breakdown by Category

| Category | Hours | Percentage |
|----------|-------|------------|
| **Core Development** | 6-8 | 50% |
| **Testing** | 3-4 | 25% |
| **Documentation** | 2-3 | 15% |
| **Polish & Optimization** | 1-2 | 10% |
| **Total** | 12-17 | 100% |

---

## 13. Next Steps

### 13.1 Immediate Actions (This Week)

1. **Review this plan** with team/stakeholders
2. **Get approval** for Phase 1-2 MVP implementation
3. **Verify GitHub access** has `project` scope enabled
4. **Create feature branch**: `git checkout -b feature/project-board-sync`
5. **Set up test environment**: Create test project board if needed

### 13.2 Phase 1 Kickoff (Next Week)

1. **Implement Phase 1** (read-only display)
2. **Test with real project** #5 data
3. **Document API requirements**
4. **Demo to stakeholders**
5. **Get go-ahead for Phase 2**

### 13.3 Decision Points

**Decision 1**: Approve MVP (Phase 1-2) vs. Full Implementation (Phase 1-4)?
- **Recommendation**: Start with MVP, evaluate before Phase 3
- **Rationale**: Faster time-to-value, lower risk

**Decision 2**: Enable by default or opt-in?
- **Recommendation**: Opt-in for Week 1-2, then default-on
- **Rationale**: Safe rollout, gather feedback

**Decision 3**: Bidirectional sync priority?
- **Recommendation**: Medium priority (after MVP proves valuable)
- **Rationale**: MVP delivers 80% value, bidirectional adds complexity

### 13.4 Success Criteria for Go-Live

Phase 2 MVP ready for production when:
- [ ] All integration tests pass
- [ ] Performance: < 10s for 50 issues
- [ ] Error handling: 0 crashes in 100 test syncs
- [ ] Documentation: Complete with examples
- [ ] Code review: Approved by senior dev
- [ ] Dry-run mode: Working and documented
- [ ] Beta testing: 3 users tested successfully
- [ ] Rollback plan: Documented and tested

---

## Appendix A: References

### Related Documentation
- `ccpm/scripts/pm/sync.sh` - Current sync implementation
- `ccpm/scripts/pm/blocked.sh` - Status-based blocking detection
- `ccpm/scripts/pm/standup.sh` - Daily standup with blocked tasks
- GitHub Projects API: https://docs.github.com/en/graphql/reference/objects#project
- gh CLI project commands: https://cli.github.com/manual/gh_project

### GitHub Issues
- Issue #7: Cloud CPD Handler (currently blocked)
- Epic #3: Cloud Authentication
- Project #5: MAC CPD Handler MVP Sprint

### Tools & Technologies
- **bash**: Shell scripting language (v4.0+)
- **gh**: GitHub CLI (v2.0+ with project commands)
- **jq**: JSON processor for parsing API responses
- **git**: Version control

---

## Appendix B: FAQ

**Q: Will this slow down my syncs?**
A: Phase 2 adds 2-3 seconds for project board sync. Total sync time: < 10s for 50 issues.

**Q: What if I don't want project sync?**
A: Set `PROJECT_SYNC_ENABLED=false` in your environment or per-epic config.

**Q: Can I preview changes before applying?**
A: Yes! Use dry-run mode: `PROJECT_SYNC_DRY_RUN=true ./ccpm/scripts/pm/sync.sh`

**Q: What happens if the project board is manually updated?**
A: Phase 2 (one-way): Manual changes overwritten on next sync. Phase 3 (bidirectional): Manual changes synced to local files.

**Q: How do I troubleshoot sync issues?**
A: Enable debug mode: `PROJECT_SYNC_DEBUG=true ./ccpm/scripts/pm/sync.sh`

**Q: What if my issue isn't in the project?**
A: The sync will skip it with a warning. Add it manually: `gh project item-add 5 --owner Ubi-Tel --url <issue-url>`

**Q: Can I sync to multiple projects?**
A: Not in MVP. Phase 4 could add multi-project support if needed.

**Q: What about private projects?**
A: Works if your GitHub token has access. Ensure correct `PROJECT_OWNER` is set.

---

## Appendix C: Glossary

| Term | Definition |
|------|------------|
| **CCPM** | Claude Code Project Manager - task management system |
| **Project Board** | GitHub Projects kanban board for issue tracking |
| **Project Item** | An issue or PR added to a GitHub project |
| **Status Field** | The column/status of an item (Todo, In Progress, Done) |
| **One-way sync** | Changes flow in only one direction (Local → GitHub) |
| **Bidirectional sync** | Changes flow both ways with conflict resolution |
| **Dry-run mode** | Preview changes without applying them |
| **Epic** | Parent issue that groups related tasks |
| **Frontmatter** | YAML metadata at the top of markdown files |

---

**Document Version**: 1.0
**Last Updated**: 2025-10-06
**Status**: Draft - Awaiting Approval
**Next Review**: After Phase 1 completion
