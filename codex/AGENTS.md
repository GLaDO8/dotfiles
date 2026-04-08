Global rules and conventions. Detailed instructions live in `~/.agents/agent-docs/` and are loaded on demand — read the relevant file when a trigger matches.

## On-Demand Instructions
Before starting any task, ALWAYS identify which docs below are relevant and read them first. Load the full context before making changes.

`~/.agents/agent-docs/how-to-plan.md` - (For when planning, entering plan mode, or for non-trivial tasks (3+ steps))
`~/.agents/agent-docs/statusline.md` - (For when modifying statusline.sh, context-tracker.sh, or the statusline visual design)
`~/.agents/agent-docs/cli-tools.md` - (For when doing code refactoring, benchmarking, diffing, or config file processing via Bash)

## SUBAGENTS
- Use subagents liberally. One focused task per subagent. Parallelize when independent.
- **Spawn when**: 3+ file reads, parallel research, multi-step refactors, risky ops (use worktree).
- **Don't spawn for**: single file reads, simple greps, answering from memory.
- `compound-engineering` plugin has specialized agents (code review, frontend, security, research) — use when the task clearly benefits.

## STYLING
- **Strictly Tailwind v4 utility classes** — no inline styles, no `<style>` blocks, no CSS modules.

## GENERAL RULES
- Before replying, ask yourself: should I use a skill for this? Use the best tools available.
- Always use Context7 MCP to fetch latest docs when working with libraries, APIs, CLI tools or frameworks.
- When I report a bug, first write a test that reproduces it. Then use subagents to fix and prove it with a passing test.
- Do not add yourself to commits as a co-author.
- Never commit secrets, `.env` files, or API keys. Never expose service keys client-side.
- For browser testing (localhost, screenshots, forms, navigation), use the `agent-browser` skill. Keep iterating till no visual issues remain. Only use `/chrome` for authenticated sessions or real-time visual inspection.
- Be concise. No preamble, no summaries unless asked. Skip "I'll do X" narration before tool calls.
- When I say "watch mode", call agentation_watch_annotations tool call from Agentation MCP in a loop. For each annotation: acknowledge it, make the fix, then resolve it with a summary. Continue watching until I say stop or timeout is reached.

@RTK.md
