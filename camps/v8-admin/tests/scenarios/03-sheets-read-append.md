---
name: Google Sheets 읽기 및 행 추가
skill: gws-sheets
---

# Scenario: 스프레드시트에서 데이터 읽고 행 추가

## Prompt

> "Budget 시트에서 현재 데이터 확인하고, 새 항목 추가해줘"

## Expected Steps

1. Drive에서 "Budget" 스프레드시트 검색
   ```bash
   gws drive files list --params '{"q": "name contains \"Budget\" and mimeType=\"application/vnd.google-apps.spreadsheet\"", "pageSize": 5}'
   ```
2. 스프레드시트 전체 읽기
   ```bash
   gws sheets +read --spreadsheet <ID> --range Sheet1
   ```
3. 헤더 구조에 맞춰 새 행 추가
   ```bash
   gws sheets +append --spreadsheet <ID> --range "Sheet1!A1" \
     --values '[["2026-03-30", "Office Supplies", 150]]'
   ```
4. 추가 결과 확인을 위해 다시 읽기

## Success Criteria

- Drive 검색으로 올바른 spreadsheet ID 획득
- 기존 데이터가 테이블로 표시됨
- 새 행이 기존 데이터 아래에 정상 추가됨
