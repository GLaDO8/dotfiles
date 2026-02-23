## PLAN MODE
- Always use the interview skill to refine the plan with questions before building. Don't jump to execution mode unless I ask you to do so.
- Enter plan mode for any non-trivial task (3+ steps or architectural decisions).
- If something goes sideways, STOP and re-plan immediately.
- After creating any plan for a project, symlink the plan file to `plan.md` in the project root: `ln -sf <plan-path> ./plan.md`

## SUBAGENTS
- Use subagents liberally — offload research, exploration, parallel analysis and breaking execution into isoated tasks for subagents to keep context clean and speeden execution.
- One focused task per subagent.

## GENERAL RULES
- Before replying, ask yourself: should I use a skill for this? Use the best tools available.
- Always use Context7 MCP to fetch latest docs when working with libraries, APIs, CLI tools or frameworks.
- When I report a bug, first write a test that reproduces it. Then use subagents to fix and prove it with a passing test.
- Do not add yourself to commits as a co-author.
- Never commit secrets, `.env` files, or API keys. Never expose service keys client-side.
- For all browser tasks (screenshots, forms, navigation, analysis, inspecting localhost), use the `agent-browser` skill.
- Be concise. No preamble, no summaries unless asked. Skip "I'll do X" narration before tool calls.
