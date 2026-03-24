# Scenario: Spam Comment Cleanup

## Prompt

"스팸 댓글 좀 정리해줘. spam@example.com 유저가 올린 댓글 다 삭제해"

## Expected Behavior

1. `comments-list.gql`로 해당 이메일의 댓글 조회 (searchType: USEREMAIL)
2. 대상 댓글 목록을 사용자에게 표시
3. 삭제 확인 요청
4. 확인 후 batch delete mutation 실행
5. 삭제 결과 보고
