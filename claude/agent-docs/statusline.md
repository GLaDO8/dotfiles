# Statusline — Context Window Visualizer

Read this before modifying `~/.claude/statusline.sh` or `~/.claude/hooks/context-tracker.sh`.

## Architecture

Four files work together:

1. **`~/.claude/statusline.sh`** — Renders the status bar. Called by Claude Code via `settings.json` → `statusLine.command`. Receives JSON on stdin with model, session, context metrics, cost. Outputs 1-5 ANSI-colored lines depending on display modes. Also writes the current model to a sidecar file for the tracker, and persists session cost data for cross-session aggregation.

2. **`~/.claude/hooks/context-tracker.sh`** — PostToolUse hook. Estimates token consumption per tool call by measuring the hook payload size (`chars / 4`). Writes cumulative totals (including per-model stats) to `/tmp/claude-context-tracker/<session_id>.json`. Uses `lockf` for concurrency-safe read-modify-write and `--arg`/`@sh` for injection-safe jq interpolation.

3. **`~/.claude/statusline.conf`** — Display preferences (`show_model`, `show_cost`, `show_cwd`, `cost_scope`). Sourced by statusline.sh on each render. Toggled by the `/sl` skill.

4. **`~/.claude/project-costs/<encoded-path>/<session_id>`** — Per-session cost files for cross-session project cost aggregation. Written by statusline.sh on each render.

## Visual Design (v5.2)

### Line Hierarchy

```
Line 1 (show_cwd=1):   ~/local-documents/ai-grading
Line 2 (always):       ███████▊████▊█▊███▊████████████████████▊█████▊  72k/200k ($8.44)  Claude 4.6 Opus  [main]
Line 3 (always):       tools-12k mcp-4k chat-8k (system-5k, schemas-11k, skills-3k)
Line 4 (show_cost=1):  ————————————————————————————————————————————————————————————————————————————
Line 5 (show_cost=1):  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▖▄▖▄▄▄▄▄▄▄▖               (30 chars, color-coded)
Line 6 (show_cost=1, scope=session):  $8.44 - $3.20 $2.10 ($1.30, $0.50, $0.29)
Line 6 (show_cost=1, scope=project): $47.12 (5 sesh) - $15.40 $12.50 ($7.80, $3.10, $2.12)
Line 7 (show_model=1): opus-84k(47) sonnet-8k(12) haiku-1k(3)
```

Default (show_cwd=1, show_cost=0, show_model=0): **3 lines** (CWD + bar + legend).
Full display (all on): **7 lines**.

Zero-cost categories are hidden from the cost line. If mcp-$0.00 or any other category is $0, it's omitted entirely.

### Display Modes

**Default** (3 lines — CWD + bar + legend):
```
~/my-project
███████▊████▊█▊███▊████████████████████▊█████▊  72k/200k ($8.44)  Claude 4.6 Opus  [main]
tools-12k mcp-4k chat-8k (system-5k, schemas-11k, skills-3k)
```

**Cost breakdown ON** (`show_cost=1`, adds Lines 4-6 — session scope):
```
~/my-project
███████▊████▊█▊███▊████████████████████▊█████▊  72k/200k ($8.44)  Claude 4.6 Opus  [main]
tools-12k mcp-4k chat-8k (system-5k, schemas-11k, skills-3k)
————————————————————————————————————————————————————————————————————————————
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▖▄▄▄▄▄▄▄▄▖▄▄▄▄▄▄▄▄▄▖
$8.44 - $3.20 $2.10 ($1.30, $0.50, $0.29)
```

Note: zero-cost categories are hidden from both bar and text. If mcp=$0, it won't appear.
No labels — color acts as the legend (matches the bar segments above).

**Cost breakdown ON** (`show_cost=1, cost_scope=project`, adds Lines 4-6 — project scope):
```
~/my-project
███████▊████▊█▊███▊████████████████████▊█████▊  72k/200k ($8.44)  Claude 4.6 Opus  [main]
tools-12k mcp-4k chat-8k (system-5k, schemas-11k, skills-3k)
————————————————————————————————————————————————————————————————————————————
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▖▄▄▄▄▄▄▄▄▖▄▄▄▄▄▄▄▄▄▖
$47.12 (5 sesh) - $15.40 $12.50 ($7.80, $3.10, $2.12)
```

