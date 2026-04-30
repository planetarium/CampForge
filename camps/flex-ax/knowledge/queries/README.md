# Query patterns

Reusable SQL snippets and schema notes for the local `flex-ax query`
workflow. This camp does not call a remote GraphQL endpoint. All data
access goes through `flex-ax query "SQL"` against the imported local DB.

Populate this directory only when a query pattern keeps recurring across
sessions. Do not add speculative templates.

## When to add a snippet here

- A SQL pattern is used repeatedly across sessions.
- The join path is non-trivial enough that re-deriving it wastes time.
- The query needs human review or explanation before reuse.

For one-off ad-hoc queries, write SQL inline with `flex-ax query`.

## Suggested naming

Use kebab-case names that match the intent:

- `list-employees.sql`
- `recent-approvals.sql`
- `attendance-by-month.sql`
- `expense-documents.sql`

## Discovery

Need to inspect schema first? Use `flex-ax query` directly:

```bash
flex-ax query "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"
flex-ax query "PRAGMA table_info(users)"
```

If multiple exports exist, narrow to one before querying:

```bash
OUTPUT_DIR="$HOME/.flex-ax-data/output/<customerIdHash>" \
  flex-ax query "SELECT COUNT(*) AS users FROM users"
```
