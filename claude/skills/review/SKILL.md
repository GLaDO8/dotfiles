---
name: review
description: Comprehensive code review — runs symbolic tools first (free, fast), then spawns LLM agents for project-specific analysis. Use for thorough code quality checks before commits or PRs.
---

# /review — Comprehensive Code Review

Two-phase review: deterministic tools first, then targeted LLM analysis.

## Phase 1: Symbolic Analysis (fast, free, deterministic)

Run all 5 tools in sequence. Report findings from each. Auto-fix what's safe.

### Step 1 — Type check
```bash
tsc --noEmit
```
Report any type errors. These block everything — fix before proceeding.

### Step 2 — ESLint
```bash
npx eslint
```
Report Next.js-specific and React hooks issues.

### Step 3 — Biome
```bash
biome check --write .
```
Auto-fixes formatting + import organization. Then run `biome check .` to report remaining warnings.

### Step 4 — Knip

First check if knip is available by running `npx knip --version`. If it fails or is not installed, run the `/knip` skill instead (it handles setup, config creation, and the full cleanup workflow) then resume with Step 5.

If knip is available:
```bash
npx knip
```
Report unused dependencies, exports, and files. Run `npx knip --fix` for safe auto-removals.

If issues remain after `--fix` (items that need judgment — possible entry points, public API exports, CLI-only deps), note the count in the summary table and suggest: *"Run `/knip` for interactive cleanup of the remaining items."*

### Step 5 — Circular dependencies
```bash
npx madge --circular --ts-config tsconfig.json src/
```
Report any cycles found.

### Symbolic Summary
After running all 5 tools, provide a summary table:

```
| Tool     | Status | Issues |
|----------|--------|--------|
| tsc      | ✓/✗    | count  |
| eslint   | ✓/✗    | count  |
| biome    | ✓/✗    | count  |
| knip     | ✓/✗    | count  |
| madge    | ✓/✗    | count  |
```

If all tools pass clean, skip Phase 2 unless the user explicitly requests LLM review.

## Phase 2: LLM Analysis (targeted, uses tokens)

Determine what changed using `git diff` (staged + unstaged) or `git diff main...HEAD` (for branch reviews).

Based on the diff, spawn **only** the relevant compound-engineering review agents as subagents. Skip agents whose domain wasn't touched.

### Agent selection matrix

| Agent | When to spawn |
|-------|---------------|
| `pattern-recognition-specialist` | Always — checks naming, duplication, consistency |
| `code-simplicity-reviewer` | Always — checks for YAGNI and over-engineering |
| `performance-oracle` | Perf-sensitive code changed (rendering, physics, simulation, large data transforms) |
| `security-sentinel` | Auth, API routes, input handling, env vars, or external service calls changed |
| `architecture-strategist` | New files/modules added, or significant structural changes |

### How to spawn

Use the Task tool with the appropriate `subagent_type` from compound-engineering. Each agent gets:
- The diff of changed files
- Brief context about what the project does
- Instruction to focus only on actionable findings

### Phase 2 Summary
Aggregate findings from all spawned agents. Deduplicate overlapping observations. Present as a prioritized list:
1. **Must fix** — correctness issues, security problems
2. **Should fix** — naming issues, code smells, missing edge cases
3. **Consider** — style preferences, optional improvements

## Notes
- Phase 1 is always run. Phase 2 is run by default but can be skipped with `/review --symbolic-only` or `/review --fast`.
- If the user says `/review --full`, run all Phase 2 agents regardless of diff scope.
- Biome auto-fixes are committed separately if they touch many files (to keep `git blame` clean).
