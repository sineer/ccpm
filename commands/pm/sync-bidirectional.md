---
allowed-tools: Bash
---

Run `bash .claude/scripts/pm/sync-bidirectional.sh` to perform full bidirectional sync with GitHub.

This will:
- Pull all issues from GitHub and update local files
- Update task statuses to match GitHub
- Handle closed/reopened issues
- Generate complete sync report

Show the COMPLETE output including:
- Number of files updated
- Issues synced
- Any sync failures
- DO NOT truncate or summarize