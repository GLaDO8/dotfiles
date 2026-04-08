# CLI Tools Reference

Quick reference for modern CLI tools. Use these instead of legacy defaults when working through Bash.

---

## ast-grep (`sg`) — Structural Code Search & Replace

Use instead of regex grep/sed when searching or modifying **code patterns**. Understands syntax trees — won't match inside strings, comments, or unrelated constructs.

```bash
# Search for patterns
sg -p 'console.log($$$)' --lang ts              # find all console.logs
sg -p 'if ($A) { return $B }' --lang js          # find if-return patterns
sg -p 'useState($INIT)' --lang tsx               # find React useState calls
sg -p 'def $FN(self, $$$):' --lang python         # find Python methods

# Replace patterns
sg -p 'assert.equal($A, $B)' -r 'expect($A).toBe($B)' --lang js
sg -p 'console.log($$$)' -r '' --lang ts          # remove all console.logs
sg -p 'require($MOD)' -r 'import $MOD from $MOD' --lang js

# Interactive mode (confirm each replacement)
sg -p 'PATTERN' -r 'REPLACEMENT' --lang LANG -i

# With file filtering
sg -p 'PATTERN' --lang ts src/                    # search only in src/
```

**When to use**: Refactoring patterns across a codebase, finding function signatures, removing dead code patterns, migrating APIs.
**When NOT to use**: Simple text search (use rg), searching non-code files.

---

## difftastic (`difft`) — AST-Aware Diffs

Shows what actually changed semantically, ignoring whitespace and formatting noise.

```bash
# Compare two files
difft old.ts new.ts

# Use with git
GIT_EXTERNAL_DIFF=difft git diff
GIT_EXTERNAL_DIFF=difft git diff HEAD~1
GIT_EXTERNAL_DIFF=difft git show COMMIT_SHA
GIT_EXTERNAL_DIFF=difft git log -p --ext-diff -n5

# Side-by-side display
difft --display side-by-side old.ts new.ts

# Inline display (better for narrow terminals)
difft --display inline old.ts new.ts
```

**When to use**: Reviewing changes after refactoring, comparing before/after files, understanding what a commit really changed.

---

## sd — Modern sed

Drop-in sed replacement with sane regex syntax. No escaping madness.

```bash
# Basic replace (first match per line)
sd 'old_pattern' 'new_pattern' file.txt

# Fixed-string mode (no regex interpretation)
sd -F 'literal.string' 'replacement' file.txt

# Capture groups (just work)
sd 'v(\d+)\.(\d+)' 'v${1}.${2}.0' package.json

# Multi-file (combine with fd)
fd -e ts | xargs sd 'oldFunction' 'newFunction'

# Stdin pipe
echo "hello world" | sd 'world' 'there'
```

**When to use**: Quick text replacements in Bash. Anywhere you'd reach for `sed`.

---

## hyperfine — Benchmarking

Statistical benchmarking with warmup runs, variance analysis, and markdown export.

```bash
# Compare two commands
hyperfine 'command1' 'command2'

# With warmup (important for disk-cached operations)
hyperfine --warmup 3 'command'

# Export results as markdown
hyperfine --export-markdown bench.md 'cmd1' 'cmd2'

# Set min/max runs
hyperfine --min-runs 10 'command'

# With preparation step (runs before each benchmark)
hyperfine --prepare 'make clean' 'make build'

# Shell selection
hyperfine --shell=none './binary_to_test'
```

**When to use**: Comparing performance of two implementations, validating optimization, generating benchmark reports.

---

## scc — Code Statistics

Fast project overview — languages, lines, complexity.

```bash
# Full project overview
scc

# Per-file breakdown
scc --by-file

# Filter by language
scc -i js,ts,tsx

# Exclude directories
scc --exclude-dir node_modules,dist,.next

# Output as JSON (pipe to jq)
scc -f json | jq '.[] | {Name, Lines, Code, Comments}'

# Compare complexity
scc --sort complexity
```

**When to use**: First contact with a new codebase, understanding project scope before estimating effort.

---

## yq — YAML/TOML/XML Processing

Like jq but for YAML, TOML, XML. Preserves comments and formatting on edits.

```bash
# Read values
yq '.key.nested' file.yaml
yq '.services.web.ports' docker-compose.yml

# In-place edit (preserves comments!)
yq -i '.version = "2.0"' file.yaml
yq -i '.dependencies.react = "^19.0.0"' package.yaml

# Convert formats
yq -o json file.yaml                 # YAML → JSON
yq -o yaml file.json                 # JSON → YAML
yq -p toml file.toml                 # Read TOML

# Array operations
yq -i '.items += ["new"]' file.yaml
yq '.items | length' file.yaml

# Multiple documents
yq eval-all 'select(.kind == "Deployment")' k8s.yaml
```

**When to use**: Editing config files (docker-compose, k8s manifests, CI configs) without destroying comments/formatting. Converting between formats.

---

## bat — Syntax-Highlighted cat

```bash
# Display file with syntax highlighting
bat file.ts

# Plain style (no line numbers/headers, just highlighting)
bat --style=plain file.ts

# Specific language (when auto-detect fails)
bat --language=json data.txt

# Show only a range of lines
bat --line-range 10:20 file.ts

# As a pager for other commands
command | bat --language=json
```

---

## delta — Git Diff Pager

Word-level diff highlighting with syntax awareness. Already configured as global git pager.

```bash
# Already active for all git commands:
git diff                              # auto-uses delta
git log -p                            # auto-uses delta
git show                              # auto-uses delta

# Side-by-side mode (ad-hoc)
git diff | delta --side-by-side

# Override for raw output when needed
git --no-pager diff
```

---

## watchexec — File Watcher

Run commands automatically when files change.

```bash
# Re-run tests on change
watchexec -e ts,tsx -- npm test

# Rebuild on change
watchexec -e rs -- cargo build

# Watch specific directory
watchexec -w src/ -- make build

# Restart long-running process
watchexec -r -- node server.js

# Debounce (wait for changes to settle)
watchexec --debounce 500 -e ts -- npm test
```

**When to use**: Setting up persistent feedback loops — continuous test running, auto-rebuild, live reload.

---

## comby — Structural Search for Any File Format

Like ast-grep but works on any text format (JSON, Markdown, config files, prose).

```bash
# Search
comby 'console.log(:[args])' '' .js

# Replace
comby 'TODO: :[msg]' 'DONE: :[msg]' .md

# JSON structure matching
comby '"name": :[val]' '' .json

# Preview changes (dry run)
comby 'old' 'new' .ext -diff

# In-place
comby 'old' 'new' .ext -in-place
```

**When to use**: Structural patterns in non-code files. For actual code, prefer `sg` (ast-grep).

---

## Cheat Sheet: Which Tool When?

| Task | Legacy | Modern |
|------|--------|--------|
| Search code patterns | `rg 'regex'` | `sg -p 'pattern' --lang X` |
| Replace in files | `sed -i 's/old/new/g'` | `sd 'old' 'new' file` |
| Diff files | `diff a b` | `difft a b` |
| Git diff | `git diff` | `GIT_EXTERNAL_DIFF=difft git diff` |
| Benchmark | `time cmd` | `hyperfine 'cmd'` |
| Read YAML | manual grep | `yq '.key' file.yaml` |
| Project stats | `wc -l`, `cloc` | `scc` |
| View code | `cat file.ts` | `bat file.ts` |
| Watch & rerun | `while true; do ...` | `watchexec -e ext -- cmd` |