**Model breakdown ON** (`show_model=1`, adds Line 7):
```
~/my-project
███████▊████▊█▊███▊████████████████████▊█████▊  72k/200k ($8.44)  Claude 4.6 Opus  [main]
tools-12k mcp-4k chat-8k (system-5k, schemas-11k, skills-3k)
opus-84k(47) sonnet-8k(12) haiku-1k(3)
```

### Bar: 36 × █, uniform blocks, truecolor

| Segment | Color hex | RGB | Meaning |
|---------|-----------|-----|---------|
| Results (tool+agent) | `#FC66B1` | `252;102;177` (pink) | Tool results + subagent results merged |
| MCP | `#37F3BA` | `55;243;186` (teal) | MCP tool results (Figma, Supabase, etc.) |
| Chat | `#CAFF44` | `202;255;68` (green) | User messages + assistant reasoning |
| Overhead | `#999999` | `153;153;153` (grey) | System prompt, tool defs, skills, memory — immutable |
| Free | `#393939` | `57;57;57` (dark grey) | Available usable space |
| Buffer | `#222222` | `34;34;34` (near-black) | Autocompact reserve (16.5%) — unusable |

Additional colors:
| Element | Color hex | RGB | Usage |
|---------|-----------|-----|-------|
| CWD | `#82AAFF` | `130;170;255` (soft blue) | Working directory on Line 1 |
| Git branch | `#F39B37` | `243;155;55` (orange) | Branch name in brackets |
| Model name | `#FF6044` | `255;96;68` (red-orange italic) | Model display name |

Stats text uses `#999999` grey (same escape as overhead — `c_fixed`). No percentage shown — just `Xk/Yk $cost`.

## Separated Cost vs Context Semantics

v5.0 cleanly separates two distinct concepts:

- **Legend (Line 3)**: Always shows **tokens** — a point-in-time snapshot of what's loaded in the context window right now. After autocompaction, numbers decrease as old content is summarized.

- **Cost line (Line 4)**: Shows **dollars** — cumulative session or project spending. Uses raw (pre-scaling) tracker values for proportional attribution. Numbers only increase over time.

### Cost Attribution Math (Session Scope)

The tracker stores cumulative tokens per category. Before the scaling step (which fits tracker values to the context snapshot), we save raw values:

```
raw_results = t_agents + t_tools  (cumulative tool+agent result tokens)
raw_mcp     = t_mcp               (cumulative MCP result tokens)
overhead    = ~19,200 + memory     (fixed, known)
```

Chat tokens are estimated as the context window's residual:
```
raw_chat = max(0, tokens_used - overhead - raw_results - raw_mcp)
```

After autocompaction, this under-estimates chat (since old chat was compacted), but the proportions are still meaningful for cost distribution.

Distribution (all integer cents arithmetic, zero forks):
```
denominator = raw_results + raw_mcp + raw_chat + overhead
tools_cost  = raw_results * total_cents / denominator
mcp_cost    = raw_mcp     * total_cents / denominator
chat_cost   = raw_chat    * total_cents / denominator
sys_cost    = overhead_system  * total_cents / denominator
schema_cost = overhead_schemas * total_cents / denominator
skills_cost = overhead_skills  * total_cents / denominator
```

Rendered in the same segment colors as the legend (pink for tools, teal for mcp, green for chat, grey for overhead sub-components).

### Cost Attribution Math (Project Scope)

Sums all 4 columns across session files:
```
sum_cost, sum_results, sum_mcp, sum_overhead
```

Since `raw_chat` is not stored per-session, it's computed as the remainder:
```
denominator = sum_results + sum_mcp + sum_overhead
tools_cost  = sum_results * sum_cost / denominator
mcp_cost    = sum_mcp * sum_cost / denominator
overhead_cost = sum_overhead * sum_cost / denominator
chat_cost   = sum_cost - tools_cost - mcp_cost - overhead_cost
```

Overhead sub-components (sys, schemas, skills) use the current session's ratios as a proxy (since the ratio is roughly constant across sessions).

## Cross-Session Project Cost

### Storage

`~/.claude/project-costs/<encoded-path>/<session_id>` — one file per session.

**File format** (tab-separated, one line):
```
8.44	45000	12000	19200
```
Fields: `total_cost`, `raw_results`, `raw_mcp`, `overhead`

### Path Encoding

Match Claude Code's convention — replace `/` and `.` with `-`:
```bash
_proj_key="${cwd//\//-}"; _proj_key="${_proj_key//./-}"
```

