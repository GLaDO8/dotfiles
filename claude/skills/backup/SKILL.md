---
name: backup
description: Backup Claude Code configuration to GitHub. Commits and pushes any changes to settings, skills, or other config files.
---

# Backup Claude Config

Commit and push any changes to the claude-config repository.

## Workflow

1. **Check for changes**
   ```bash
   cd ~/claude-config && git status --short
   ```
   If no changes, inform user and stop.

2. **Show what changed**
   ```bash
   cd ~/claude-config && git diff
   cd ~/claude-config && git diff --cached
   ```

3. **Stage all changes**
   ```bash
   cd ~/claude-config && git add -A
   ```

4. **Generate commit message**
   Analyze the changes and create a descriptive message:
   - "Update CLAUDE.md instructions"
   - "Add new skill: <name>"
   - "Update settings: enable <plugin>"
   - "Update statusline script"
   - Or combine if multiple: "Update settings and add skill"

5. **Commit and push**
   ```bash
   cd ~/claude-config && git commit -m "<message>"
   cd ~/claude-config && git push
   ```

6. **Confirm success**
   Report what was backed up.

## Output Format

```
Checking claude-config for changes...

Changes detected:
  M  settings.json
  A  skills/newskill.md

Committed: Add newskill and update settings
Pushed to: https://github.com/GLaDO8/claude-config

Backup complete.
```

## If no changes

```
Checking claude-config for changes...

No changes to backup. Config is up to date.
```

## Never

- Don't commit if there are no changes
- Don't include sensitive data in commit messages
- Don't force push
