---
name: done
description: End-of-session summary that analyzes the full conversation and writes a structured markdown log to Obsidian. Use when the user says "done", wants to wrap up a session, or wants to capture what happened during a coding session.
---

# Session Summary to Obsidian

Analyze the full conversation, extract key insights, and write a structured session log to the Obsidian vault.

## Workflow

### Step 1: Gather Project Metadata

Run these bash commands to collect context:

```bash
# Project name: prefer package.json "name" field, fallback to folder basename
cat package.json 2>/dev/null | grep '"name"' | head -1 | sed 's/.*: *"//;s/".*//' || basename "$(pwd)"

# Git info (skip if not a git repo)
git remote get-url origin 2>/dev/null
git branch --show-current 2>/dev/null
git log --oneline -10 2>/dev/null

# Working directory and timestamp
pwd
date "+%Y-%m-%d %H:%M"

# Session ID (UUID from the most recent conversation transcript)
basename "$(ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -1)" .jsonl 2>/dev/null
```

Store the results:
- `project_name` — from package.json name or folder basename
- `git_remote` — remote URL (may be empty)
- `git_branch` — current branch (may be empty)
- `recent_commits` — last 10 commits as one-liners
- `working_dir` — absolute path
- `session_date` — YYYY-MM-DD
- `session_time` — HH:MM
- `session_id` — UUID from the most recent conversation transcript filename

### Step 2: Analyze the Conversation

Read through the FULL conversation history and extract:

1. **Session Objective** — What was the user trying to accomplish? One or two sentences.

2. **What Was Accomplished** — Bullet list of concrete outcomes:
   - Files created or modified
   - Features built or bugs fixed
   - Configurations changed
   - Commands run that had lasting effects

3. **Key Decisions** — Important choices made during the session and their rationale. Format as a table with columns: Decision, Rationale, Alternatives Considered.

4. **Session Arc** — A 2-4 paragraph narrative of how the session progressed. What was the starting point? What challenges came up? How did the approach evolve? This should read like a brief story of the session.

5. **My Prompts** — Every message the user sent, listed verbatim in chronological order. These are the raw steering inputs that drove the session. Format as a numbered list with each prompt in a blockquote.

6. **Mistakes & Corrections** — Only include this section if there were actual mistakes, wrong approaches, or corrections during the session. Skip entirely if the session went smoothly. Format as callout blocks.

7. **Open Items / Next Steps** — Anything left unfinished, ideas mentioned but not pursued, or natural follow-ups. Format as checkbox list.

### Step 3: Determine Output Path

The primary vault path is:
```
/Users/shreyasgupta/Library/Mobile Documents/iCloud~md~obsidian/Documents/iCloud vault/Claude Sessions/
```

1. Check if the `Claude Sessions/` folder exists inside the vault. If not, create it.
2. Generate the filename: `YYYY-MM-DD-<project_name>.md`
   - Sanitize project_name: lowercase, replace spaces/special chars with hyphens
3. Check if a file with that name already exists:
   - If yes, append a numeric suffix: `-2`, `-3`, etc.
   - Check incrementally until an unused name is found
4. If the vault path is unreachable (iCloud not syncing, path doesn't exist):
   - Fall back to `~/Desktop/Claude Sessions/`
   - Create the directory if needed
   - Warn the user: "Obsidian vault unreachable, wrote to ~/Desktop/Claude Sessions/ instead"

### Step 4: Write the File

Use the Write tool to create the markdown file with this exact structure:

```markdown
---
type: claude-session
project: <project_name>
date: <YYYY-MM-DD>
time: <HH:MM>
branch: <git_branch or omit if none>
remote: <git_remote or omit if none>
directory: <working_dir>
session_id: <session_id or omit if unavailable>
tags:
  - claude-session
  - <project_name>
---

# <Session Objective — short title>

## Objective

<1-2 sentence description of what the user set out to do>

## What Was Accomplished

- <concrete outcome 1>
- <concrete outcome 2>
- <...>

## Key Decisions

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| <decision> | <why> | <what else was considered> |

## Session Arc

<2-4 paragraph narrative of how the session unfolded>

## My Prompts

<numbered list of every user message, verbatim, each in a blockquote>

1. > <first user prompt>
2. > <second user prompt>
3. > <...>

## Mistakes & Corrections

> [!warning] <Brief title>
> **What happened:** <description>
> **Correction:** <what was done to fix it>

## Open Items

- [ ] <unfinished item or next step>
- [ ] <...>

## Recent Commits

```
<paste the git log --oneline -10 output here>
```
```

### Formatting Rules

- Use `[[<project_name>]]` wikilink syntax for the project name the first time it appears in the body text (not in frontmatter)
- Use `> [!warning]` callout syntax for Mistakes & Corrections entries
- Use `> [!note]` callout for any additional context blocks
- Use interactive checkboxes `- [ ]` for Open Items
- Omit the "Mistakes & Corrections" section entirely if there were none — do NOT include an empty section or "None" placeholder
- Omit `branch` and `remote` from frontmatter if not in a git repo
- Keep the Session Arc readable — no bullet points, just flowing paragraphs
- For "My Prompts", include EVERY user message, even short ones like "yes", "do it", "looks good" — these show the full interaction pattern

### Step 5: Confirm to User

After writing the file, output:

```
Session logged to: <full file path>
Session ID: <session_id>

Summary: <one-line description of what was captured>
Sections: <list which sections were populated>
```

## Edge Cases

### Very Short Session (< 5 user messages)
Use a minimal format — just Objective, What Was Accomplished, My Prompts, and Open Items. Skip Key Decisions, Session Arc, and Mistakes.

### No Code Changes Made
Focus on planning, research, or decisions. The "What Was Accomplished" section should reflect what was learned, decided, or planned rather than code changes.

### No Git Repository
- Skip git commands gracefully
- Use folder basename as project name
- Omit `branch` and `remote` from frontmatter
- Omit the "Recent Commits" section

### Session Was Mostly Q&A / Research
- Objective should reflect the research goal
- "What Was Accomplished" becomes key findings or answers
- Key Decisions becomes key insights or conclusions
- Session Arc describes the research journey

## Never

- Don't fabricate or embellish what happened — only include what actually occurred in the conversation
- Don't include system messages or tool outputs as "user prompts" — only actual user messages
- Don't create empty sections with "N/A" or "None" — omit them instead
- Don't truncate the My Prompts section — include every single user message
- Don't ask the user to review or approve before writing — just write it
- Don't modify any existing files in the vault
