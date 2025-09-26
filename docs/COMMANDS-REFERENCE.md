# 🚀 New CCPM Slash Commands

## Recently Added Commands (Sept 26, 2025)

### Sync Commands
| Command | Description | Script |
|---------|-------------|--------|
| `/pm:submodules` | Sync all submodule status | sync-submodules.sh |
| `/pm:sync-bidirectional` | Full GitHub bidirectional sync | sync-bidirectional.sh |
| `/pm:sync-sprint` | Sprint board alignment | sync-sprint.sh |
| `/pm:sprint` | Alias for sync-sprint | sync-sprint.sh |
| `/pm:github-sync` | Basic GitHub sync | sync.sh |

### Updated Commands
| Command | Update |
|---------|--------|
| `/pm:standup` | Now shows GitHub issue titles |

## Quick Usage Guide

### Daily Workflow
```bash
/pm:standup              # Morning standup with issue titles
/pm:sprint               # Check sprint board status
/pm:submodules           # Check submodule agent status
```

### Sync Operations
```bash
/pm:github-sync          # Quick GitHub sync
/pm:sync-bidirectional   # Full bidirectional sync
/pm:sync-sprint          # Align with sprint board
```

### Submodule Management
```bash
/pm:submodules           # Check all submodule status
```

## Command File Locations

All command definitions: `.claude/commands/pm/*.md`
All scripts: `.claude/scripts/pm/*.sh`

## Testing New Commands

If a slash command doesn't work immediately:
1. The command file has been created
2. Try restarting Claude (commands load at startup)
3. Or just ask me to run it naturally

## All Available PM Commands

Run `/pm:help` to see the full list of PM commands.