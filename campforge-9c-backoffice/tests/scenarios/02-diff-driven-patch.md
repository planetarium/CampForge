# Scenario: Diff-Driven Patch

## Prompt

"오딘에서 WorldSheet 체인이랑 R2 비교해서 다르면 패치해줘"

## Expected Behavior

1. `sheet-compare.gql` 실행 (Odin, WorldSheet)
2. `isEqual` 확인:
   - `true` → "이미 동일합니다" 보고, 종료
   - `false` → "차이가 있습니다. 패치를 진행할까요?" 확인 요청
3. 확인 후 풀 패치 플로우 실행
