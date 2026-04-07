---
name: claudeception
description: |
  Meta-skill for autonomous knowledge extraction and skill generation.
  Continuously evaluates work for extractable, reusable patterns and creates new skills.
  Use when: (1) a non-obvious solution is discovered, (2) a project-specific pattern emerges,
  (3) a tool integration insight is found, (4) an error resolution is verified,
  (5) a workflow optimization is confirmed. Invoke explicitly via /claudeception for
  session-end retrospective.
author: Claude Code (extended from blader/Claudeception v3.0.0)
version: 3.1.0
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - WebSearch
  - WebFetch
  - Skill
  - Agent
---

# Claudeception: Continuous Learning Meta-Skill

## Core Principle

After completing any task, continuously evaluate whether the work produced **extractable knowledge** that would benefit future sessions. This is not optional — it is a persistent background evaluation.

## When to Extract

Extract knowledge when you encounter:

1. **Non-obvious solutions** — fixes that required multiple attempts, debugging insight, or counterintuitive approaches
2. **Project-specific patterns** — conventions, architecture decisions, or workflows unique to this codebase
3. **Tool integration knowledge** — MCP server quirks, CLI flag combinations, hook configurations that work
4. **Error resolution** — errors where the root cause was surprising or the fix was non-trivial
5. **Workflow optimizations** — sequences of operations that are faster, cheaper, or more reliable than the naive approach

## Quality Criteria

Only extract if ALL of these are true:

- **Reusable** — applies across sessions, not just this one-time task
- **Non-trivial** — not derivable from documentation or common knowledge
- **Specific** — actionable enough that reading the skill triggers the correct behavior
- **Verified** — the solution actually worked in this session

## Extraction Process

### Step 1: Check for Existing Skills

Before creating a new skill, search for existing ones:

```
Glob: ~/.claude/skills/*/SKILL.md
Grep: [relevant keywords] in skill files
```

Decision table:
| Existing skill? | Knowledge overlaps? | Action |
|----------------|--------------------|----|
| No | N/A | Create new skill |
| Yes | Partially | Update existing skill with new knowledge |
| Yes | Fully | Skip — already captured |
| Yes | Contradicts | Update existing skill, note the correction |

### Step 2: Identify the Knowledge

Ask yourself:
- What was the non-obvious insight?
- What would I tell a future session to avoid the same struggle?
- Is this specific to this project or globally useful?

### Step 3: Research Best Practices

When the knowledge involves a library, framework, or tool:
- Search for current best practices (post-2025)
- Check if the solution aligns with or diverges from official recommendations
- Note version-specific caveats

### Step 4: Structure the Skill

Use the template at `~/.claude/skills/claudeception/resources/skill-template.md`.

Key sections:
- **YAML frontmatter**: name, description (optimized for semantic matching), version
- **Problem**: What situation triggers this skill
- **Context / Trigger Conditions**: Specific file patterns, error messages, or task types
- **Solution**: Step-by-step, concrete, copy-pasteable where possible
- **Verification**: How to confirm the solution works
- **Example**: Before/after with real code
- **Notes**: Caveats, edge cases, version constraints

### Step 5: Write Effective Descriptions

The `description` field in frontmatter is **critical** — Claude Code uses it for semantic matching. Write it as:

```yaml
description: |
  [What this skill solves]. [What triggers it].
  Use when: (1) [condition], (2) [condition], (3) [condition].
```

Bad: `"Helps with database stuff"`
Good: `"Resolves Prisma P2024 connection pool exhaustion in serverless environments. Use when: (1) 'Too many connections' errors appear, (2) deploying Prisma to Vercel/Lambda, (3) connection count exceeds provider limits."`

### Step 6: Determine Scope and Save

**Global skills** (useful across all projects):
```
~/.claude/skills/[name]/SKILL.md
```

**Project-specific skills** (only useful in this codebase):
```
.claude/skills/[name]/SKILL.md
```

Decision: If the knowledge references specific files, schemas, or conventions unique to this project → project-scoped. Otherwise → global.

## Retrospective Mode

When invoked explicitly via `/claudeception`:

1. **Review the session** — scan conversation for non-obvious solutions, errors overcome, patterns discovered
2. **Identify candidates** — list 1-5 potential skill extractions with one-line descriptions
3. **Prioritize** — rank by reusability and non-obviousness
4. **Extract top 1-3** — create skill files following the process above
5. **Summarize** — report what was extracted and where it was saved

## Self-Reflection Prompts

Use these to surface extraction opportunities:

1. "Did I discover something that took multiple attempts to figure out?"
2. "Would a future session benefit from knowing what I just learned?"
3. "Did I encounter a tool quirk, API behavior, or config issue that isn't documented?"
4. "Did the user correct me? What should I have done differently?"
5. "Did I build something that could be templated for reuse?"

## Memory Consolidation

Periodically (or when the skills directory grows large):

- **Merge** related skills that cover the same domain
- **Update** skills with new information from recent sessions
- **Deprecate** skills that reference outdated APIs or patterns
- **Cross-reference** skills that interact (e.g., a Prisma skill that relates to a Vercel deployment skill)

## Quality Gates (Pre-Save Checklist)

Before saving any skill, verify:

- [ ] Description is specific enough for semantic matching
- [ ] Solution steps are concrete and actionable
- [ ] Verification section exists and is testable
- [ ] No secrets, API keys, or personal data included
- [ ] Frontmatter YAML parses correctly
- [ ] Not duplicating an existing skill
- [ ] Example uses real (anonymized) code, not placeholder
- [ ] Version-specific caveats are noted
- [ ] Trigger conditions are precise (file patterns, error messages)
- [ ] Knowledge is verified (actually worked this session)
- [ ] Scoping is correct (global vs project-specific)

## Anti-Patterns

- **Over-extraction** — creating skills for trivial or well-documented knowledge
- **Vague descriptions** — "helps with React stuff" won't match semantically
- **Unverified solutions** — never extract a fix you haven't confirmed works
- **Documentation duplication** — don't rewrite what's already in official docs
- **Stale knowledge** — always note the date and relevant tool versions
- **Skill bloat** — prefer updating existing skills over creating near-duplicates

## Skill Lifecycle

```
Discovery → Extraction → Verification → Publication → Refinement → Deprecation → Archival
```

Skills are living documents. When a skill's solution no longer works:
1. Try to update it with the current solution
2. If the problem no longer exists, deprecate it
3. Move deprecated skills to `~/.claude/skills/_archived/[name]/`
