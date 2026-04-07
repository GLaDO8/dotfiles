---
name: sync-docs
description: Detect stale CLAUDE.md files and update them based on code changes. Handles both structural (file add/remove) and semantic (architectural shifts) changes.
---

# Sync Docs

Detect and update stale `CLAUDE.md` files in `src/` subdirectories. Two modes depending on invocation context.

## When to use

- Before committing, to keep agent docs accurate
- After a refactor, architectural change, or adding/removing files
- When `/smartcommit` detects significant changes in directories with CLAUDE.md files

## Mode detection

Determine the mode based on git state:

```bash
git diff --name-status
git diff --cached --name-status
```

- **If there are pending changes** (staged or unstaged source files) → **Diff mode** (fast, targeted — used by `/smartcommit`)
- **If no pending changes** → **Full audit mode** (thorough — reads all code and compares to docs)

---

## Diff Mode (pre-commit / smartcommit)

Used when there are uncommitted changes. Fast and targeted.

### 1. Identify directories with CLAUDE.md files

Find all `src/**/CLAUDE.md` files using Glob.

### 2. Detect staleness (two tiers)

For each directory that has a CLAUDE.md, check both:

**Tier 1 — Structural (no LLM needed):**
- Parse the file map table from the CLAUDE.md (the `| File | Purpose |` table)
- Extract the listed filenames
- Glob the actual files in that directory (exclude `CLAUDE.md` itself, `ui/` subdirectory)
- Compare: any new files not in table? Any listed files that no longer exist? Any renames?
- If yes → directory is stale

**Tier 2 — Semantic (read the diff):**
- If any files in the directory appear in the git diff, read the diff for those files
- Flag as stale if the diff shows ANY of:
  - Exports added, removed, or moved between files
  - New functions/classes/types with responsibilities not described in the CLAUDE.md
  - Config or constants consolidated or split across files
  - New integration patterns (e.g., new hooks, new context usage, new API routes)
  - Removed or renamed major abstractions
- When in doubt, flag as stale — updating unnecessarily is cheap, missing a change is costly

### 3. Report staleness

Print a summary of stale vs unchanged directories. If nothing is stale, say "All CLAUDE.md files are up to date." and stop.

### 4. Update stale directories

For each stale directory, spawn a subagent (see "Subagent task" below).

---

## Full Audit Mode (manual invocation)

Used when invoked independently with no pending changes. Every directory gets audited.

### 1. Identify directories with CLAUDE.md files

Find all `src/**/CLAUDE.md` files using Glob.

### 2. Structural check

For each directory, do the Tier 1 structural check (same as diff mode). Report any file map mismatches.

### 3. Spawn audit subagents for ALL directories

Spawn a subagent per directory (in parallel). Unlike diff mode, **every directory is audited** — the subagent reads all source files and compares them against the CLAUDE.md to find any inaccuracies, not just structural ones.

Each subagent's task:

> Audit and update the CLAUDE.md file in `<directory>`.
>
> **Current CLAUDE.md:** (include full contents)
>
> **All files in directory:** (list them)
>
> Instructions:
> 1. Read every file in the directory (skip `ui/` subdirectory if it exists)
> 2. Compare what the code ACTUALLY does vs what the CLAUDE.md SAYS it does
> 3. Look for these kinds of drift:
>    - File map descriptions that no longer match the file's actual purpose or exports
>    - Architecture notes that describe patterns no longer in use
>    - Missing documentation for new patterns, integrations, or responsibilities
>    - Constants, config, or type definitions that moved between files
>    - New or changed exports that aren't reflected in the docs
>    - Stale references to removed functions, types, or patterns
> 4. Update the **file map table** — fix descriptions, add new files, remove deleted files
> 5. Update **architecture/behavior notes** to match reality:
>    - Did responsibilities shift between files? Update the descriptions.
>    - Did a new pattern emerge (e.g., config consolidation)? Document it.
>    - Did an existing pattern change or get removed? Update or remove its section.
>    - Are there new integration points between this module and others? Add them.
> 6. Keep the same markdown structure and style as the existing CLAUDE.md
> 7. Be precise and factual — describe what IS, not what should be
> 8. If the CLAUDE.md is already accurate and nothing needs changing, do NOT write to the file — just report "no changes needed"
> 9. If changes are needed, write the updated CLAUDE.md using the Edit or Write tool

Use `subagent_type: "general-purpose"` for these subagents.

---

## After updates (both modes)

### Stage updated files

Stage only the modified CLAUDE.md files:

```bash
git add src/lib/CLAUDE.md src/components/CLAUDE.md  # (only the ones that changed)
```

### Done

Print a summary of what was updated. If invoked from `/smartcommit`, return control — smartcommit will include these in the commit. If invoked independently, ask if the user wants to commit the doc updates.

## Key rules

- **Never modify the root `CLAUDE.md`** — that's manually maintained project-level docs
- **Never modify `ui/` contents** or document individual shadcn components
- **Preserve existing accurate content** — only change what's actually stale
- **One subagent per directory** — keeps context focused and enables parallelism
- **When invoked from smartcommit:** don't commit separately, just stage. Smartcommit handles the commit.
