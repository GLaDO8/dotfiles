# RTK - Rust Token Killer (Codex CLI)

**Usage**: Token-optimized CLI proxy for shell commands.

## Rule

Default to `rtk` for simple shell commands.

Use direct shell commands instead of `rtk` for:
- `find`
- complex quoting
- heredocs/herestrings
- browser commands
- commands where exact raw stdout/stderr/exit behavior matters
- commands that previously failed because of `rtk` filtering or shell-shape handling

Examples:

```bash
rtk git status
rtk cargo test
rtk npm run build
rtk pytest -q
```

## Meta Commands

```bash
rtk gain            # Token savings analytics
rtk gain --history  # Recent command savings history
rtk proxy <cmd>     # Run raw command without filtering
```

## Verification

```bash
rtk --version
rtk gain
which rtk
```
