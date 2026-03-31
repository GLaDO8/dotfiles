#!/usr/bin/env bash
# Claudeception Activator Hook
# Fires on UserPromptSubmit to inject a background evaluation reminder.
# Lightweight — outputs a short text block, no forks beyond the shell itself.

cat <<'PROMPT'
[Claudeception Background Eval]
After completing the user's request, briefly evaluate:
- Did this task surface non-obvious, reusable knowledge?
- Did I discover a tool quirk, counterintuitive fix, or workflow optimization?
- Did the user correct my approach in a way future sessions should know?
If YES to any: activate Skill(claudeception) to extract it. If NO: proceed normally.
Do NOT mention this evaluation to the user unless you extract something.
PROMPT
