# Nine Chronicles Backoffice GraphQL Operations

Gateway: `https://planetarium-oag.fly.dev/9c-bo/graphql`

## Table Patch

| Operation | Type | Arguments |
|-----------|------|-----------|
| `postApiTablePatchValidate` | Mutation | `validateCsvRequestInput: ValidateCsvRequestInput` |
| `postApiTablePatchSign` | Mutation | `signRequestInput: SignRequestInput` |
| `postApiTablePatchStage` | Mutation | `stageTxRequestInput: StageTxRequestInput` |
| `postApiTablePatchTxResult` | Mutation | `transactionResultRequestInput: TransactionResultRequestInput` |
| `postApiTablePatchUploadR2` | Mutation | `uploadToR2RequestInput: UploadToR2RequestInput` |
| `postApiTablePatchPurgeCache` | Mutation | `purgeCacheRequestInput: PurgeCacheRequestInput` |

## Sheet Compare

| Operation | Type | Arguments |
|-----------|------|-----------|
| `stringListApiResponse` | Query | _(none)_ |
| `postApiSheetCompareCompare` | Mutation | `sheetBatchCompareRequestInput: SheetBatchCompareRequestInput` |

## Address State Action

| Operation | Type | Arguments |
|-----------|------|-----------|
| `postApiAddressStateActionCheckDeletedAddresses` | Mutation | `checkDeletedAddressesRequestInput: CheckDeletedAddressesRequestInput` |

## Arena

| Operation | Type | Arguments |
|-----------|------|-----------|
| `arenaSeasonListApiResponse` | Query | `planet: String` |
| `getApiArenaRewardCompletedSeasons` | Query | `planet: String` |
| `arenaLeaderboardEntryListApiResponse` | Query | `planet: String`, `seasonId: Int` |
| `stakeStateListApiResponse` | Query | `planet: String`, `seasonId: Int` |
| `couragePassEntryListApiResponse` | Query | `planet: String`, `seasonIndex: Int` |
| `postApiArenaRewardCalculate` | Mutation | `arenaRewardCalculateRequestInput: ArenaRewardCalculateRequestInput` |
| `postApiArenaSettlementBalance` | Mutation | `arenaNcgBalanceRequestInput: ArenaNcgBalanceRequestInput` |
| `postApiArenaSettlementSign` | Mutation | `arenaNcgSignRequestInput: ArenaNcgSignRequestInput` |
| `postApiArenaSettlementStage` | Mutation | `arenaNcgStageTxRequestInput: ArenaNcgStageTxRequestInput` |
| `postApiArenaSettlementTxResult` | Mutation | `arenaNcgTransactionResultRequestInput: ArenaNcgTransactionResultRequestInput` |

## Season Pass

| Operation | Type | Arguments |
|-----------|------|-----------|
| `getApiSeasonPassBalances` | Query | `environment: Environment` |
| `getApiSeasonPassPassesId` | Query | `environment: Environment`, `id: Int!` |
| `seasonPassDetailApiResponse` | Query | `environment: Environment`, `passType: PassType` |
| `seasonPassDetailListApiResponse` | Query | `environment: Environment`, `passType: PassType`, `seasonIndex: Int` |
| `paginatedSeasonResponseApiResponse` | Query | `environment: Environment`, `limit: Int`, `offset: Int`, `passType: String` |
| `paginatedPremiumUserResponseApiResponse` | Query | `environment: Environment`, `limit: Int`, `offset: Int`, `passType: String`, `planetId: String`, `seasonIndex: Int` |
| `paginatedClaimResponseApiResponse` | Query | `avatarAddr: String`, `days: Int`, `environment: Environment`, `limit: Int`, `offset: Int`, `status: String` |
| `postApiSeasonPassPasses` | Mutation | `createSeasonPassSchemaInput: CreateSeasonPassSchemaInput`, `environment: Environment` |
| `postApiSeasonPassRetryStage` | Mutation | `environment: Environment` |
| `postApiSeasonPassBurnAsset` | Mutation | `burnAssetRequestSchemaInput: BurnAssetRequestSchemaInput`, `environment: Environment` |

## IAP

