---
name: bash-perf-patterns
description: Optimize bash scripts for minimal fork count and maximum safety. Use when writing or reviewing shell scripts that run frequently (hooks, statuslines, watchers), need to be fast, or handle untrusted input. Covers fork elimination, jq batching, shell injection prevention, macOS locking, and integer arithmetic safety.
---

# Bash Performance & Safety Patterns

Apply these patterns when writing bash scripts that run on hot paths (hooks, statuslines, CI checks) where every fork matters, or when handling untrusted/external input.

## 1. Fork Elimination

Every `$(command)` or `command | command` spawns a subprocess. Target: count your forks and minimize them.

### `$(cat)` → `read -d ''`

```bash
# BAD: 1 fork
input=$(cat)

# GOOD: 0 forks (bash builtin)
IFS= read -r -d '' input
```

`IFS=` prevents word splitting, `-r` prevents backslash interpretation, `-d ''` reads until EOF (not just newline). This is the single most common unnecessary fork in shell scripts.

### `echo "$var" | jq` → `jq <<< "$var"`

```bash
# BAD: 2 forks (echo subshell + jq)
value=$(echo "$input" | jq -r '.field')

# GOOD: 1 fork (jq only, here-string)
value=$(jq -r '.field' <<< "$input")
```

Here-strings (`<<<`) feed stdin to a command without a pipe subshell. Saves 1 fork per call.

### `cat file | jq` → `jq file`

```bash
# BAD: 2 forks
data=$(cat "$file" | jq '.key')

# GOOD: 1 fork
data=$(jq '.key' "$file")
```

jq accepts a filename argument directly — no need for cat.

### `wc -c < file` → `${#var}`

```bash
# BAD: 1 fork
size=$(wc -c < "$file")

# GOOD: 0 forks (bash builtins)
content=$(<"$file")
size=${#content}
```

`$(<file)` is a bash builtin that reads a file without forking. `${#var}` gives string length.

### Multiple field extractions → single `@sh` eval

```bash
# BAD: 4 forks (2× echo + 2× jq)
name=$(echo "$json" | jq -r '.name')
age=$(echo "$json" | jq -r '.age')

# GOOD: 1 fork (1× jq, @sh-quoted eval)
eval "$(jq -r '
  @sh "name=\(.name // "")",
  @sh "age=\(.age // 0)"
' <<< "$json" 2>/dev/null)"
```

Batches N field extractions into 1 jq invocation. The `@sh` filter handles quoting.

## 2. jq Safety: `@sh` vs `--arg`

### `@sh` — for eval blocks (shell receives the value)

```bash
eval "$(jq -r '@sh "var=\(.field)"' <<< "$json")"
```

`@sh` produces POSIX shell-quoted strings. Use when values flow through `eval`. Prevents injection if JSON contains `$(rm -rf /)` or backticks.

### `--arg` / `--argjson` — for jq expressions (jq receives the value)

```bash
# BAD: injection via string interpolation
jq ".${key} = \"$value\"" "$file"    # key="]; system(\"rm -rf /\"); .[" → RCE

# GOOD: --arg binds as jq variables, never interpreted as jq code
jq --arg key "$key" --arg val "$value" '.[$key] = $val' "$file"
```

`--arg` is strictly safer than `@sh` because values never pass through shell eval. **Always prefer `--arg`/`--argjson` when writing jq expressions that modify files.** Use `@sh` only for the read-into-shell-variables pattern.

### Decision rule

| Data flow | Pattern | Safety mechanism |
|-----------|---------|------------------|
| JSON → shell variables | `eval "$(jq -r '@sh ...')"` | `@sh` quoting |
| Shell variables → jq expression | `jq --arg key "$k" '.[$key]'` | `--arg` binding |
| **Never do** | `jq ".${var} = $val"` | *none — injectable* |

## 3. macOS File Locking with `lockf`

### Command mode (the only mode on macOS)

```bash
lockf [-knsw] [-t seconds] file command [arguments]
```

**macOS `lockf` does NOT support fd-based locking.** That's Linux `flock`. Don't confuse them.

