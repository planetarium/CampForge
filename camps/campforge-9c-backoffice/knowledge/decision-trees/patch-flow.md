# Table Patch Decision Tree

## Input Resolution

```
사용자 요청 수신
├── 행성 지정됨?
│   ├── No → "어떤 플래닛에 패치할까요? (odin / heimdall / thor)"
│   └── Yes → 행성 이름 → planetId + url 매핑
│
├── 테이블명 지정됨?
│   ├── No → 파일명에서 추론 가능?
│   │   ├── Yes → 자동 매핑 (WorldSheet.csv → WorldSheet)
│   │   └── No → "어떤 테이블에 패치할까요?"
│   └── Yes → 그대로 사용
│
└── CSV 있음?
    ├── 파일 경로 → 파일 읽기
    ├── 인라인 텍스트 → 그대로 사용
    └── 없음 → "패치할 CSV 파일 경로나 내용을 알려주세요"
```

## Patch Flow

```
1. Validate
   ├── isValid: true → 다음 단계
   └── isValid: false → 에러 표시, 중단
        └── errors 내용을 사용자에게 보여주기

2. Sign
   ├── success: true → txId, payload 보존
   └── success: false → 에러 보고, 중단

3. Stage
   ├── success: true → polling 시작
   └── success: false → 에러 보고, 중단

4. Poll TX Result (5초 간격, 2분 타임아웃)
   ├── txStatus: SUCCESS → 다음 단계
   ├── txStatus: FAILURE → exceptionNames 확인, 보고, 중단
   └── 타임아웃 → txId 알려주고 수동 확인 안내

5. Upload R2
   ├── success: true → 다음 단계
   └── success: false → 에러 보고 (패치 자체는 성공)

6. Purge Cache
   ├── success: true → 완료!
   └── success: false → 에러 보고 (수동 퍼지 안내)
```

## Diff-Driven Patch

```
sheet-compare 실행
├── isEqual: true → "이미 동일합니다" → 종료
└── isEqual: false → 패치 진행 여부 확인 → 풀 패치 플로우
```

## Multi-Planet Patch

```
전 플래닛 패치 요청
├── Odin 패치 → 결과 기록
├── Heimdall 패치 → 결과 기록
├── Thor 패치 → 결과 기록
└── 전체 결과 요약 테이블 출력
```