Example: `/Users/shreyasgupta/dotfiles` → `-Users-shreyasgupta-dotfiles`

### Write

On every statusline render (zero forks — `printf` builtin), overwrite the current session's file with cost + raw tracker values. Last-writer-wins is safe since values are monotonically increasing.

### Read

Shell `for` loop over all files in the project directory, summing each column to integer cents / token totals. Zero forks. For a project with 200 sessions, ~200 iterations of builtins takes <1ms.

### Session Count

Count files in the directory to show "(N sessions)".

## Performance Notes

### statusline.sh — 3 forks (unchanged from v4.3)
- 1× `jq` for stdin JSON extraction (via here-string `<<<`, no pipe subshell)
- 1× `jq` for tracker file (reads file directly + extracts pre-formatted model_line in same call)
- 1× `git` for branch detection
- Config source (`. statusline.conf`) and model sidecar write (`printf > file`) are builtins — zero forks
- CWD display: `${cwd/#$HOME/~}` parameter expansion — zero forks
- Project cost write: `printf > file` — zero forks
- Project cost read: `for` loop + `read` + integer arithmetic — zero forks
- Path encoding: `${var//\//-}` parameter expansion — zero forks
- Cost formatting: `printf -v` builtin — zero forks

### context-tracker.sh — 2 direct forks (unchanged from v4.3)
- 1× `jq` for metadata extraction (now also extracts `subagent_model` — same call)
- 1× `lockf` for locked read-modify-write (jq now also updates `.models` — same call)
- Model sidecar read (`read -r model < file`) is a builtin — zero forks

Previously expensive patterns replaced with builtins:
- `$(cat)` → `IFS= read -r -d '' input`
- `echo "$var" | jq` → `jq ... <<< "$var"` (here-string)
- `cat file | jq` → `jq ... file` (direct file arg)
- `wc -c < file` → `$(<file)` + `${#var}` (bash builtins)
- printf loop for bar → precomputed `BLOCKS` substring
- Multiple `echo | jq` for read-modify-write → single `jq --arg`/`--argjson`
- Model sidecar: `printf '%s\n' > file` (write), `read -r var < file` (read)

### bash 3.2 compatibility
macOS `/bin/bash` is 3.2. Avoided bashisms:
- No `${var,,}` (lowercase) — use `case` patterns instead
- `$(<file)` unreliable after pipe stdin consumption — use `read -r var < file`
- `printf -v varname` works in bash 3.1+ (used for zero-fork cost formatting)

## Security: `@sh` and `--arg` Convention

**statusline.sh** — All `jq -r` eval blocks use `@sh` on every field:
```
@sh "field=\(.json_path // default)"
```
This prevents shell injection if input JSON contains metacharacters.

**context-tracker.sh** — The read-modify-write uses `jq --arg`/`--argjson`:
```
jq --arg key "$key" --argjson est "$est" --arg tool "$tool_name" --arg model "$model" '
  .[$key] = ((.[$key] // 0) + $est) | .last = $tool | .models[$model] = ...
'
```
`--arg` binds shell variables as jq string variables, eliminating all string interpolation into jq expressions. This is strictly safer than `@sh` because the values never pass through shell eval at all.

The tracker directory `/tmp/claude-context-tracker` is created with `chmod 700`, and the read-modify-write is wrapped in `lockf` for concurrency safety.

## Model Sidecar

`/tmp/claude-context-tracker/<session>.model` — single-line text file containing the normalized model key (`opus`, `sonnet`, `haiku`, or `unknown`).

- **Written by**: `statusline.sh` on each render (knows the current model from its JSON input)
- **Read by**: `context-tracker.sh` as fallback for non-Task tool calls
- **Zero forks**: `printf '%s\n' > file` (write), `read -r var < file` (read)

### Two-tier model resolution (context-tracker.sh)

1. **Task calls**: Extract `.tool_input.model` from the hook payload (same jq call, zero extra cost). Gives the actual subagent model.
2. **Regular tools**: Read parent model from sidecar file. Gives the session's active model.
3. **Normalization**: `case` pattern matching normalizes to `opus`/`sonnet`/`haiku`.

Internal subagent tool calls (Read/Grep/etc. within a subagent) get attributed to the parent model via sidecar, but their tokens are captured in the Task result — the scaling logic handles overlap.

## Calibrated Constants

From `/context` output (verified Feb 2026):

