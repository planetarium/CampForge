# Error Handling Decision Tree

## GraphQL Error

```
에러 발생
├── "Cannot query field X"
│   → 스키마 변경됨
│   → gq --introspect로 SDL 다운로드
│   → SDL에서 올바른 필드명 검색
│   → .gql 파일 수정 후 재시도
│
├── "Unknown type X"
│   → enum 또는 type 이름 변경됨
│   → SDL에서 올바른 타입명 검색
│   → .gql 파일 수정 후 재시도
│
├── "Could not invoke operation"
│   → 백엔드 에러
│   ├── statusCode 401/403 → 인증 에러 → 토큰 재발급 필요
│   ├── statusCode 500 → 서버 에러 → 잠시 후 재시도 또는 에스컬레이션
│   └── 기타 → message 내용 확인 → 사용자에게 보고
│
└── 네트워크 에러
    → 게이트웨이 URL 확인
    → 네트워크 연결 상태 확인
```

## Credit Grant Validation

```
크레딧 지급 요청
├── 금액 확인됨?
│   ├── No → 사용자에게 금액 확인 요청
│   └── Yes → 대상 유저 확인됨?
│       ├── No → 유저 검색 먼저 수행
│       └── Yes → 지급 실행 → 결과 보고
```

## Comment Bulk Action

```
댓글 일괄 작업 요청
├── 대상 목록 조회
├── 사용자에게 대상 목록 표시
├── 확인 받음?
│   ├── No → 중단
│   └── Yes → 일괄 작업 실행 → 결과 보고
```
