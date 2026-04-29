# Query files

Reusable PostGraphile GraphQL queries for the Flex HR endpoint (`$FLEX_HR_GQL`).
Each `.gql` file in this directory is a single operation that the agent can invoke via `gq --queryFile`.

## Available queries

| File | Operation | Variables |
|------|-----------|-----------|
| `get-file-download-url.gql` | Mutation: presigned R2 download URL for a file upload | `fileUploadId` |