| Component | Tokens | Notes |
|-----------|--------|-------|
| System prompt | 4,200 | Core instructions, safety rules, output style |
| Custom agents | 1,700 | Agent descriptions (30 plugin + 1 user) |
| System tools | 10,100 | Built-in + MCP schemas + deferred tools loaded via ToolSearch |
| Skills | 3,200 | Skill trigger descriptions |
| Memory | measured | `$(<CLAUDE.md)` + `${#var} / 4` for each file |
| **Total overhead** | **~19,500** | Fixed, survives /clear |
| Autocompact buffer | 16.5% of context_size | 33k on 200k window |

**If plugins/MCP servers change, re-run `/context` and update `overhead_base` in statusline.sh.**

## Key Design Decisions

### Bar and Legend: unified results
Both the bar and legend merge `t_agents + t_tools` into a single pink "results" segment labeled `tools-Xk`. The legend shows an entry **only if its corresponding bar segment has visible chars** (`bar_chars[i] > 0`), preventing the inconsistency of legend items appearing without a matching bar segment.

### Legend = snapshot, Cost line = cumulative
The legend (Line 3) always shows token counts — a context window snapshot. The cost line (Line 4) shows dollar amounts using raw cumulative tracker values. This separation prevents the misleading conflation of "what's loaded now" vs "what was spent."

### Overhead floor (not cap)
After `/clear`, the API may report `used_pct=0`, but overhead (~19.5k) is always loaded. The statusline uses `max(tokens_used, overhead)` so the bar never shows 0% — it shows the true minimum (~9-10%).

### Cumulative tracker vs snapshot context
The PostToolUse hook counts every tool result ever seen (cumulative). But the context is a point-in-time snapshot — after autocompaction, old results are summarized/removed. When `tracked > msg_budget`, the statusline:
1. Reserves 15% of msg_budget as a floor for Chat
2. Scales results/mcp proportionally into the remaining 85%
3. Uses tracker **ratios** (not absolutes) for the breakdown

### Uniform glyphs
All segments use `█` (full block). Previous versions used `▓░▒` for different density levels. The uniform glyph creates a cleaner look — color alone distinguishes segments.

### Truecolor everywhere
All colors use `\033[38;2;R;G;Bm` truecolor escapes. No ANSI 16-color codes (which vary across terminal themes). Ensures consistent appearance in Ghostty and other truecolor terminals.

### Legend line with bar-gated entries
Line 3 shows legend items gated on bar visibility. Message segments (`tools`, `mcp`, `chat`) appear **only if their bar segment has chars** (`bar_chars[i] > 0`). System segments (`system`, `schemas`, `skills`) are always shown since overhead always has at least 1 bar char.

Legend labels (always tokens):

| Label | Source variable | Bar index | Color | Condition |
|-------|----------------|-----------|-------|-----------|
| `tools-Xk` | `t_results` (agents+tools merged) | 0 | pink `#FC66B1` | `bar_chars[0] > 0` |
| `mcp-Xk` | `t_mcp` | 1 | teal `#37F3BA` | `bar_chars[1] > 0` |
| `chat-Xk` | `t_chat` | 2 | green `#CAFF44` | `bar_chars[2] > 0` |
| `system-Xk` | `overhead_system` | — | grey `#999999` | always |
| `schemas-Xk` | `overhead_schemas` | — | grey `#999999` | always |
| `skills-Xk` | `overhead_skills` | — | grey `#999999` | always |

Cost bar segments (when show_cost=1, 30-char bar using ▄/▖ glyphs):

| Segment | Source | Color | Glyph |
|---------|--------|-------|-------|
| tools | `_rc` (tools cents) | pink `#FC66B1` | body=▄, end=▖ |
| mcp | `_mc` (mcp cents) | teal `#37F3BA` | body=▄, end=▖ |
| chat | `_cc` (chat cents) | green `#CAFF44` | body=▄, end=▖ |
| overhead | `_oc` (overhead cents) | grey `#999999` | body=▄, end=▖ |

Cost text format (no labels — color is the legend, bar above provides visual mapping):

```
$total - $tools $mcp $chat ($sys, $schemas, $skills)
│grey │ │pink  │teal│green│ │grey overhead breakdown   │
```

- Total first (was `= $X.XX` at end), session count uses "sesh" abbreviation
- Hyphen separator `-` between total and breakdown
- Overhead sub-components as bare dollar amounts in grey parens
- Zero-cost items omitted from both bar and text

