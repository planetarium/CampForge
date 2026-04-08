---
name: gws-drive
description: >
  Google Drive operations via gws (Google Workspace CLI). Use when asked to
  upload, download, list, search, share, or manage files in Google Drive.
  Triggers on requests like "upload to Drive", "list Drive files",
  "share file with team", "create a folder", "move file to folder".
license: Apache-2.0
metadata:
  author: swen
  version: "0.1"
compatibility: Requires @campforge/gws-auth skill package (^0.1.0). Drive-wide operations require `drive` or `drive.readonly` scope via gws-auth login.
---

# Google Drive Skill (gws CLI)

Authentication, installation, and token setup are handled by the **gws-auth** skill. Before proceeding, load/activate the `@campforge/gws-auth` skill dependency. If not already authenticated, the **user** must run `gws-auth login --scope drive --scope spreadsheets --scope drive.file` themselves — the agent cannot perform this interactive browser OAuth step.

## How to call

### File operations

```bash
# List files
gws drive files list --params '{"pageSize": 20, "fields": "files(id,name,mimeType,modifiedTime,webViewLink)"}'

# Search files by name
gws drive files list --params '{"q": "name contains \"report\"", "pageSize": 10, "fields": "files(id,name,mimeType,modifiedTime)"}'

# Search files in a specific folder
gws drive files list --params '{"q": "\"<FOLDER_ID>\" in parents", "pageSize": 20, "fields": "files(id,name,mimeType)"}'

# Get file metadata
gws drive files get --params '{"fileId": "<FILE_ID>", "fields": "id,name,mimeType,size,modifiedTime,webViewLink,parents"}'

# Upload file (simple)
gws drive files create --upload <LOCAL_FILE_PATH> --json '{"name": "<FILE_NAME>", "parents": ["<FOLDER_ID>"]}'

# Upload file with specific MIME type
gws drive files create --upload <LOCAL_FILE_PATH> --json '{"name": "<FILE_NAME>", "mimeType": "text/csv", "parents": ["<FOLDER_ID>"]}'

# Update file content (overwrite existing)
gws drive files update --params '{"fileId": "<FILE_ID>"}' --upload <LOCAL_FILE_PATH>

# Download file
gws drive files get --params '{"fileId": "<FILE_ID>", "alt": "media"}' --output <LOCAL_FILE_PATH>

# Export Google Docs/Sheets as different format
gws drive files export --params '{"fileId": "<FILE_ID>", "mimeType": "application/pdf"}' --output <LOCAL_FILE_PATH>

# Delete file (trash)
gws drive files update --params '{"fileId": "<FILE_ID>"}' --json '{"trashed": true}'

# Copy file
gws drive files copy --params '{"fileId": "<FILE_ID>"}' --json '{"name": "<NEW_NAME>", "parents": ["<FOLDER_ID>"]}'
```

### Folder operations

```bash
# Create folder
gws drive files create --json '{"name": "<FOLDER_NAME>", "mimeType": "application/vnd.google-apps.folder", "parents": ["<PARENT_FOLDER_ID>"]}'

# Move file to folder (remove old parent, add new)
gws drive files update --params '{"fileId": "<FILE_ID>", "addParents": "<NEW_FOLDER_ID>", "removeParents": "<OLD_FOLDER_ID>"}'
```

### Permissions (sharing)

```bash
# Share with user
gws drive permissions create \
  --params '{"fileId": "<FILE_ID>"}' \
  --json '{"role": "writer", "type": "user", "emailAddress": "user@example.com"}'

# Share with anyone (link sharing)
gws drive permissions create \
  --params '{"fileId": "<FILE_ID>"}' \
  --json '{"role": "reader", "type": "anyone"}'

# List permissions
gws drive permissions list --params '{"fileId": "<FILE_ID>"}'

# Remove permission
gws drive permissions delete --params '{"fileId": "<FILE_ID>", "permissionId": "<PERMISSION_ID>"}'
```

## Discover commands

```bash
# List all drive subcommands
gws drive --help

# Inspect method signature
gws schema drive.files.create
gws schema drive.files.list

# Dry-run (preview request without executing)
gws drive files list --params '{"pageSize": 5}' --dry-run
```

## Common Workflows

### Upload local file to Drive folder

1. Find or create target folder
2. `gws drive files create --upload <PATH> --json '{"name": "...", "parents": ["<FOLDER_ID>"]}'`
3. Optionally share: `gws drive permissions create ...`

### Export data and upload

1. Generate local CSV/data file with a descriptive filename (e.g. `expense-report-2026-04.csv`)
2. Load gws env: `source ~/.bashrc`
3. Upload with explicit name:
   ```bash
   gws drive files create --upload expense-report-2026-04.csv \
     --json '{"name": "expense-report-2026-04.csv"}'
   ```
4. Return the `webViewLink` from the response

**Important**: Always specify `"name"` in `--json`. Without it, files are uploaded as "Untitled". Use CSV for tabular data, not markdown.

### Search and download

1. `gws drive files list --params '{"q": "name contains \"keyword\""}'` -> find file
2. `gws drive files get --params '{"fileId": "<ID>", "alt": "media"}' --output <PATH>` -> download

## Notes

- `--upload` flag is used for file upload (simple upload mode)
- `--output` flag saves response body to a local file (for download/export)
- `--dry-run` flag previews the HTTP request without executing
- `--page-all` flag auto-paginates large result sets (NDJSON output)
- Folder MIME type: `application/vnd.google-apps.folder`
- File ID is the long string in the URL: `drive.google.com/file/d/<FILE_ID>/view`
- `drive.file` scope only accesses files created/opened by the app; use `drive` scope for full access
- **Windows**: `--params` / `--json` examples are bash syntax. On Windows, use Git Bash — PowerShell mangles JSON quotes passed to native executables
