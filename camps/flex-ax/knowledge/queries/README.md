# Query files

Reusable PostGraphile GraphQL queries for the Flex HR endpoint
(`$FLEX_HR_GQL`). Each `.gql` file in this directory is a single
operation that the agent can invoke via `gq --queryFile`.

This directory ships **empty on purpose** — populate it as patterns
emerge in your workflows. Don't pre-fill it speculatively.

## When to add a query here

- A query is run more than once across sessions.
- A query is non-trivial enough that re-deriving it from introspection
  would waste tokens (multi-table joins, deep nesting, computed fields).
- A query needs documentation or examples for human review.

For one-off ad-hoc queries, write inline with `gq -q '...'` instead.

## Naming

Use kebab-case verbs that match what the operation does:

- `list-employees.gql`
- `recent-approvals.gql`
- `attendance-by-month.gql`
- `update-employee-by-id.gql`

## File template

```graphql
# Short description of what this query returns and when to use it.
# Variables: $first (Int), $employeeId (Int)
query ListAttendancesForEmployee($first: Int = 30, $employeeId: Int!) {
  allAttendances(
    first: $first
    condition: { employeeId: $employeeId }
    orderBy: CREATED_AT_DESC
  ) {
    totalCount
    nodes {
      id
      createdAt
      # ...select only fields you need
    }
  }
}
```

## Discovery

Need a field or relation? Don't guess — introspect:

```bash
gq "$FLEX_HR_GQL" -H "Authorization: Bearer $FLEX_HR_TOKEN" \
  --introspect > /tmp/flex-hr-schema.sdl
grep -A 5 'type Employee ' /tmp/flex-hr-schema.sdl
```

PostGraphile conventions (connection / condition / orderBy / camelCase /
RLS) are documented in `identity/AGENTS.md`.

## Calling

```bash
gq "$FLEX_HR_GQL" -H "Authorization: Bearer $FLEX_HR_TOKEN" \
  --queryFile "$FLEX_HR_QUERIES_DIR/list-employees.gql" \
  -j '{"first": 20}' -l
```
