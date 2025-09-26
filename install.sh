#!/bin/bash

# CCPM Symlink Installer
# Creates symlinks from project to centralized CCPM installation

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

CCPM_HOME="${CCPM_HOME:-$HOME/s/ccpm}"
PROJECT_DIR="${1:-.}"

echo -e "${BLUE}🔗 CCPM Symlink Installer${NC}"
echo "=========================="
echo ""
echo "CCPM Home: $CCPM_HOME"
echo "Target Project: $PROJECT_DIR"
echo ""

# Verify CCPM installation
if [ ! -d "$CCPM_HOME/scripts/pm" ] || [ ! -d "$CCPM_HOME/commands/pm" ]; then
    echo -e "${RED}❌ CCPM not found at $CCPM_HOME${NC}"
    echo "Please ensure CCPM is installed at: $CCPM_HOME"
    exit 1
fi

# Ensure .claude exists
mkdir -p "$PROJECT_DIR/.claude"

cd "$PROJECT_DIR/.claude"

# Check for existing PM directories
NEEDS_BACKUP=false
if [ -d "scripts/pm" ] && [ ! -L "scripts/pm" ]; then
    NEEDS_BACKUP=true
fi
if [ -d "commands/pm" ] && [ ! -L "commands/pm" ]; then
    NEEDS_BACKUP=true
fi

# Backup existing if present and not already symlinks
if [ "$NEEDS_BACKUP" = true ]; then
    echo -e "${YELLOW}📦 Backing up existing PM files...${NC}"
    BACKUP_FILE="pm-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$BACKUP_FILE" scripts/pm commands/pm 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Backup saved as: $BACKUP_FILE"
fi

# Remove existing directories or broken symlinks
if [ -e "scripts/pm" ] || [ -L "scripts/pm" ]; then
    rm -rf scripts/pm
fi
if [ -e "commands/pm" ] || [ -L "commands/pm" ]; then
    rm -rf commands/pm
fi

# Create parent directories if needed
mkdir -p scripts commands

# Create symlinks
echo -e "${BLUE}🔗 Creating symlinks...${NC}"
ln -s "$CCPM_HOME/scripts/pm" scripts/pm
ln -s "$CCPM_HOME/commands/pm" commands/pm

# Verify
if [ -L "scripts/pm" ] && [ -L "commands/pm" ]; then
    echo -e "${GREEN}✅ CCPM symlinks installed successfully!${NC}"
    echo -e "   scripts/pm  -> $CCPM_HOME/scripts/pm"
    echo -e "   commands/pm -> $CCPM_HOME/commands/pm"
else
    echo -e "${RED}❌ Failed to create symlinks${NC}"
    exit 1
fi

# Test symlinks
if [ -f "scripts/pm/standup.sh" ]; then
    echo -e "${GREEN}✅ Symlinks verified - standup.sh accessible${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: Cannot access scripts through symlink${NC}"
fi

# Check for submodules
if [ -f "$PROJECT_DIR/.gitmodules" ]; then
    echo ""
    echo -e "${BLUE}📦 Found submodules in this project${NC}"
    echo "Install CCPM symlinks in all submodules? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo ""
        # Get submodule paths
        git -C "$PROJECT_DIR" config --file .gitmodules --get-regexp path | awk '{print $2}' | while read -r submodule; do
            if [ -d "$PROJECT_DIR/$submodule" ]; then
                echo -e "${BLUE}Installing in submodule: $submodule${NC}"
                bash "$0" "$PROJECT_DIR/$submodule"
                echo ""
            fi
        done
    fi
fi

echo ""
echo -e "${GREEN}🎉 CCPM installation complete!${NC}"
echo ""
echo "Usage:"
echo "  - Scripts:  .claude/scripts/pm/[script].sh"
echo "  - Commands: /pm:[command] (in Claude)"
echo ""
echo "To update CCPM:"
echo "  cd $CCPM_HOME && git pull"
echo ""