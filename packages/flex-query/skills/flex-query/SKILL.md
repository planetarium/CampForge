---
name: flex-query
description: >
  flex-ax CLI를 통해 SQL 쿼리를 실행하여 결재/근태/사용자 데이터를 조회한다.
  Triggers: "결재 현황", "휴가 조회", "사용자 검색", "데이터 조회"
license: Apache-2.0
metadata:
  author: campforge
  version: "0.1"
---

# flex-query

## When to Use

사용자가 flex HR 데이터를 조회하려 할 때. 결재 문서, 근태/휴가, 사용자 정보 등.

## Important

- **반드시 `flex-ax query 'SQL'` 명령만 사용하여 데이터를 조회한다.**
- sqlite3, DB 파일 직접 접근, .db 파일 읽기 등은 절대 하지 않는다.
- flex-ax CLI가 유일한 데이터 접근 수단이다.
- 여러 법인 export가 있으면 먼저 `OUTPUT_DIR` 를 특정 export 디렉터리로 지정해야 한다.

## How to call

```bash
# 쿼리 실행 — 결과는 JSON 배열로 출력
flex-ax query 'SELECT * FROM users LIMIT 5'

# 여러 export가 있을 때는 특정 export 디렉터리 지정
OUTPUT_DIR="$HOME/.flex-ax-data/output/<customerIdHash>" \
  flex-ax query 'SELECT * FROM users LIMIT 5'

# 스키마 확인이 필요할 때
flex-ax query "SELECT name FROM sqlite_master WHERE type='table'"
flex-ax query "PRAGMA table_info(users)"
```

## Workflow

1. 스키마를 모르면 `flex-ax query`로 테이블 목록/컬럼 확인부터
2. 여러 export가 있으면 `OUTPUT_DIR` 를 먼저 특정 법인 디렉터리로 좁힘
3. 사용자 요청을 분석하여 적절한 SQL 작성
4. `flex-ax query 'SQL'` 실행 (read-only)
5. 결과 JSON을 파싱하여 사용자에게 알기 쉽게 요약

### 자주 쓰는 쿼리 패턴

```bash
# 사용자 검색
flex-ax query "SELECT * FROM users WHERE name LIKE '%이름%'"

# 특정 사용자의 결재 문서
flex-ax query "SELECT i.document_number, t.name as template, i.status, i.drafted_at
FROM instances i
JOIN templates t ON i.template_id = t.id
JOIN users u ON i.drafter_id = u.id
WHERE u.name LIKE '%이름%'
ORDER BY i.drafted_at DESC"

# 근태/휴가 현황
flex-ax query "SELECT u.name, a.type, a.date_from, a.date_to, a.days, a.status
FROM attendance a
JOIN users u ON a.user_id = u.id
WHERE a.date_from >= '2026-01-01'
ORDER BY a.date_from"

# 결재 대기 문서 (특정 결재자)
flex-ax query "SELECT i.document_number, t.name as template, u.name as drafter
FROM approval_lines al
JOIN instances i ON al.instance_id = i.id
JOIN templates t ON i.template_id = t.id
JOIN users u ON i.drafter_id = u.id
WHERE al.approver_id = (SELECT id FROM users WHERE name LIKE '%이름%')
  AND al.status = 'PENDING'"

# 필드값 검색 (EAV 구조)
flex-ax query "SELECT * FROM field_values WHERE field_name = '출장유형' AND value_text LIKE '%국내출장%'"
```

## Output Format

- 사용자에게 직접 보여줄 때: 테이블 형태로 정리
- 건수가 많으면 요약 + 상위 N건 표시
- 집계 요청이면 합계/평균/건수 등 통계 포함
- **외부 서비스(Drive/Sheets)로 내보낼 때: CSV 파일로 저장한 뒤 업로드**

### CSV 내보내기 예시

```bash
# JSON 결과를 CSV로 변환하여 저장
flex-ax query "SELECT u.name, i.document_number, t.name as template, fv.value_number as amount, fv.currency
FROM instances i
JOIN users u ON i.drafter_id = u.id
JOIN templates t ON i.template_id = t.id
LEFT JOIN field_values fv ON fv.instance_id = i.id AND fv.field_name LIKE '%금액%'
WHERE t.category = '비용 지급 요청'
ORDER BY i.drafted_at DESC" > /tmp/result.json

# JSON → CSV 변환 (python or jq)
python3 -c "
import json, csv, sys
data = json.load(sys.stdin)
if data:
    w = csv.DictWriter(sys.stdout, fieldnames=data[0].keys())
    w.writeheader()
    w.writerows(data)
" < /tmp/result.json > expense-report.csv
```

## Stop Conditions

- 쿼리 실행 완료 및 결과 전달
- DB 파일이 없으면 `flex-crawl` 안내
- SQL 오류 시 스키마 확인 후 재시도 (최대 2회)