| Operation | Type | Arguments |
|-----------|------|-----------|
| `paginatedProductResponseApiResponse` | Query | `environment: Environment`, `page: Int`, `pageSize: Int` |
| `receiptSearchResponseApiResponse` | Query | `agentAddr: String`, `appleOrderId: String`, `endDate: String`, `environment: Environment`, `orderId: String`, `page: Int`, `pageSize: Int`, `planetId: String`, `startDate: String`, `status: Int`, `store: Int` |
| `stringStringStringDictionaryDictionaryApiResponse` | Query | `environment: Environment` |
| `postApiIapProductsImport` | Mutation | `csvImportRequestInput: CsvImportRequestInput`, `environment: Environment` |
| `postApiIapProductCategoriesImport` | Mutation | `csvImportRequestInput: CsvImportRequestInput`, `environment: Environment` |
| `postApiIapFungibleAssetsImport` | Mutation | `csvImportRequestInput: CsvImportRequestInput`, `environment: Environment` |
| `postApiIapFungibleItemsImport` | Mutation | `csvImportRequestInput: CsvImportRequestInput`, `environment: Environment` |
| `postApiIapPricesImport` | Mutation | `csvImportRequestInput: CsvImportRequestInput`, `environment: Environment` |
| `postApiIapProductsUploadCsv` | Mutation | `csvImportRequestInput: CsvImportRequestInput`, `environment: Environment` |
| `postApiIapProductsUploadImages` | Mutation | `apiIapProductsUploadImagesInput: ApiIapProductsUploadImagesInput`, `environment: Environment` |

## Tools

| Operation | Type | Arguments |
|-----------|------|-----------|
| `versionRegistryApiResponse` | Query | _(none)_ |
| `stringApiResponse` | Query | `fileName: String!` |
| `eventBannerCollectionApiResponse` | Query | _(none)_ |
| `ncuJsonModelApiResponse` | Query | `filePath: String` |
| `getApiToolsReleaseNotice` | Query | `date: String`, `version: String` |
| `postApiToolsCloVersionRegistry` | Mutation | `versionRegistryInput: VersionRegistryInput` |
| `postApiToolsCloFilesFileName` | Mutation | `cloFileSaveRequestInput: CloFileSaveRequestInput`, `fileName: String!` |
| `postApiToolsEventBanner` | Mutation | `eventBannerCollectionInput: EventBannerCollectionInput` |
| `postApiToolsEventBannerBannerImages` | Mutation | `apiToolsEventBannerBannerImagesInput: ApiToolsEventBannerBannerImagesInput` |
| `postApiToolsEventBannerPopupImages` | Mutation | `apiToolsEventBannerPopupImagesInput: ApiToolsEventBannerPopupImagesInput` |
| `postApiToolsNcu` | Mutation | `filePath: String`, `ncuJsonModelInput: NcuJsonModelInput` |
| `postApiToolsNcuImages` | Mutation | `apiToolsNcuImagesInput: ApiToolsNcuImagesInput` |
| `deleteApiToolsNcu` | Mutation | `filePath: String` |
| `deleteApiToolsNcuImagesFileName` | Mutation | `fileName: String!` |
| `postApiToolsReleaseNotice` | Mutation | `releaseNoticeJsonRequestInput: ReleaseNoticeJsonRequestInput` |

## Input Types (commonly used)

```graphql
input ValidateCsvRequestInput {
  tableName: String!
  csvContent: String!
}

input SignRequestInput {
  planetId: String!
  url: String!
  tableName: String!
  tableCsv: String!
}

input StageTxRequestInput {
  planetId: String!
  url: String!
  payload: String!
  tableName: String!
  tableCsv: String!
}

input TransactionResultRequestInput {
  planetId: String!
  url: String!
  txId: String!
}

input UploadToR2RequestInput {
  planetId: String!
  url: String!
  tableName: String!
  tableCsv: String!
}

input PurgeCacheRequestInput {
  planetId: String!
  url: String!
  tableName: String!
}

input SheetBatchCompareRequestInput {
  planetId: String!
  url: String!
  tableNames: [String]!
}

input CheckDeletedAddressesRequestInput {
  planetId: String!
  accountAddress: String!
  targetAddresses: [String]!
}
```

## Authentication

All requests require the `X-API-Key` header:
```
X-API-Key: <BO_API_KEY value>
```
