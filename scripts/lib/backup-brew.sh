#!/usr/bin/env bash
#
# backup-brew.sh — Brew discovery and Brewfile management functions
#
# Discovers untracked formulae, casks, and macOS apps, and provides
# helpers to update the Brewfile with new entries.
#
# Sourced by the backup orchestrator. Not intended for direct execution.
#
# Requires:
#   - DOTFILES_DIR to be set by the caller
#   - common.sh to be sourced first
#

# Sourced-file safety: enable strict mode so errors in library functions
# propagate correctly to the caller.
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

BREWFILE="${DOTFILES_DIR:?DOTFILES_DIR must be set}/Brewfile"

# ============================================================================
# brew_desc — Look up descriptions for formulae or casks
# ============================================================================
# Usage: brew_desc "formula" name1 name2 ...
#        brew_desc "cask" name1 name2 ...
# Outputs "name: description" lines (one per item).

brew_desc() {
    local type="$1"  # "formula" or "cask"
    shift
    local items=("$@")
    (( ${#items[@]} == 0 )) && return 0

    if [[ "$type" == "cask" ]]; then
        brew desc --cask "${items[@]}" 2>/dev/null || true
    else
        brew desc "${items[@]}" 2>/dev/null || true
    fi
}

# ============================================================================
# _append_descriptions — Enrich a list of names with descriptions
# ============================================================================
# Usage: echo "name1\nname2" | _append_descriptions "formula"
# Outputs "name — description" lines. Falls back to bare name if lookup fails.

_append_descriptions() {
    local type="$1"  # "formula" or "cask"
    local names=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && names+=("$name")
    done

    (( ${#names[@]} == 0 )) && return 0

    local count=${#names[@]}
    _scan_status "Looking up descriptions for $count packages..."

    # Build associative array of descriptions
    local -A descs
    while IFS= read -r line; do
        # Format: "name: description"
        local key="${line%%: *}"
        local val="${line#*: }"
        [[ -n "$key" ]] && descs["$key"]="$val"
    done < <(brew_desc "$type" "${names[@]}")

    # Output enriched lines
    for name in "${names[@]}"; do
        if [[ -n "${descs[$name]:-}" && "${descs[$name]}" != "" ]]; then
            echo "$name — ${descs[$name]}"
        else
            echo "$name"
        fi
    done
}

# ============================================================================
# discover_new_brews — Find formulae installed but not in Brewfile
# ============================================================================
# Echoes untracked formula names, one per line.

discover_new_brews() {
    if [[ ! -f "$BREWFILE" ]]; then
        log_warn "Brewfile not found at $BREWFILE"
        return 1
    fi

    # Get currently installed formulae
    _scan_status "Listing installed formulae..."
    local installed
    installed=$(brew leaves 2>/dev/null) || return 1

    # Extract formula names already tracked in Brewfile (brew "name" lines)
    # Handles optional flags like: brew "tldr", link: false
    _scan_status "Comparing against Brewfile..."
    local tracked
    tracked=$(grep -E '^brew "' "$BREWFILE" | sed -E 's/^brew "([^"]+)".*/\1/' | sort)

    # Diff: installed but not tracked, then enrich with descriptions
    comm -23 <(echo "$installed" | sort) <(echo "$tracked") | _append_descriptions "formula"
    _scan_done
}

# ============================================================================
# discover_new_casks — Find casks installed but not in Brewfile
# ============================================================================
# Echoes untracked cask names, one per line.

discover_new_casks() {
    if [[ ! -f "$BREWFILE" ]]; then
        log_warn "Brewfile not found at $BREWFILE"
        return 1
    fi

    # Get currently installed casks
    _scan_status "Listing installed casks..."
    local installed
    installed=$(brew list --cask 2>/dev/null) || return 1

    # Extract cask names already tracked in Brewfile
    _scan_status "Comparing against Brewfile..."
    local tracked
    tracked=$(grep -E '^cask "' "$BREWFILE" | sed -E 's/^cask "([^"]+)".*/\1/' | sort)

    # Diff: installed but not tracked, then enrich with descriptions
    comm -23 <(echo "$installed" | sort) <(echo "$tracked") | _append_descriptions "cask"
    _scan_done
}

# ============================================================================
# discover_new_apps — Find /Applications apps not tracked as casks
# ============================================================================
# Scans /Applications/*.app, strips the .app suffix, searches for matching
# casks, and echoes results for apps not already in the Brewfile.

discover_new_apps() {
    if [[ ! -f "$BREWFILE" ]]; then
        log_warn "Brewfile not found at $BREWFILE"
        return 1
    fi

    # Get cask names already tracked
    local tracked_casks
    tracked_casks=$(grep -E '^cask "' "$BREWFILE" | sed -E 's/^cask "([^"]+)".*/\1/' | sort)

    # Get installed casks (these are already covered by discover_new_casks)
    local installed_casks
    installed_casks=$(brew list --cask 2>/dev/null | sort) || installed_casks=""

    # All known casks (tracked + installed)
    local known_casks
    known_casks=$(printf '%s\n' "$tracked_casks" "$installed_casks" | sort -u)

    # Scan /Applications for .app bundles
    _scan_status "Scanning /Applications..."
    local app_name cask_match
    for app_path in /Applications/*.app; do
        [[ -e "$app_path" ]] || continue
        app_name=$(basename "$app_path" .app)
        _scan_status "Checking $app_name..."

        # Skip if we already know about a cask for this app
        # (simplistic check — lowercase and hyphenate the app name)
        local normalized
        normalized=$(echo "$app_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        if echo "$known_casks" | grep -qFx "$normalized" 2>/dev/null; then
            continue
        fi

        # Try to find a matching cask
        cask_match=$(brew search --cask "$app_name" 2>/dev/null | head -1) || true
        if [[ -n "$cask_match" && "$cask_match" != "No formula or cask found"* ]]; then
            # Enrich with description
            local desc_line
            desc_line=$(brew desc --cask "$cask_match" 2>/dev/null) || desc_line=""
            local desc="${desc_line#*: }"
            if [[ -n "$desc" && "$desc" != "$desc_line" ]]; then
                echo "$cask_match — $desc"
            else
                echo "$cask_match"
            fi
        fi
    done
    _scan_done
}

# ============================================================================
# discover_new_mas — Find Mac App Store apps installed but not in Brewfile
# ============================================================================
# Echoes untracked MAS apps as "Name (id)", one per line.

discover_new_mas() {
    if [[ ! -f "$BREWFILE" ]]; then
        log_warn "Brewfile not found at $BREWFILE"
        return 1
    fi

    # Require mas CLI
    if ! command -v mas &>/dev/null; then
        return 0
    fi

    # Get installed MAS apps — format: "<id> <name> (<version>)"
    _scan_status "Listing Mac App Store apps..."
    local installed
    installed=$(mas list 2>/dev/null) || return 0
    [[ -z "$installed" ]] && return 0

    # Extract tracked MAS IDs from Brewfile
    _scan_status "Comparing against Brewfile..."
    local tracked_ids
    tracked_ids=$(grep -E '^mas ' "$BREWFILE" | grep -oE 'id: [0-9]+' | grep -oE '[0-9]+' | sort) || tracked_ids=""

    # Compare installed IDs against tracked
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local app_id app_name
        app_id=$(echo "$line" | awk '{print $1}')
        # Name is everything between the ID and the trailing " (version)"
        app_name=$(echo "$line" | sed -E 's/^[0-9]+ //' | sed -E 's/ \([^)]+\)$//')

        # Check if this ID is already tracked
        if echo "$tracked_ids" | grep -qFx "$app_id" 2>/dev/null; then
            continue
        fi

        echo "$app_name ($app_id)"
    done <<< "$installed"
    _scan_done
}

# ============================================================================
# update_brewfile — Insert items into Brewfile alphabetically
# ============================================================================
# Usage: update_brewfile "brew" "ripgrep" "bat" "fd"
#        update_brewfile "cask" "firefox" "discord"
#        update_brewfile "mas" "Things (904280696)" "Xcode (497799835)"
#
# Inserts new entries into the correct section of the Brewfile, maintaining
# alphabetical order within that section.

update_brewfile() {
    local type="${1:?update_brewfile requires type (brew, cask, or mas)}"
    shift
    local items=("$@")

    if [[ ! -f "$BREWFILE" ]]; then
        log_error "Brewfile not found at $BREWFILE"
        return 1
    fi

    if [[ "$type" != "brew" && "$type" != "cask" && "$type" != "mas" ]]; then
        log_error "Invalid type '$type' — must be 'brew', 'cask', or 'mas'"
        return 1
    fi

    if (( ${#items[@]} == 0 )); then
        return 0
    fi

    # MAS entries use a different format: mas "Name", id: <id>
    if [[ "$type" == "mas" ]]; then
        for item in "${items[@]}"; do
            # Item format: "Name (id)" — extract id from last parenthesized group
            local mas_id
            mas_id=$(echo "$item" | grep -oE '\([0-9]+\)$' | tr -d '()')
            local mas_name="${item% (${mas_id})}"

            # Skip if already present
            if grep -qE "^mas .*, id: ${mas_id}\$" "$BREWFILE"; then
                log_warn "mas \"$mas_name\" (id: $mas_id) already in Brewfile, skipping"
                continue
            fi

            local entry="mas \"${mas_name}\", id: ${mas_id}"

            # Insert alphabetically among existing mas entries
            local inserted=false
            local tmpfile
            tmpfile=$(mktemp)

            while IFS= read -r line; do
                if ! $inserted; then
                    if [[ "$line" =~ ^mas\ \"([^\"]+)\" ]]; then
                        local existing_name="${BASH_REMATCH[1]}"
                        if [[ "$existing_name" > "$mas_name" ]]; then
                            echo "$entry" >> "$tmpfile"
                            inserted=true
                        fi
                    fi
                fi
                echo "$line" >> "$tmpfile"
            done < "$BREWFILE"

            if ! $inserted; then
                local last_line_num
                last_line_num=$(grep -nE "^mas \"" "$BREWFILE" | tail -1 | cut -d: -f1)
                if [[ -n "$last_line_num" ]]; then
                    local tmpfile2
                    tmpfile2=$(mktemp)
                    local current_line=0
                    while IFS= read -r line; do
                        ((current_line++))
                        echo "$line" >> "$tmpfile2"
                        if (( current_line == last_line_num )); then
                            echo "$entry" >> "$tmpfile2"
                        fi
                    done < "$BREWFILE"
                    mv "$tmpfile2" "$tmpfile"
                else
                    echo "$entry" >> "$tmpfile"
                fi
            fi

            mv "$tmpfile" "$BREWFILE"
            log_info "Added mas \"${mas_name}\" (id: ${mas_id}) to Brewfile"
        done
        return 0
    fi

    for item in "${items[@]}"; do
        # Skip if already present
        if grep -qE "^${type} \"${item}\"" "$BREWFILE"; then
            log_warn "$type \"$item\" already in Brewfile, skipping"
            continue
        fi

        # Find the last line of this section and the correct insertion point
        # We insert alphabetically among existing entries of the same type
        local inserted=false
        local tmpfile
        tmpfile=$(mktemp)

        while IFS= read -r line; do
            # Check if this line is a same-type entry that sorts after our item
            if ! $inserted; then
                local existing_name
                if [[ "$line" =~ ^${type}\ \"([^\"]+)\" ]]; then
                    existing_name="${BASH_REMATCH[1]}"
                    if [[ "$existing_name" > "$item" ]]; then
                        echo "${type} \"${item}\"" >> "$tmpfile"
                        inserted=true
                    fi
                fi
            fi
            echo "$line" >> "$tmpfile"
        done < "$BREWFILE"

        # If not inserted yet (item sorts last), find the last line of this
        # type's section and append after it
        if ! $inserted; then
            local last_line_num
            last_line_num=$(grep -nE "^${type} \"" "$BREWFILE" | tail -1 | cut -d: -f1)
            if [[ -n "$last_line_num" ]]; then
                # Re-create tmpfile with insertion after the last matching line
                local tmpfile2
                tmpfile2=$(mktemp)
                local current_line=0
                while IFS= read -r line; do
                    ((current_line++))
                    echo "$line" >> "$tmpfile2"
                    if (( current_line == last_line_num )); then
                        echo "${type} \"${item}\"" >> "$tmpfile2"
                    fi
                done < "$BREWFILE"
                mv "$tmpfile2" "$tmpfile"
            else
                # No entries of this type exist — append to end
                echo "${type} \"${item}\"" >> "$tmpfile"
            fi
        fi

        mv "$tmpfile" "$BREWFILE"
        log_info "Added ${type} \"${item}\" to Brewfile"
    done
}

# ============================================================================
# detect_brewfile_duplicates — Find duplicate entries in the Brewfile
# ============================================================================
# Echoes duplicate lines (including their type prefix), one per line.

detect_brewfile_duplicates() {
    if [[ ! -f "$BREWFILE" ]]; then
        log_warn "Brewfile not found at $BREWFILE"
        return 1
    fi

    # Extract the canonical entry key (e.g. 'brew "git"', 'cask "firefox"')
    # ignoring trailing options like ', link: false'
    local keys
    keys=$(sed -E 's/^((tap|brew|cask|mas|vscode|go) "[^"]+").*/\1/' "$BREWFILE" | sort)

    # Find duplicates
    echo "$keys" | uniq -d
}
