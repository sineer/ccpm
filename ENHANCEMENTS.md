# CCPM Enhancements

This fork includes the following improvements over the original CCPM:

## New Features

### 1. Advanced Sync Capabilities
- **sync-bidirectional.sh**: Full bidirectional GitHub synchronization
- **sync-sprint.sh**: Sprint board alignment and tracking
- **sync-submodules.sh**: Multi-repository status aggregation

### 2. Enhanced Standup
- GitHub issue title integration
- Epic status awareness (completed/closed)
- Improved formatting and task counting

### 3. Submodule Support
- Distributed AI agent architecture
- Cross-repository coordination
- Specialized agent instructions per module

### 4. Convenience Tools
- `pm` wrapper for easy command execution
- Simplified aliases for common operations
- Tab completion support

## Installation

1. Clone this enhanced version:
```bash
git clone https://github.com/sineer/ccpm.git .claude/
```

2. Make scripts executable:
```bash
chmod +x .claude/scripts/pm/*.sh
chmod +x .claude/bin/pm
```

3. Optional: Add to PATH for global `pm` command:
```bash
export PATH="$PATH:$PWD/.claude/bin"
```

## Usage

### Quick Commands
```bash
# Using the pm wrapper
./claude/bin/pm standup       # Daily standup
./claude/bin/pm sync          # GitHub sync
./claude/bin/pm sprint        # Sprint board
./claude/bin/pm submodules    # Check submodules

# Or use slash commands in Claude
/pm:standup
/pm:sync-bidirectional
/pm:sprint
/pm:submodules
```

## Contributing

Contributions are welcome! Please submit PRs to the develop branch.

## Credits

Original CCPM by [Automaze](https://github.com/automazeio/ccpm)
Enhancements by [Sineer](https://github.com/sineer)
