# Scenario: Single Planet Table Patch

## Prompt

"오딘에 ./WorldSheet.csv 로 WorldSheet 패치해줘"

## Expected Behavior

1. CSV 파일 읽기
2. 테이블명 자동 추론 (WorldSheet.csv → WorldSheet)
3. 행성 매핑 (오딘 → planetId: 0x100000000000)
4. 6단계 파이프라인 실행 (validate → sign → stage → poll → upload-r2 → purge-cache)
5. 각 단계별 진행 상황 표시
6. 완료 요약 보고
