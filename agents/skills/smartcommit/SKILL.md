---
name: smartcommit
description: Stage all changes and commit with a concise, auto-generated message.
---

# Smart Commit

Stage all uncommitted changes and commit with a well-written message.

## Workflow

### 0. Sync docs (optional)

If the diff touches files in directories that have `CLAUDE.md` files (e.g., `src/lib/`, `src/components/`, `src/hooks/`, `src/app/`, `src/types/`), ask the user if they want to run `/sync-docs` first to update agent documentation. If they say yes, invoke the `sync-docs` skill and wait for it to complete before proceeding. The sync-docs skill will stage any updated CLAUDE.md files.

### 1. Gather (parallel, no LLM)

```bash
git status --short
```
```bash
git diff --stat
```
```bash
git diff --cached --stat
```
```bash
git log --oneline -5
```

If no changes, say "Nothing to commit." and stop.
Warn and exclude .env / secret files.

### 2. Read the diff (no LLM)

Run `git diff` (and `git diff --cached` if staged changes exist). If over 300 lines, use `--stat` + Read tool on key files instead.

### 3. Stage + commit

Stage specific files by name — never `git add -A` or `git add .`.

Write one commit message:
- One line, max 72 chars
- Imperative verb (Add, Fix, Update, Remove, Refactor, Wire, Clean up)
- WHY/WHAT, not HOW
- No period, no co-author

```bash
git add <file1> <file2> ...
git commit -m "<message>"
```

### 4. Done

Run `git log --oneline -1` and display it. Nothing else.
