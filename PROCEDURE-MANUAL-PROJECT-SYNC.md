# Manual GitHub Projects Board Sync Procedure

**Purpose**: Step-by-step guide for manually synchronizing local CCPM task status with GitHub Projects board when the automated sync script is not available or not working.

**Use Cases**:
- Quick one-off status updates
- Troubleshooting sync issues
- Understanding the API for script development
- Emergency sync when automation is broken

**Last Updated**: 2025-10-06
**Tested With**: gh CLI v2.40+, GitHub Projects v2

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Discovery Phase](#discovery-phase)
3. [Sync Procedure](#sync-procedure)
4. [Status Mapping Reference](#status-mapping-reference)
5. [Troubleshooting](#troubleshooting)
6. [Quick Reference](#quick-reference)

---

## Prerequisites

### 1. GitHub CLI Installed

```bash
# Check if gh is installed
gh --version
# Expected: gh version 2.40.0 or higher

# Install if missing (Ubuntu/Debian)
sudo apt install gh

# Or via official installer
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
  sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
  sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

### 2. GitHub Authentication with Project Scope

```bash
# Check current authentication status
gh auth status

# Expected output should include:
#   Token scopes: 'gist', 'project', 'read:org', 'repo', 'workflow'
#                          ^^^^^^^^ - THIS IS REQUIRED
```

**If 'project' scope is missing**, add it:

```bash
# Refresh authentication with project scopes
gh auth refresh -h github.com -s read:project -s project

# This will output a device code like:
# ! First copy your one-time code: XXXX-XXXX
# Open this URL to continue in your web browser: https://github.com/login/device

# Steps:
# 1. Copy the code shown
# 2. Open https://github.com/login/device in browser
# 3. Paste the code
# 4. Click "Authorize"
# 5. Wait for CLI to confirm: "✓ Authentication complete"

# Verify scopes were added
gh auth status | grep -i project
# Should show: 'project' in token scopes
```

### 3. Required Tools

```bash
# jq - JSON processor
jq --version
# Install if missing: sudo apt install jq

# Basic shell utilities (should be pre-installed)
which grep sed basename
```

### 4. Repository Context

```bash
# Ensure you're in the correct repository
cd /path/to/ubispot  # or your project directory
git remote -v | grep origin
# Should show: Ubi-Tel/ubispot (or your repo)
```

---

## Discovery Phase

Before syncing, you need to discover the project metadata. This phase gathers all the IDs needed for updates.

### Step 1: List Available Projects

```bash
# List all projects for the organization/owner
gh project list --owner Ubi-Tel

# Example output:
# 5  MAC CPD Handler MVP Sprint       open  PVT_kwDOCocVeM4BENWS
# 4  Ubitel DApp External Issues      open  PVT_kwDOCocVeM4BEL3P
# 3  E2E Captive Portal Sprint        open  PVT_kwDOCocVeM4BD3Eo
# ...

# Identify your project number (e.g., 5) and project ID (e.g., PVT_kwDOCocVeM4BENWS)
```

**Record these values**:
```bash
PROJECT_NUMBER=5
PROJECT_ID="PVT_kwDOCocVeM4BENWS"
PROJECT_OWNER="Ubi-Tel"
```

### Step 2: Get Status Field Metadata

```bash
# List all fields for the project
gh project field-list $PROJECT_NUMBER --owner $PROJECT_OWNER --format json

# This returns a large JSON with all field information
# We need to extract:
# 1. Status field ID
# 2. Status option IDs (Todo, In Progress, Done)
```

**Extract Status Field ID**:
```bash
# Get the Status field ID
gh project field-list $PROJECT_NUMBER --owner $PROJECT_OWNER --format json | \
  jq -r '.fields[] | select(.name == "Status") | .id'

# Example output: PVTSSF_lADOCocVeM4BENWSzg15s94

# Record this:
STATUS_FIELD_ID="PVTSSF_lADOCocVeM4BENWSzg15s94"
```

**Extract Status Option IDs**:
```bash
# Get all status options with their IDs
gh project field-list $PROJECT_NUMBER --owner $PROJECT_OWNER --format json | \
  jq -r '.fields[] | select(.name == "Status") | .options[] | "\(.name)|\(.id)"'

# Example output:
# Todo|f75ad846
# In Progress|47fc9ee4
# Done|98236657

# Record these:
TODO_ID="f75ad846"
IN_PROGRESS_ID="47fc9ee4"
DONE_ID="98236657"
```

### Step 3: List Current Project Items

```bash
# Get all items in the project with their current status
gh project item-list $PROJECT_NUMBER --owner $PROJECT_OWNER --format json --limit 100 | \
  jq -r '.items[] | select(.content.type == "Issue") | "\(.content.number)|\(.id)|\(.status)|\(.content.title)"' | \
  sort -t'|' -k1 -n

# Example output:
# 2|PVTI_lADOCocVeM4BENWSzgfPPlo|In Progress|[UPDATED] IP-Only Cloud Authentication
# 3|PVTI_lADOCocVeM4BENWSzgfPPk8|Todo|Epic: Cloud Authentication
# 7|PVTI_lADOCocVeM4BENWSzgfPPlM|Todo|Cloud CPD Handler - IP Parameter Injection
# 10|PVTI_lADOCocVeM4BENWSzgfPPmA|Todo|Cloud UAM Handler - Accept IP/MAC Parameters
# ...

# This shows: issue_number | item_id | current_status | title
```

**Create a mapping file** (optional but recommended):
```bash
# Save to a file for reference
gh project item-list $PROJECT_NUMBER --owner $PROJECT_OWNER --format json --limit 100 | \
  jq -r '.items[] | select(.content.type == "Issue") | "\(.content.number)|\(.id)|\(.status)"' | \
  sort -t'|' -k1 -n > /tmp/project-items-map.txt

# View it:
cat /tmp/project-items-map.txt
```

---

## Sync Procedure

Now that you have all the metadata, you can update item statuses.

### Step 4: Check Local CCPM Status

```bash
# For a specific issue (e.g., #7)
grep "^status:" .claude/epics/cloud-authentication/7.md | head -1
# Output: status: blocked

# For all issues in an epic
for f in .claude/epics/cloud-authentication/*.md; do
  [ -f "$f" ] || continue
  num=$(basename "$f" .md)
  [[ "$num" =~ ^[0-9]+$ ]] || continue
  status=$(grep "^status:" "$f" | head -1 | sed 's/^status: *//')
  echo "$num|$status"
done | sort -t'|' -k1 -n

# Example output:
# 4|closed
# 5|closed
# 6|closed
# 7|blocked
# 8|open
# 10|open
# 13|open
```

### Step 5: Map Local Status to Project Status

Use the [Status Mapping Reference](#status-mapping-reference) to determine the target project status.

**Example**:
- Local: `blocked` → Project: `Todo` + add "blocked" label
- Local: `in_progress` → Project: `In Progress`
- Local: `closed` → Project: `Done`

### Step 6: Update Project Item Status

```bash
# Template command:
gh project item-edit \
  --id <ITEM_ID> \
  --project-id <PROJECT_ID> \
  --field-id <STATUS_FIELD_ID> \
  --single-select-option-id <STATUS_OPTION_ID>

# Example: Update issue #7 from "In Progress" to "Todo"
# (because local status is "blocked")

# Get item ID for issue #7 (from Step 3 output or mapping file)
ITEM_ID_7="PVTI_lADOCocVeM4BENWSzgfPPlM"

# Update to Todo status
gh project item-edit \
  --id "$ITEM_ID_7" \
  --project-id "$PROJECT_ID" \
  --field-id "$STATUS_FIELD_ID" \
  --single-select-option-id "$TODO_ID"

# Expected: Command completes silently (success) or shows error
```

### Step 7: Update Issue Labels (for blocked status)

```bash
# If local status is "blocked", add the label
gh issue edit 7 --add-label "blocked"

# If changing FROM blocked to something else, remove the label
gh issue edit 7 --remove-label "blocked"
```

### Step 8: Verify Changes

```bash
# Check the project board via CLI
gh project item-list $PROJECT_NUMBER --owner $PROJECT_OWNER --format json | \
  jq -r '.items[] | select(.content.number == 7) | "\(.content.number)|\(.status)"'

# Expected output: 7|Todo

# Check the label
gh issue view 7 --json labels | jq -r '.labels[].name'

# Expected output should include: blocked

# Or view in web browser
gh project view $PROJECT_NUMBER --owner $PROJECT_OWNER --web
```

### Step 9: Batch Updates (Multiple Issues)

```bash
# Create a batch update script

#!/bin/bash
# batch-sync.sh

PROJECT_ID="PVT_kwDOCocVeM4BENWS"
STATUS_FIELD_ID="PVTSSF_lADOCocVeM4BENWSzg15s94"
TODO_ID="f75ad846"
IN_PROGRESS_ID="47fc9ee4"
DONE_ID="98236657"

# Define updates as: issue_number|item_id|target_status_id|label_action
declare -a UPDATES=(
  "7|PVTI_lADOCocVeM4BENWSzgfPPlM|$TODO_ID|add-blocked"
  "3|PVTI_lADOCocVeM4BENWSzgfPPk8|$TODO_ID|none"
  "13|PVTI_lADOCocVeM4BENWSzgfcEsk|$TODO_ID|none"
)

for update in "${UPDATES[@]}"; do
  IFS='|' read -r issue_num item_id status_id label_action <<< "$update"

  echo "Updating #$issue_num..."

  # Update project status
  gh project item-edit \
    --id "$item_id" \
    --project-id "$PROJECT_ID" \
    --field-id "$STATUS_FIELD_ID" \
    --single-select-option-id "$status_id" 2>/dev/null && \
    echo "  ✅ Project status updated" || \
    echo "  ❌ Failed to update project"

  # Handle labels
  if [ "$label_action" = "add-blocked" ]; then
    gh issue edit "$issue_num" --add-label "blocked" 2>/dev/null && \
      echo "  ✅ Added blocked label" || \
      echo "  ⚠️  Could not add label"
  elif [ "$label_action" = "remove-blocked" ]; then
    gh issue edit "$issue_num" --remove-label "blocked" 2>/dev/null || true
  fi

  echo ""
done

echo "✅ Batch sync complete"
```

**Run the batch script**:
```bash
chmod +x batch-sync.sh
./batch-sync.sh
```

---

## Status Mapping Reference

### Local CCPM → GitHub Projects

| Local Status | Project Column | Label Action | Notes |
|-------------|----------------|--------------|-------|
| `open` | Todo | None | Ready to work on |
| `in_progress` | In Progress | None | Active work |
| `in-progress` | In Progress | None | Alternate format |
| `blocked` | Todo | Add "blocked" | Blocked by dependencies |
| `closed` | Done | Remove "blocked" | Task completed |
| `completed` | Done | None | Epic completed |
| `archived` | Done | None | Deleted from GitHub |

### GitHub Projects → Local CCPM (Reverse)

| Project Column | Issue Labels | Local Status | Notes |
|---------------|--------------|--------------|-------|
| Todo | (none) | `open` | Default ready state |
| Todo | blocked | `blocked` | Check label! |
| In Progress | any | `in_progress` | Active work |
| Done | any | `closed` | For tasks |
| Done | any | `completed` | For epic.md |

### Status Option IDs (Project #5)

**IMPORTANT**: These IDs are specific to Project #5. Other projects will have different IDs.

```bash
# Always re-fetch for different projects!
Todo:         f75ad846
In Progress:  47fc9ee4
Done:         98236657
```

To get IDs for a different project:
```bash
gh project field-list <PROJECT_NUMBER> --owner <OWNER> --format json | \
  jq -r '.fields[] | select(.name == "Status") | .options[] | "\(.name)|\(.id)"'
```

---

## Troubleshooting

### Problem: "error: your authentication token is missing required scopes [read:project]"

**Solution**: Add project scopes to your token
```bash
gh auth refresh -h github.com -s read:project -s project
# Follow OAuth flow in browser
```

### Problem: "unknown flag: --owner"

**Cause**: Using wrong command or old gh version

**Solution**: Check command syntax
```bash
# Correct:
gh project list --owner Ubi-Tel

# Check gh version (need v2.0+):
gh --version
```

### Problem: "Project not found"

**Possible Causes**:
1. Wrong project number
2. Wrong owner name
3. No access to private project

**Solution**: List projects to verify
```bash
gh project list --owner Ubi-Tel
# Verify project number exists
```

### Problem: "Item not found in project"

**Cause**: Issue #X is not added to the project

**Solution**: Add issue to project first
```bash
gh project item-add $PROJECT_NUMBER \
  --owner $PROJECT_OWNER \
  --url https://github.com/Ubi-Tel/ubispot/issues/X

# Then try updating again
```

### Problem: "Field not found"

**Cause**: Wrong field ID or project doesn't have Status field

**Solution**: Re-fetch field IDs
```bash
gh project field-list $PROJECT_NUMBER --owner $PROJECT_OWNER --format json | \
  jq '.fields[] | {name: .name, id: .id}'
```

### Problem: Command runs but status doesn't change

**Possible Causes**:
1. Using wrong status option ID
2. Project has custom statuses
3. Permissions issue

**Solution**: Verify IDs are correct
```bash
# Re-fetch status option IDs
gh project field-list $PROJECT_NUMBER --owner $PROJECT_OWNER --format json | \
  jq -r '.fields[] | select(.name == "Status") | .options[]'

# Check current item status
gh project item-list $PROJECT_NUMBER --owner $PROJECT_OWNER --format json | \
  jq -r '.items[] | select(.content.number == X) | {status: .status, id: .id}'
```

### Problem: Rate limit exceeded

**Error**: "API rate limit exceeded"

**Solution**: Wait or check limit status
```bash
# Check rate limit status
gh api rate_limit

# Output shows:
# {
#   "rate": {
#     "limit": 5000,
#     "remaining": 0,
#     "reset": 1696598400
#   }
# }

# Wait until reset time or use authenticated requests (usually higher limit)
```

### Problem: jq command not found

**Solution**: Install jq
```bash
sudo apt install jq        # Ubuntu/Debian
brew install jq            # macOS
```

### Problem: Changes don't appear on web UI

**Solution**:
1. Hard refresh browser (Ctrl+Shift+R)
2. Clear browser cache
3. Wait 10-30 seconds for sync
4. Verify via CLI:
```bash
gh project item-list $PROJECT_NUMBER --owner $PROJECT_OWNER --format json | \
  jq -r '.items[] | select(.content.number == X)'
```

---

## Quick Reference

### Essential Variables

```bash
# Set these once at the start
export PROJECT_NUMBER=5
export PROJECT_OWNER="Ubi-Tel"
export PROJECT_ID="PVT_kwDOCocVeM4BENWS"
export STATUS_FIELD_ID="PVTSSF_lADOCocVeM4BENWSzg15s94"
export TODO_ID="f75ad846"
export IN_PROGRESS_ID="47fc9ee4"
export DONE_ID="98236657"
```

### One-Liner Commands

```bash
# List all projects
gh project list --owner Ubi-Tel

# Get status field ID
gh project field-list 5 --owner Ubi-Tel --format json | \
  jq -r '.fields[] | select(.name == "Status") | .id'

# Get status option IDs
gh project field-list 5 --owner Ubi-Tel --format json | \
  jq -r '.fields[] | select(.name == "Status") | .options[] | "\(.name)|\(.id)"'

# List all items with status
gh project item-list 5 --owner Ubi-Tel --format json | \
  jq -r '.items[] | select(.content.type == "Issue") | "\(.content.number)|\(.status)"' | \
  sort -n

# Update item to Todo
gh project item-edit --id PVTI_xxx --project-id PVT_xxx \
  --field-id PVTSSF_xxx --single-select-option-id f75ad846

# Add blocked label
gh issue edit 7 --add-label "blocked"

# Remove blocked label
gh issue edit 7 --remove-label "blocked"

# View project in browser
gh project view 5 --owner Ubi-Tel --web
```

### Complete Sync Workflow (Copy-Paste)

```bash
#!/bin/bash
# Quick sync for issue #7 from "In Progress" to "Todo" (blocked status)

# 1. Set variables (customize for your project)
PROJECT_NUMBER=5
PROJECT_OWNER="Ubi-Tel"
PROJECT_ID="PVT_kwDOCocVeM4BENWS"
STATUS_FIELD_ID="PVTSSF_lADOCocVeM4BENWSzg15s94"
TODO_ID="f75ad846"
ISSUE_NUMBER=7
ITEM_ID="PVTI_lADOCocVeM4BENWSzgfPPlM"

# 2. Update project status
echo "Updating issue #$ISSUE_NUMBER to Todo..."
gh project item-edit \
  --id "$ITEM_ID" \
  --project-id "$PROJECT_ID" \
  --field-id "$STATUS_FIELD_ID" \
  --single-select-option-id "$TODO_ID"

# 3. Add blocked label
echo "Adding blocked label..."
gh issue edit "$ISSUE_NUMBER" --add-label "blocked"

# 4. Verify
echo "Verifying changes..."
gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json | \
  jq -r ".items[] | select(.content.number == $ISSUE_NUMBER) | \"Status: \(.status)\""
gh issue view "$ISSUE_NUMBER" --json labels | \
  jq -r '.labels[] | select(.name == "blocked") | "Label: \(.name)"'

echo "✅ Sync complete"
```

### Discovery Script (Get All IDs)

```bash
#!/bin/bash
# discover-project-metadata.sh
# Run this once to get all IDs you need

PROJECT_NUMBER=5
PROJECT_OWNER="Ubi-Tel"

echo "=== Project Discovery ==="
echo ""

echo "1. Project Info:"
gh project list --owner "$PROJECT_OWNER" | grep "^$PROJECT_NUMBER"
echo ""

echo "2. Project ID:"
PROJECT_ID=$(gh project list --owner "$PROJECT_OWNER" --format json | \
  jq -r ".projects[] | select(.number == $PROJECT_NUMBER) | .id")
echo "   PROJECT_ID=$PROJECT_ID"
echo ""

echo "3. Status Field ID:"
STATUS_FIELD_ID=$(gh project field-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json | \
  jq -r '.fields[] | select(.name == "Status") | .id')
echo "   STATUS_FIELD_ID=$STATUS_FIELD_ID"
echo ""

echo "4. Status Option IDs:"
gh project field-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json | \
  jq -r '.fields[] | select(.name == "Status") | .options[] | "   \(.name): \(.id)"'
echo ""

echo "5. Current Items:"
gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json | \
  jq -r '.items[] | select(.content.type == "Issue") | "   #\(.content.number): \(.id) | \(.status)"' | \
  sort -t'#' -k2 -n
echo ""

echo "=== Copy-Paste Export Variables ==="
echo ""
echo "export PROJECT_NUMBER=$PROJECT_NUMBER"
echo "export PROJECT_OWNER=\"$PROJECT_OWNER\""
echo "export PROJECT_ID=\"$PROJECT_ID\""
echo "export STATUS_FIELD_ID=\"$STATUS_FIELD_ID\""

# Extract option IDs
TODO_ID=$(gh project field-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json | \
  jq -r '.fields[] | select(.name == "Status") | .options[] | select(.name == "Todo") | .id')
IN_PROGRESS_ID=$(gh project field-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json | \
  jq -r '.fields[] | select(.name == "Status") | .options[] | select(.name == "In Progress") | .id')
DONE_ID=$(gh project field-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json | \
  jq -r '.fields[] | select(.name == "Status") | .options[] | select(.name == "Done") | .id')

echo "export TODO_ID=\"$TODO_ID\""
echo "export IN_PROGRESS_ID=\"$IN_PROGRESS_ID\""
echo "export DONE_ID=\"$DONE_ID\""
echo ""
```

**Save and run**:
```bash
chmod +x discover-project-metadata.sh
./discover-project-metadata.sh > project-vars.sh
source project-vars.sh
```

---

## Best Practices

1. **Always discover IDs first**: Don't hardcode IDs - they change between projects
2. **Verify before bulk updates**: Test with one item first
3. **Keep a mapping file**: Save issue → item_id mappings for reference
4. **Use dry-run mindset**: Double-check commands before running
5. **Handle labels**: Remember to sync labels for blocked status
6. **Verify changes**: Always check results after updates
7. **Document custom workflows**: If you develop custom batch scripts, document them

---

## When to Use Manual Sync vs. Script

### Use Manual Sync When:
- Quick one-off status change (1-3 issues)
- Troubleshooting sync script issues
- Learning the API
- Script is not available or broken
- Testing before implementing automation

### Use Automated Script When:
- Regular syncs (daily, after commits)
- Many issues to update (>5)
- Consistent workflow
- Integration with CI/CD
- Team collaboration (everyone uses same process)

---

## Appendix: Real Example from 2025-10-06

This is the actual sync performed on 2025-10-06 when moving issues #3, #7, #13 from "In Progress" to "Todo":

```bash
# 1. Discovered project metadata
gh project list --owner Ubi-Tel
# Found: Project #5 "MAC CPD Handler MVP Sprint"

# 2. Got field IDs
gh project field-list 5 --owner Ubi-Tel --format json | \
  jq -r '.fields[] | select(.name == "Status") | .options[] | "\(.name)|\(.id)"'
# Result:
#   Todo: f75ad846
#   In Progress: 47fc9ee4
#   Done: 98236657

# 3. Got item IDs and current status
gh project item-list 5 --owner Ubi-Tel --format json --limit 50 | \
  jq -r '.items[] | select(.content.type == "Issue" and ([.content.number] | inside([3,7,13]))) | "\(.content.number)|\(.id)|\(.status)"'
# Result:
#   3|PVTI_lADOCocVeM4BENWSzgfPPk8|In Progress
#   7|PVTI_lADOCocVeM4BENWSzgfPPlM|In Progress
#   13|PVTI_lADOCocVeM4BENWSzgfcEsk|In Progress

# 4. Updated each item to Todo
gh project item-edit \
  --id PVTI_lADOCocVeM4BENWSzgfPPk8 \
  --project-id PVT_kwDOCocVeM4BENWS \
  --field-id PVTSSF_lADOCocVeM4BENWSzg15s94 \
  --single-select-option-id f75ad846
# (Repeated for items 7 and 13)

# 5. Verified changes
gh project item-list 5 --owner Ubi-Tel --format json | \
  jq -r '.items[] | select(.content.type == "Issue") | "\(.content.number)|\(.status)"' | \
  grep -E "^(3|7|13)"
# Result:
#   3|Todo
#   7|Todo
#   13|Todo

# ✅ Success! All three items moved to Todo
```

---

**End of Procedure Document**

**Next Steps**:
1. Test this procedure with your own project
2. Create shortcuts/aliases for common commands
3. Consider automating frequent tasks (→ see TODO-DASHBOARD-SYNC.md)
4. Share procedure with team members

**Feedback**: If you find issues or improvements, document them here!
