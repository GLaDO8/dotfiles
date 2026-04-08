# How to Plan

## Entering Plan Mode
- Enter plan mode for any non-trivial task (3+ steps or architectural decisions).
- NEVER jump to execution mode unless I ask you to do so.
- Liberally use the interview skill to refine the plan with questions before building.

## During Planning
- If something goes sideways, STOP and re-plan immediately.
- Plans should always exist within the project root. ALWAYS symlink it to `plan.md` in the current project root: `ln -sf <plan-path> ./plan.md`

## Large Plans
- When a plan document becomes longer than 300 lines, break the plan into smaller phase-wise plan files and store it in `plans/` folder and use the `plan.md` file as context + index for all plans.
