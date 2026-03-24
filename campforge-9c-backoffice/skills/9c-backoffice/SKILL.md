---
name: 9c-backoffice
description: >
  Nine Chronicles Backoffice table patch operations via GraphQL.
  Use when asked to patch game tables, validate CSV, compare sheets,
  upload to R2, purge CDN cache, or check transaction status.
  Triggers on requests like "patch WorldSheet", "validate this CSV",
  "compare sheets on odin", "upload table to R2", "purge cache".
license: Apache-2.0
metadata:
  author: swen
  version: "0.4"
compatibility: Requires gq (graphqurl) CLI and a running GraphQL gateway (oag-fly)
---

# Nine Chronicles Backoffice Skill (GraphQL)

**Before proceeding, load the `gql-ops` skill dependency.** It provides schema introspection, validation, and self-healing guidance used by this skill. The `gql-ops` skill must be installed alongside this skill.

## Environment variables

Check if set, ask user if not:

```bash
echo $BO_GQL      # GraphQL gateway URL
echo $BO_API_KEY   # API key for authentication
echo $BO_SKILL_DIR  # Absolute path to this skill directory
```

Defaults:

```bash
export BO_GQL="https://planetarium-oag.fly.dev/9c-bo/graphql"
export BO_API_KEY="<ask user for API key>"
export BO_SKILL_DIR="<absolute path to this 9c-backoffice skill directory>"
```

## Planet configurations

| Planet   | PlanetId         | Internal URL                                                 |
|----------|------------------|--------------------------------------------------------------|
| Odin     | `0x100000000000` | `http://odin-internal-rpc.nine-chronicles.com/graphql`       |
| Heimdall | `0x100000000001` | `http://heimdall-internal-rpc-1.nine-chronicles.com/graphql` |
| Thor     | `0x100000000003` | `http://thor-internal-rpc-1.nine-chronicles.com/graphql`     |

When the user says "odin" / "heimdall" / "thor", use the corresponding Internal PlanetId and URL.

## How to call

Use `gq` with `$BO_GQL` and `$BO_API_KEY`. For all operations, use `--queryFile` with `$BO_SKILL_DIR/queries/`. Always use `-l` for compact output.

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" --queryFile "$BO_SKILL_DIR/queries/<name>.gql" -j '<variables>' -l
```

## Input Examples

Users will typically provide one of these forms. Claude must resolve the missing pieces before executing.

### File-based patch
> "오딘에 ./WorldSheet.csv 로 WorldSheet 패치해줘"

→ Read the file, extract CSV content, then run the full patch flow with `planetId=0x100000000000`.

### Inline CSV patch
> "하임달에 WorldSheet 패치해줘" + (CSV content pasted)

→ Use the pasted content as `csvContent`/`tableCsv`, `planetId=0x100000000001`.

### Diff-driven patch
> "오딘에서 WorldSheet 체인이랑 R2 비교해서 다르면 패치해줘"

→ Run `sheet-compare.gql` first, then patch only if `isEqual: false`.

### Multi-planet patch
> "WorldSheet 전 플래닛에 패치해줘" + (CSV file or content)

→ Run the full flow sequentially for Odin → Heimdall → Thor with the same CSV.

### Validation only
> "이 CSV WorldSheet에 맞는지 확인해줘" + (CSV content)

→ Run `table-patch-validate.gql` only, report result.

### What to ask the user if missing

| Given | Missing | Ask |
|-------|---------|-----|
| Planet + table name | CSV content | "패치할 CSV 파일 경로나 내용을 알려주세요" |
| CSV file + planet | Table name | "어떤 테이블에 패치할까요?" (or infer from file name) |
| Table name + CSV | Planet | "어떤 플래닛에 패치할까요? (odin / heimdall / thor)" |

**Table name inference**: if the CSV file name matches a known sheet name (e.g. `WorldSheet.csv` → `WorldSheet`), use it automatically without asking.

## Table Patch Workflow

The standard table patch flow is: **validate → sign → stage → poll tx-result → upload-r2 → purge-cache**

### Step 1: Validate CSV

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  --queryFile "$BO_SKILL_DIR/queries/table-patch-validate.gql" \
  -j '{"tableName":"WorldSheet","csvContent":"id,name\n1,World1"}' -l
```

### Step 2: Sign transaction

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  --queryFile "$BO_SKILL_DIR/queries/table-patch-sign.gql" \
  -j '{"planetId":"0x100000000000","url":"http://odin-internal-rpc.nine-chronicles.com/graphql","tableName":"WorldSheet","tableCsv":"id,name\n1,World1"}' -l
