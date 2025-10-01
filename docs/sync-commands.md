# CCPM Sync Commands Guide

## Overview

CCPM provides **three different sync operations**, each serving a specific purpose in the development workflow. Understanding when to use each command is crucial for effective project management.

## The Three Sync Commands

### 1. `/pm:epic-sync` - Initial Publication

**Purpose**: First-time publication of an epic and its tasks to GitHub

**Direction**: Local → GitHub (one-way, one-time operation)

**What it does**:
- ✅ Creates epic issue on GitHub
- ✅ Creates task sub-issues (in parallel for large batches)
- ✅ Renames local files: `001.md` → `{issue_number}.md`
- ✅ Updates `depends_on` references with real GitHub issue IDs
- ✅ Adds proper labels: `epic`, `task`, `epic:{name}`
- ✅ Creates development worktree
- ✅ Updates frontmatter with GitHub URLs

**When to use**:
- After running `/pm:epic-decompose` to break down a PRD into tasks
- When you have local task files ready to publish
- **Once per epic** - this is a one-time operation

**Example**:
```bash
/pm:epic-sync cloud-authentication
```

**Output**:
- Epic issue created on GitHub
- Task sub-issues created (with proper parent-child relationships if using `gh-sub-issue`)
- Local files renamed to match GitHub issue numbers
- Worktree created at `../epic-{name}`

---

### 2. `/pm:issue-sync` - Progress Updates

**Purpose**: Share development progress with the team via GitHub comments

**Direction**: Local → GitHub (one-way, ongoing operation)

**What it does**:
- ✅ Posts detailed progress updates as issue comments
- ✅ Updates completion percentages
- ✅ Syncs technical notes and decisions
- ✅ References recent commits
- ✅ Tracks acceptance criteria status
- ✅ Updates epic progress when task completes

**When to use**:
- During active development on a task
- After completing significant work
- Before standup meetings
- When you want to share progress with the team

**Example**:
```bash
/pm:issue-sync 42
```

**Output**:
- Progress comment posted to GitHub issue #42
- Local frontmatter updated with sync timestamp
- Epic progress recalculated if task completed

---

### 3. `/pm:sync` - Bidirectional Synchronization

**Purpose**: Keep local files and GitHub issues synchronized

**Direction**: Local ↔ GitHub (bidirectional, ongoing operation)

**What it does**:
- ✅ **Pull from GitHub**: Updates local files when GitHub is newer
- ✅ **Push to GitHub**: Updates issues when local files are newer
- ✅ **Create files**: Creates local files from GitHub issues
- ✅ **Create issues**: Creates GitHub issues from local files without URLs
- ✅ **Archive handling**: Marks local files as archived if GitHub issue deleted
- ✅ **Audit trail**: Posts sync summary comments to epics
- ✅ **Smart detection**: Uses epic labels + 4 fallback strategies

**When to use**:
- Regular synchronization to keep everything aligned
- After team members update GitHub issues
- When you've created local task files manually
- Daily/weekly maintenance

**Example**:
```bash
# Sync all epics
/pm:sync

# Sync specific epic
/pm:sync cloud-authentication
```

**Output**:
- Local files updated from GitHub
- GitHub issues updated from local
- New files created as needed
- Sync summary posted as comment

---

## Comparison Chart

| Feature | epic-sync | issue-sync | sync |
|---------|-----------|-----------|------|
| **Direction** | Local → GH | Local → GH | Local ↔ GH |
| **Frequency** | Once | Ongoing | Ongoing |
| **Creates GitHub issues** | ✅ | ❌ | ✅ |
| **Creates local files** | ❌ | ❌ | ✅ |
| **Updates GitHub** | ✅ | ✅ | ✅ |
| **Updates local** | ❌ | ❌ | ✅ |
| **Renames files** | ✅ | ❌ | ❌ |
| **Posts comments** | ❌ | ✅ (detailed) | ✅ (summary) |
| **Use case** | Initial publish | Progress sharing | Sync maintenance |

## Typical Workflow

### Phase 1: Epic Creation
```bash
# 1. Create PRD
/pm:prd-new cloud-auth

# 2. Break down into tasks
/pm:epic-decompose cloud-auth

# 3. Publish to GitHub (ONCE)
/pm:epic-sync cloud-auth
```

### Phase 2: Development
```bash
# 1. Start working on a task
/pm:issue-start 42

# 2. Do some work...
# ... code, test, commit ...

# 3. Share progress with team
/pm:issue-sync 42

# 4. Continue development...
# ... more code, more commits ...

# 5. Share more progress
/pm:issue-sync 42
```

### Phase 3: Maintenance
```bash
# Daily/weekly: Keep everything synchronized
/pm:sync

# Or sync just your epic
/pm:sync cloud-authentication
```

## Smart Epic Detection (`/pm:sync` only)

The `/pm:sync` command uses **4 fallback strategies** to determine which epic a task belongs to:

1. **epic:{name} label** (primary)
   - Looks for labels like `epic:cloud-authentication`
   - Most reliable method

2. **Title extraction**
   - For epics with titles like `"Epic: Cloud Authentication"`
   - Converts to slug: `cloud-authentication`

3. **Command argument**
   - If you run `/pm:sync cloud-authentication`
   - Uses the provided epic name

4. **Existing directories**
   - Falls back to first epic directory found
   - Last resort for orphaned tasks

## Best Practices

### Do's ✅
- **Use `epic-sync` once** when first publishing an epic
- **Use `issue-sync` frequently** during development for transparency
- **Use `sync` regularly** to keep local and GitHub aligned
- **Add `epic:{name}` labels** to all issues for reliable sync
- **Commit before syncing** to avoid confusion

### Don'ts ❌
- **Don't run `epic-sync` twice** on the same epic (creates duplicates)
- **Don't edit GitHub issue bodies manually** (local will overwrite)
- **Don't skip sync** for long periods (causes conflicts)
- **Don't delete local files** without archiving GitHub issues first

## Troubleshooting

### "Cannot determine epic name"
- Add `epic:{name}` label to the GitHub issue
- Or run `/pm:sync {epic-name}` with explicit argument

### "Issue already exists"
- You may have run `epic-sync` twice
- Check GitHub for duplicate issues
- Update local file frontmatter with correct GitHub URL

### "Permission denied" or "Auth failed"
- Run `gh auth status` to check authentication
- Run `gh auth login` if needed

### "Syncing to CCPM template repository"
- You're in the wrong repo!
- Update remote: `git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_REPO.git`

## Related Commands

- `/pm:standup` - View daily progress and available tasks
- `/pm:status` - Show overall project status
- `/pm:epic-status {name}` - Show specific epic progress

---

**Last Updated**: 2025-10-01
**Version**: 1.0.0
