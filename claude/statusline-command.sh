#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# ============================================
# Vercel Deployment Status (cached polling)
# ============================================
VERCEL_CACHE_FILE="/tmp/claude-vercel-status-cache"
VERCEL_CACHE_TTL=60  # seconds

get_vercel_status() {
    # Skip if env vars not set
    if [ -z "$VERCEL_TOKEN" ] || [ -z "$VERCEL_PROJECT_ID" ]; then
        echo ""
        return
    fi

    # Check cache
    if [ -f "$VERCEL_CACHE_FILE" ]; then
        cache_age=$(($(date +%s) - $(stat -f %m "$VERCEL_CACHE_FILE" 2>/dev/null || echo 0)))
        if [ "$cache_age" -lt "$VERCEL_CACHE_TTL" ]; then
            cat "$VERCEL_CACHE_FILE"
            return
        fi
    fi

    # Fetch fresh data
    deploy_data=$(curl -s --max-time 3 -H "Authorization: Bearer $VERCEL_TOKEN" \
        "https://api.vercel.com/v6/deployments?projectId=$VERCEL_PROJECT_ID&limit=1" 2>/dev/null)

    if [ -z "$deploy_data" ] || [ "$(echo "$deploy_data" | jq -r '.error // empty')" != "" ]; then
        echo "▲ --" > "$VERCEL_CACHE_FILE"
        cat "$VERCEL_CACHE_FILE"
        return
    fi

    # Parse deployment info
    state=$(echo "$deploy_data" | jq -r '.deployments[0].state // empty')
    url=$(echo "$deploy_data" | jq -r '.deployments[0].url // empty')
    created=$(echo "$deploy_data" | jq -r '.deployments[0].created // empty')

    # Format state with icon
    case "$state" in
        READY)     state_icon="✓"; state_text="Ready" ;;
        BUILDING)  state_icon="◐"; state_text="Building" ;;
        QUEUED)    state_icon="◷"; state_text="Queued" ;;
        ERROR)     state_icon="✗"; state_text="Error" ;;
        CANCELED)  state_icon="○"; state_text="Canceled" ;;
        *)         state_icon="?"; state_text="$state" ;;
    esac

    # Calculate time ago
    if [ -n "$created" ] && [ "$created" != "null" ]; then
        now=$(date +%s)
        created_sec=$((created / 1000))
        diff=$((now - created_sec))
        if [ "$diff" -lt 60 ]; then
            time_ago="${diff}s"
        elif [ "$diff" -lt 3600 ]; then
            time_ago="$((diff / 60))m"
        elif [ "$diff" -lt 86400 ]; then
            time_ago="$((diff / 3600))h"
        else
            time_ago="$((diff / 86400))d"
        fi
    else
        time_ago="--"
    fi

    # Store full URL for reference
    full_url="https://$url"
    echo "$full_url" > "/tmp/claude-vercel-url"

    # Build vercel status string (OSC 8 links not supported by Claude Code)
    result="▲ ${state_icon} ${state_text} (${time_ago} ago)"
    echo "$result" > "$VERCEL_CACHE_FILE"
    echo "$result"
}

vercel_status=$(get_vercel_status)

# Extract data from JSON
model_name=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
version=$(echo "$input" | jq -r '.version // "Unknown"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

# Get context window info
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
used_percentage=$(echo "$input" | jq -r '.context_window.used_percentage // 0')

# Calculate total tokens used (in thousands)
# Derive from used_percentage to stay in sync with progress bar after /clear
context_k=$((context_size / 1000))
tokens_k=$((used_percentage * context_k / 100))

# Create progress bar based on usage percentage
bar_length=10
filled=$((used_percentage * bar_length / 100))
if [ "$filled" -gt "$bar_length" ]; then
    filled=$bar_length
fi
empty=$((bar_length - filled))

progress_bar=""
for ((i=0; i<filled; i++)); do
    progress_bar+="█"
done
for ((i=0; i<empty; i++)); do
    progress_bar+="░"
done

# Get git branch with optional lock skip
git_branch=""
if [ -n "$cwd" ] && [ -d "$cwd/.git" ]; then
    branch=$(cd "$cwd" && git --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        git_branch="$branch"
    fi
else
    git_branch="UNTRACKED"
fi

# Shorten model name (e.g., "Claude 3.5 Sonnet" -> "Sonnet 3.5", "Claude Opus 4.5" -> "Opus 4.5")
short_model=$(echo "$model_name" | sed -E 's/Claude ([0-9.]+) (Opus|Sonnet|Haiku)/\2 \1/; s/Claude (Opus|Sonnet|Haiku) ([0-9.]+)/\1 \2/')

# Colors
orange="\033[38;5;208m"
grey="\033[90m"
reset="\033[0m"

# Colors for Vercel status
green="\033[32m"
yellow="\033[33m"
red="\033[31m"

# Build status line: "[BRANCH/UNTRACKED] Model ████░░░░░░ 4k/200k v2.1.6"
printf "${grey}[%s]${reset} ${orange}%s${reset} %s %dk/%dk v%s" \
    "$git_branch" \
    "$short_model" \
    "$progress_bar" \
    "$tokens_k" \
    "$context_k" \
    "$version"

# Add Vercel status on second line if available
if [ -n "$vercel_status" ]; then
    # Color based on state
    if [[ "$vercel_status" == *"Ready"* ]]; then
        vercel_color="$green"
    elif [[ "$vercel_status" == *"Building"* ]] || [[ "$vercel_status" == *"Queued"* ]]; then
        vercel_color="$yellow"
    elif [[ "$vercel_status" == *"Error"* ]]; then
        vercel_color="$red"
    else
        vercel_color="$grey"
    fi
    printf "\n${vercel_color}%s${reset}" "$vercel_status"
fi
