---
name: safari-tabs
description: Open iPhone Safari tabs in Dia browser on Mac. Use when the user wants to open their iPhone Safari tabs, sync Safari tabs to desktop, view recent mobile tabs, or open mobile browsing history. Triggers on "safari tabs", "iphone tabs", "phone tabs", "open my tabs".
---

# Safari Tabs

Run `~/bin/iphone-tabs` with the appropriate argument and print its output.

## Usage

```bash
~/bin/iphone-tabs          # today's tabs (last 24h)
~/bin/iphone-tabs 7        # last 7 days
~/bin/iphone-tabs all      # every tab on iPhone
~/bin/iphone-tabs --list-only    # list without opening
~/bin/iphone-tabs 3 --list-only  # list last 3 days, no open
```

Default (no args from user) = today's tabs. If user says "all", pass `all`.

## Critical: Sandbox and Dia

The CLI sandbox blocks launching GUI apps via `open -a`. The script will fail with `procNotFound` or `kLSUnknownErr` errors unless the Bash call uses `dangerouslyDisableSandbox: true`.

**Always run this script with sandbox disabled.**

## After Running

Display the script's output directly — it prints a numbered list with titles and timestamps. If the user didn't pass `--list-only`, tabs are already opening in Dia.
