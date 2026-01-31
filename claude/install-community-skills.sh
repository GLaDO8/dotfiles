#!/bin/bash
# Install community skills (always gets latest versions)
# These are installed via npx and create symlinks in ~/.claude/skills/

set -e

echo "Installing community skills..."

# Use --agent to specify Claude Code, --yes to skip prompts, -g for global install
npx skills add vercel-labs/agent-browser --agent "claude-code" -g -y
npx skills add vercel-labs/agent-skills --agent "claude-code" -g -y       # web-design-guidelines
npx skills add supabase/agent-skills --agent "claude-code" -g -y          # postgres-best-practices
npx skills add vercel-labs/skills --agent "claude-code" -g -y             # find-skills

echo "Community skills installed successfully!"
