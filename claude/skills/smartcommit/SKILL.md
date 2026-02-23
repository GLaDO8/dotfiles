---
name: smartcommit
description: Generate a concise commit message and commit all changes. Use when you want to quickly commit work with an auto-generated message.
---

# Smart Commit

Analyze all staged and unstaged changes, generate a concise commit message, and commit.

## Workflow

1. **Check for changes**
   Run `git status` to see what's changed.
   If no changes, inform user and stop.

2. **Stage all changes**
   Run `git add -A` to stage everything.

3. **Analyze the diff**
   Run `git diff --cached --stat` for overview.
   Run `git diff --cached` for details (limit to first 200 lines if large).

4. **Generate commit message**
   Create a message that is:
   - One line, max 72 characters
   - Starts with a verb (Add, Fix, Update, Remove, Refactor, Improve)
   - Focuses on WHAT changed, not HOW
   - No periods at the end

5. **Commit**
   Run commit with generated message.

6. **Check if CLAUDE.md needs updating**
   After committing, check if any of these architectural files were changed:
   - `package.json` (new dependencies)
   - `lib/supabase*.ts` (database patterns)
   - `app/api/**` (new API routes)
   - `app/actions/**` (new server actions)
   - `.env*` files (new environment variables)
   - `tsconfig.json`, `next.config.*` (config changes)
   - New directories or major structural changes

   If architectural changes detected:
   - List what changed
   - Suggest specific updates to CLAUDE.md
   - Ask user if they want to apply the updates now

## Message Style

Good:
- `Add user authentication flow`
- `Fix null check in product scraper`
- `Update API endpoint for categories`
- `Remove deprecated helper functions`
- `Refactor database queries for performance`

Bad:
- `Updated some files` (vague)
- `Fix bug` (what bug?)
- `WIP` (not descriptive)
- `Changes to user.ts, auth.ts, and api.ts` (lists files, not purpose)

## Commit Format

```bash
git add -A && git commit -m "<generated message>"
```

## Output

```
Staged 3 files:
  M  src/components/Button.tsx
  M  src/lib/utils.ts
  A  src/hooks/useAuth.ts

Committed: Add authentication hook with login state management
```

## Output (with CLAUDE.md check)

```
Staged 4 files:
  M  package.json
  A  app/api/categories/route.ts
  A  lib/category-utils.ts
  M  lib/types.ts

Committed: Add category filtering API endpoint

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 CLAUDE.md may need updates:

Architectural changes detected:
  • package.json - Check for new dependencies
  • app/api/categories/route.ts - New API endpoint

Suggested updates:
  1. Add to "Project Structure" → api/ section:
     │   ├── categories/  # Category filtering endpoint

  2. Add to "RPC Functions" if new RPC was added

Update CLAUDE.md now? [y/N]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Never

- Don't commit if there are no changes
- Don't include file names in the message (unless it's a single config file change)
- Don't use generic messages like "misc changes" or "updates"
- Don't commit .env files or secrets (warn and exclude)
