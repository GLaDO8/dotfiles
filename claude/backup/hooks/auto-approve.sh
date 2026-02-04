#!/bin/bash
#
# Auto-approve safe permission requests for Claude Code
# Reads JSON from stdin, outputs decision to stdout
#

# Read the permission request from stdin
INPUT=$(cat)

# Extract tool name and command (if Bash)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Log for debugging (uncomment to debug)
# echo "[auto-approve] Tool: $TOOL_NAME, Command: $COMMAND, File: $FILE_PATH" >> ~/.claude/hooks/debug.log

# Define dangerous patterns to DENY
DANGEROUS_PATTERNS=(
    "rm -rf /"
    "rm -rf ~"
    "rm -rf \$HOME"
    "rm -rf \*"
    "> /dev/sd"
    "mkfs"
    "dd if="
    ":(){:|:&};:"
    "chmod -R 777 /"
    "chown -R.*/"
    "git push.*--force"
    "git push.*-f"
    "git reset --hard"
    "DROP DATABASE"
    "DROP TABLE"
    "TRUNCATE"
    "DELETE FROM.*WHERE 1"
    "sudo rm"
    "curl.*\| *bash"
    "curl.*\| *sh"
    "wget.*\| *bash"
    "wget.*\| *sh"
)

# Define sensitive file patterns to DENY writes
SENSITIVE_FILES=(
    "\.env$"
    "\.env\."
    "credentials"
    "secrets"
    "id_rsa"
    "id_ed25519"
    "\.ssh/id_"
    "\.pem$"
    "\.key$"
    "password"
    "\.aws/credentials"
    "hosts\.yml"
)

# Check for dangerous commands
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
        # Deny - output JSON with deny decision
        jq -n '{
            hookSpecificOutput: {
                hookEventName: "PermissionRequest",
                decision: {
                    behavior: "deny",
                    message: "Blocked dangerous command pattern"
                }
            }
        }'
        exit 0
    fi
done

# Check for sensitive file access (only for write operations)
if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "MultiEdit" ]]; then
    for pattern in "${SENSITIVE_FILES[@]}"; do
        if echo "$FILE_PATH" | grep -qiE "$pattern"; then
            jq -n --arg pattern "$pattern" '{
                hookSpecificOutput: {
                    hookEventName: "PermissionRequest",
                    decision: {
                        behavior: "deny",
                        message: ("Blocked write to sensitive file matching: " + $pattern)
                    }
                }
            }'
            exit 0
        fi
    done
fi

# If we get here, approve the action
jq -n '{
    hookSpecificOutput: {
        hookEventName: "PermissionRequest",
        decision: {
            behavior: "allow"
        }
    }
}'
exit 0
