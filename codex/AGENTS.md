# Global rules and conventions.

## On-Demand Instructions
Before starting any task, identify which docs below are relevant and read them first.

`~/.agents/agent-docs/how-to-plan.md` - Read only when the user asks for a plan/plan mode, the task needs architectural decisions, or the work is broad enough that you would create or update a plan file. Do not read it for a normal inspect -> edit -> verify loop.
`~/.agents/agent-docs/cli-tools.md` - Read only when choosing a specialized CLI for refactoring, benchmarking, structural search, diffing, or config/data processing. Do not read it for routine `rg`, `sed`, `git`, `pnpm`, or simple file inspection.

## SUBAGENTS
- Use subagents liberally. One focused task per subagent. Parallelize when independent.
- Spawn for 3+ file reads, parallel research, multi-step refactors, and risky operations.
- Don't spawn for single file reads, simple greps, or questions answerable from local context.

## GENERAL RULES
- Use the best available skill or tool when one clearly applies. 
- When debugging a bug, add a reproducing test first, then fix it and prove it with a passing test.
- Do not add yourself to commits as a co-author.
- Never commit secrets, `.env` files, API keys, or tokens.
- Be concise. Skip preamble and avoid narration before tool calls.
- Never start a dev server if one is already running.

<!-- context7 -->
## CONTEXT 7
Use `ctx7` for current library/framework/SDK/API/CLI/cloud docs, but only when it matters - unfamiliar syntax, version-specific behavior, migration/config details, user explicitly asks for docs, or you are not confident from local code/context. It is not necessary for routine repo work, refactors, business-logic debugging, code review, general programming concepts, or APIs/commands already proven in the current session.

When using it:
1. Resolve: `npx ctx7@latest library <name> "<question>"` — use the official library name with proper punctuation (e.g., "Next.js" not "nextjs", "Customer.io" not "customerio", "Three.js" not "threejs")
2. Fetch: `npx ctx7@latest docs <libraryId> "<question>"`

Use at most 3 ctx7 commands per question. Never include secrets in queries.

@/Users/shreyasgupta/.codex/RTK.md

<!-- BEGIN COMPOUND CODEX TOOL MAP -->
## Compound Codex Tool Mapping (Claude Compatibility)

This section maps Claude Code plugin tool references to Codex behavior.
Only this block is managed automatically.

Tool mapping:
- Read: use shell reads (cat/sed) or rg
- Write: create files via shell redirection or apply_patch
- Edit/MultiEdit: use apply_patch
- Bash: use shell_command
- Grep: use rg (fallback: grep)
- Glob: use rg --files or find
- LS: use ls via shell_command
- WebFetch/WebSearch: use curl or Context7 for library docs
- AskUserQuestion/Question: present choices as a numbered list in chat and wait for a reply number. For multi-select (multiSelect: true), accept comma-separated numbers. Never skip or auto-configure — always wait for the user's response before proceeding.
- Task/Subagent/Parallel: run sequentially in main thread; use multi_tool_use.parallel for tool calls
- TodoWrite/TodoRead: use file-based todos in todos/ with todo-create skill
- Skill: open the referenced SKILL.md and follow it
- ExitPlanMode: ignore
<!-- END COMPOUND CODEX TOOL MAP -->