```

The `gq` output JSON has the following structure:
```json
{ "data": { "postApiTablePatchSign": { "success": true, "data": { "txId": "...", "payload": "..." } } } }
```
- `data.postApiTablePatchSign.data.payload` (hex-serialized transaction) → use in step 3 (stage)
- `data.postApiTablePatchSign.data.txId` (transaction hash) → use in step 4 (poll tx-result)

### Step 3: Stage transaction

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  --queryFile "$BO_SKILL_DIR/queries/table-patch-stage.gql" \
  -j '{"planetId":"0x100000000000","url":"http://odin-internal-rpc.nine-chronicles.com/graphql","payload":"<payload from sign>","tableName":"WorldSheet","tableCsv":"id,name\n1,World1"}' -l
```

### Step 4: Poll transaction result

Retry until `txStatus` is `SUCCESS` or `FAILURE`, wait 5 seconds between retries.

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  --queryFile "$BO_SKILL_DIR/queries/table-patch-tx-result.gql" \
  -j '{"planetId":"0x100000000000","url":"http://odin-internal-rpc.nine-chronicles.com/graphql","txId":"<txId>"}' -l
```

### Step 5: Upload to R2

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  --queryFile "$BO_SKILL_DIR/queries/table-patch-upload-r2.gql" \
  -j '{"planetId":"0x100000000000","url":"http://odin-internal-rpc.nine-chronicles.com/graphql","tableName":"WorldSheet","tableCsv":"id,name\n1,World1"}' -l
```

### Step 6: Purge CDN cache

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  --queryFile "$BO_SKILL_DIR/queries/table-patch-purge-cache.gql" \
  -j '{"planetId":"0x100000000000","url":"http://odin-internal-rpc.nine-chronicles.com/graphql","tableName":"WorldSheet"}' -l
```

## Sheet Compare

### List available sheets

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  --queryFile "$BO_SKILL_DIR/queries/sheet-list.gql" -l
```

### Compare chain vs R2 sheets

```bash
gq $BO_GQL -H "X-API-Key: $BO_API_KEY" \
  --queryFile "$BO_SKILL_DIR/queries/sheet-compare.gql" \
  -j '{"planetId":"0x100000000000","url":"http://odin-internal-rpc.nine-chronicles.com/graphql","tableNames":["WorldSheet","StageSheet"]}' -l
```

## Queries (--queryFile reference)

| File | Operation | Variables |
|------|-----------|-----------|
| `table-patch-validate.gql` | Validate CSV | `tableName`, `csvContent` |
| `table-patch-sign.gql` | Sign tx | `planetId`, `url`, `tableName`, `tableCsv` |
| `table-patch-stage.gql` | Stage tx | `planetId`, `url`, `payload`, `tableName`, `tableCsv` |
| `table-patch-tx-result.gql` | Poll tx result | `planetId`, `url`, `txId` |
| `table-patch-upload-r2.gql` | Upload to R2 | `planetId`, `url`, `tableName`, `tableCsv` |
| `table-patch-purge-cache.gql` | Purge CDN cache | `planetId`, `url`, `tableName` |
| `sheet-list.gql` | List sheets | (none) |
| `sheet-compare.gql` | Compare sheets | `planetId`, `url`, `tableNames` |
| `check-deleted-addresses.gql` | Check deleted addresses | `planetId`, `accountAddress`, `targetAddresses` |

## Common Workflows

### Patch a table on Odin (full flow)

1. Read the CSV file content
2. Validate: `table-patch-validate.gql`
3. If valid, Sign: `table-patch-sign.gql` → get `txId` + `payload`
4. Stage: `table-patch-stage.gql`
5. Poll `table-patch-tx-result.gql` every 5 seconds until `txStatus` is `SUCCESS`
6. Upload to R2: `table-patch-upload-r2.gql`
7. Purge cache: `table-patch-purge-cache.gql`

### Patch a table on multiple planets

Run the full flow for each planet sequentially: Odin → Heimdall → Thor.
Reuse the same CSV content but change `planetId` and `url` for each.

### Compare and patch (diff-driven)

1. List sheets: `sheet-list.gql`
2. Compare: `sheet-compare.gql` to find differences
3. For each table with `isEqual: false`, run the patch flow

## Creating new queries

See the `gql-ops` skill's "Creating new queries" section for guidance on introspecting
the schema and writing new `.gql` files.

## Notes

- All responses include `{"success": bool, "message": string?}`. Some also include `data: any?` (e.g. sign returns `txId`+`payload`)
- Exception: `check-deleted-addresses.gql` returns `results: any?` instead of `data`
- For chain-targeting operations (table patch, sheet compare, arena, etc.), `planetId` and `url` are always required together
- Exception: `check-deleted-addresses.gql` requires `planetId` and `accountAddress` but not `url`
- CSV content should be passed as a string with `\n` for newlines
- Transaction polling: wait 5 seconds between retries, timeout after 2 minutes
- Always validate before signing to catch CSV format errors early
- `--queryFile` paths use `$BO_SKILL_DIR` to resolve absolute paths to query files
- Always use `-l` flag for compact output to minimize tokens
