#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Statusline toggle — atomic read-branch-write, zero LLM reasoning
# ═══════════════════════════════════════════════════════════
# Usage: sl-toggle.sh <command>
# Commands: status, cwd, model, cost-session, cost-project

conf="$HOME/.claude/statusline.conf"

case "$1" in
  status)
    . "$conf" 2>/dev/null
    _on_off() { [ "$1" -eq 1 ] 2>/dev/null && echo "ON" || echo "OFF"; }
    _scope="$cost_scope"
    [ "$show_cost" -eq 0 ] 2>/dev/null && _scope="-"
    cat <<EOF
Statusline modes:
  CWD display: $(_on_off "$show_cwd")
  Model breakdown: $(_on_off "$show_model")
  Cost breakdown: $(_on_off "$show_cost") (scope: ${_scope})

Toggle: /sl-toggle-cwd  /sl-toggle-cost-session  /sl-toggle-cost-project  /models
EOF
    ;;
  cwd)
    if grep -q 'show_cwd=1' "$conf"; then
      sed -i '' 's/show_cwd=1/show_cwd=0/' "$conf"
      echo "**CWD display OFF**"
    else
      sed -i '' 's/show_cwd=0/show_cwd=1/' "$conf"
      echo "**CWD display ON** — working directory shown on line 1"
    fi ;;
  model)
    if grep -q 'show_model=1' "$conf"; then
      sed -i '' 's/show_model=1/show_model=0/' "$conf"
      echo "**Model breakdown OFF**"
    else
      sed -i '' 's/show_model=0/show_model=1/' "$conf"
      echo "**Model breakdown ON** — per-model token usage shown on the last line"
    fi ;;
  cost-session)
    if grep -q 'show_cost=1' "$conf" && grep -q 'cost_scope=session' "$conf"; then
      sed -i '' 's/show_cost=1/show_cost=0/' "$conf"
      echo "**Session cost OFF**"
    else
      sed -i '' 's/show_cost=0/show_cost=1/;s/cost_scope=project/cost_scope=session/' "$conf"
      echo "**Session cost ON** — per-category cost breakdown shown below context legend"
    fi ;;
  cost-project)
    if grep -q 'show_cost=1' "$conf" && grep -q 'cost_scope=project' "$conf"; then
      sed -i '' 's/show_cost=1/show_cost=0/' "$conf"
      echo "**Project cost OFF**"
    else
      sed -i '' 's/show_cost=0/show_cost=1/;s/cost_scope=session/cost_scope=project/' "$conf"
      echo "**Project cost ON** — aggregate cost across all sessions for this project"
    fi ;;
  *)
    echo "Usage: sl-toggle.sh <status|cwd|model|cost-session|cost-project>" ;;
esac
