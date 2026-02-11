#!/usr/bin/env bash
# SSH wrapper for dotfiles-autocommit — ensures 1Password agent is used
# with the fully-expanded path (avoids ~ expansion issues in launchd)
OP_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
exec ssh -o "IdentityAgent \"$OP_SOCK\"" "$@"
