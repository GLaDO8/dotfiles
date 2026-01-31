---
name: safari-tabs
description: Open iPhone Safari tabs in Dia browser. Use when the user wants to open their iPhone Safari tabs on Mac, sync Safari tabs, or open recent mobile tabs.
allowed-tools: Bash(~/bin/iphone-tabs*), Bash(sqlite3*), Bash(open -*)
---

# Safari Tabs Skill

Open iPhone Safari tabs in Dia browser on Mac.

## Usage

- `/safari-tabs` - Open today's tabs
- `/safari-tabs 7` - Open tabs from last 7 days
- `/safari-tabs 3` - Open tabs from last 3 days

## Instructions

When the user invokes this skill, run the script at `~/bin/iphone-tabs` with the optional days argument:

```bash
~/bin/iphone-tabs [days]
```

If the script doesn't exist or fails, implement the logic directly:

1. **Query the CloudTabs database** at the correct path for macOS version:
   - macOS 26+: `~/Library/Containers/com.apple.Safari/Data/Library/Safari/CloudTabs.db`
   - Older: `~/Library/Safari/CloudTabs.db`

2. **Find the iPhone device UUID**:
   ```sql
   SELECT device_uuid FROM cloud_tab_devices WHERE device_name LIKE '%iPhone%'
   ```

3. **Calculate cutoff timestamp**:
   - Parse the argument as number of days (default 1)
   - Apple uses seconds since Jan 1, 2001 (offset: 978307200)
   - Cutoff = `(current_unix_epoch - 978307200) - (days * 86400)`

4. **Get tabs filtered by time**:
   ```sql
   SELECT title, url, datetime(last_viewed_time + 978307200, 'unixepoch', 'localtime')
   FROM cloud_tabs
   WHERE device_uuid = '<iphone_uuid>'
   AND last_viewed_time > <cutoff>
   ORDER BY last_viewed_time DESC
   ```

5. **Display tabs** to user showing title, URL, and when last viewed

6. **Ask confirmation** before opening

7. **Open in Dia**:
   ```bash
   # First URL in new window
   open -na "Dia" --args --new-window "<first_url>"
   sleep 1
   # Remaining URLs as tabs
   open -a "Dia" "<url2>" "<url3>" ...
   ```

## Notes

- Tabs are sorted by most recently viewed first (fixes iOS ordering issue)
- The script requires Full Disk Access for the terminal
- CloudTabs.db location changed in macOS 26 to the Safari container