### Pattern: locked read-modify-write

```bash
# Pass data via env vars (avoids quoting hell in sh -c)
_MY_FILE="$file" _MY_KEY="$key" _MY_VAL="$val" \
lockf -s -t 2 "${file}.lock" /bin/sh -c '
  jq --arg key "$_MY_KEY" --arg val "$_MY_VAL" \
    '"'"'.[$key] = $val'"'"' \
    "$_MY_FILE" > "${_MY_FILE}.tmp" && mv "${_MY_FILE}.tmp" "$_MY_FILE"
' 2>/dev/null
```

Key details:
- `-s` = silent (no error messages)
- `-t 2` = timeout 2 seconds (skip if can't lock)
- Env vars with `_PREFIX` pass data without export pollution
- `'"'"'` = standard way to embed single quote inside single-quoted string
- `mv` for atomic file replacement (prevents partial reads)
- `2>/dev/null` suppresses lockf errors (hook must never produce stderr)

### Fork cost

`lockf file /bin/sh -c '...'` adds 2 forks (lockf + sh). Budget accordingly.

## 4. Integer Arithmetic Safety

### Float truncation (jq can return floats)

```bash
# jq might return "85.5" — bash arithmetic crashes on floats
used_pct=${used_pct%.*}   # "85.5" → "85"
```

### Division-by-zero guard

```bash
[ "$denominator" -le 0 ] 2>/dev/null && denominator=200000
```

The `2>/dev/null` handles the case where `$denominator` is empty or non-numeric.

### Cascading overflow adjustment

When distributing N items across a fixed-width container with minimum constraints:

```bash
diff=$((total - target))
if [ $diff -gt 0 ]; then
  # Steal from lowest-priority first
  steal=$diff
  [ $steal -gt ${bucket[0]} ] && steal=${bucket[0]}
  bucket[0]=$((bucket[0] - steal))
  diff=$((diff - steal))

  # Then next priority
  if [ $diff -gt 0 ]; then
    bucket[1]=$((bucket[1] - diff))
    [ ${bucket[1]} -lt 1 ] && bucket[1]=1  # enforce minimum
  fi
fi
```

Always track remaining `diff` through each stage. Clamping to 0 without tracking the excess is a bug — the container overflows.

## 5. Directory Security in /tmp

```bash
dir="/tmp/my-app-data"
[ -d "$dir" ] || { mkdir -p "$dir" && chmod 700 "$dir"; } 2>/dev/null
```

- `[ -d ]` guard avoids chmod on every invocation
- `chmod 700` prevents other users from reading/writing your data in shared `/tmp`
- Group the mkdir+chmod in `{ }` so chmod only runs if mkdir succeeds

## 6. Counting Forks (Audit Technique)

To audit a script's fork count:

1. Count every `$(...)` command substitution
2. Count every `cmd | cmd` pipe (each side is a fork)
3. Count every external command (`jq`, `git`, `grep`, `sed`, `awk`, `cat`, `wc`, `mkdir`, `chmod`)
4. Subtract bash builtins: `read`, `printf`, `echo`, `[`, `[[`, `case`, `${#var}`, `$(<file)`, arithmetic `$(( ))`

Target for hot-path scripts: **2-3 forks**. Each fork costs ~2-5ms on macOS.

## Quick Reference

| Instead of | Use | Forks saved |
|------------|-----|-------------|
| `$(cat)` | `IFS= read -r -d '' var` | 1 |
| `echo "$x" \| jq` | `jq ... <<< "$x"` | 1 |
| `cat file \| jq` | `jq ... file` | 1 |
| `wc -c < file` | `c=$(<file); ${#c}` | 1 |
| N × `echo \| jq -r .field` | 1 × `eval "$(jq -r '@sh ...')"` | 2×(N-1) |
| N × `echo \| jq .field` + write | 1 × `jq --arg ... file > tmp && mv` | 2×(N-1) |
| `jq ".${var}"` | `jq --arg v "$var" '.[$v]'` | 0 (security fix) |