`overhead_system = 4200 + overhead_memory`, `overhead_schemas = 1700 + 10100 = 11800`, `overhead_skills = 3200`.

## Tracker Data Format

`/tmp/claude-context-tracker/<session_id>.json`:
```json
{
  "agents": 14000, "tools": 90000, "mcp": 4000, "calls": 52, "last": "Read",
  "models": {
    "opus": {"tokens": 84000, "calls": 47},
    "sonnet": {"tokens": 8000, "calls": 12},
    "haiku": {"tokens": 1000, "calls": 3}
  }
}
```

- `agents` — cumulative estimated tokens from `Task` (subagent) results
- `tools` — from built-in tools: Read, Grep, Glob, Bash, Edit, Write, ToolSearch, etc.
- `mcp` — from `mcp__*` tools (Figma, Supabase, Slack, Chrome, etc.)
- `calls` — total tool invocation count
- `models` — per-model breakdown: `{model_key: {tokens, calls}}`
- Estimation: `(payload_chars - 300) / 4` per call

## Project Cost Data Format

`~/.claude/project-costs/<encoded-path>/<session_id>`:
```
8.44	45000	12000	19200
```

Tab-separated fields:
- `total_cost` — session total cost in USD (e.g. `8.44`)
- `raw_results` — cumulative tool+agent result tokens (pre-scaling)
- `raw_mcp` — cumulative MCP result tokens (pre-scaling)
- `overhead` — fixed overhead tokens for this session

Path encoding: `/Users/shreyasgupta/dotfiles` → `-Users-shreyasgupta-dotfiles`

## Config File

`~/.claude/statusline.conf`:
```bash
show_model=0     # 1 to show per-model breakdown on Line 5
show_cost=0      # 1 to show cost breakdown on Line 4
show_cwd=1       # 1 to show working directory on Line 1
cost_scope=session  # session or project
```

- Sourced by `statusline.sh` on each render (builtin `source`, zero forks)
- Toggled by standalone skills: `/sl-toggle-cwd`, `/sl-toggle-cost-session`, `/sl-toggle-cost-project`, `/models`
- `/sl` is read-only status display (no args)
- Created by `install.sh` with defaults

## Bar Char Distribution Algorithm

1. Each segment gets `segment_tokens * 36 / context_size` chars
2. Minimum 1 char enforced for: overhead (index 3), free (index 4), buffer (index 5)
3. Message sub-segments (results/mcp/chat) can be 0 to avoid over-representing tiny values
4. Adjustment: if total != 36, free absorbs the difference first, then buffer, then overhead (min 1 char)
5. Buffer always at right end, free adjacent to it

## Segment Order

```
seg_vals=($t_results $t_mcp $t_chat $overhead $free $buffer)
```
Indices: results=0, mcp=1, chat=2, overhead=3, free=4, buffer=5

## Testing

Pipe JSON to the script:
```bash
TEST_JSON='{"model":{"display_name":"Claude 4.6 Opus"},"workspace":{"current_dir":"/Users/shreyasgupta/dotfiles"},"session_id":"test","context_window":{"context_window_size":200000,"used_percentage":36},"cost":{"total_cost_usd":8.44}}'

# Test CWD display (default config)
printf 'show_model=0\nshow_cost=0\nshow_cwd=1\ncost_scope=session\n' > ~/.claude/statusline.conf
echo "$TEST_JSON" | ~/.claude/statusline.sh
# Expect: line 1 = ~/dotfiles (blue), line 2 = bar, line 3 = legend (tokens only)

# Test session cost breakdown
printf 'show_model=0\nshow_cost=1\nshow_cwd=1\ncost_scope=session\n' > ~/.claude/statusline.conf
echo "$TEST_JSON" | ~/.claude/statusline.sh
# Expect: line 4 = tools-$X mcp-$X chat-$X (sys-$X, schemas-$X, skills-$X)  =  $8.44

# Test project cost breakdown
printf 'show_model=0\nshow_cost=1\nshow_cwd=1\ncost_scope=project\n' > ~/.claude/statusline.conf
echo "$TEST_JSON" | ~/.claude/statusline.sh
# Expect: line 4 = project aggregate + = $Y.YY (N sessions)
```

## Settings Integration

In `~/.claude/settings.json`:
```json
{
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" },
  "hooks": {
    "PostToolUse": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/context-tracker.sh", "timeout": 5 }] }]
  }
}
```
