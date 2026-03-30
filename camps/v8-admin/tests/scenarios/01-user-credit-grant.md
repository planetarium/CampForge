# Scenario: User Credit Grant

## Prompt

"swen 유저를 찾아서 $10 크레딧을 지급해줘"

## Expected Behavior

1. `users-search.gql`로 "swen" 검색
2. 검색 결과에서 대상 유저 확인
3. 금액($10) 확인 요청
4. 사용자 확인 후 grant credits mutation 실행
5. 결과 보고
