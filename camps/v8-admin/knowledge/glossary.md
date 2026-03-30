# V8 Admin Glossary

## Platform Concepts

| Term | Definition |
|------|-----------|
| **V8** | Planetarium의 게이밍 플랫폼. 버스(게임 월드) 호스팅 및 크리에이터 경제 지원 |
| **Verse** | V8 플랫폼 위의 개별 게임 월드/환경 |
| **Verse shortId** | Verse의 축약 식별자 (URL 등에서 사용) |
| **VX Shop** | V8 플랫폼 내 마켓플레이스 (V8과는 별도 브랜딩) |
| **Credit** | V8 플랫폼 내 가상 화폐. USD 기반 (예: `20` = $20) |
| **Featured** | 관리자가 선정한 추천 버스. `Featured` enum의 `ONLY` 값으로 필터링 |
| **Showcase** | 메인 페이지 쇼케이스 배치 여부 |
| **Visibility** | 버스 공개 상태: `public`, `unlisted`, `private` |

## User Management

| Term | Definition |
|------|-----------|
| **userUid** | 유저 고유 ID (숫자) |
| **handle** | 유저 핸들 (@mention용) |
| **isSeller** | 크리에이터 마켓 판매자 여부 |
| **creditInUSD** | 유저 크레딧 잔액 (USD 단위) |

## Search & Filter

| Enum | Values |
|------|--------|
| **SearchType** | `USEREMAIL`, `USERDISPLAYNAME`, `VERSETITLE`, `VERSESHORTID`, `COMMENTCONTENT` |
| **Filter** | `ALL`, `ACTIVE`, `DELETED` |
| **SortBy** | 버스 정렬 기준 |

## Collections (Verse Categories)

| Index | Category |
|-------|----------|
| 0 | Multiplayer |
| 1 | Educational |
| 2 | Story-Driven |
| 3 | 3D |
| 4 | Deep Gameplay |

## Google Sheets (gws-sheets skill)

| Term | Definition |
|------|-----------|
| **gws** | Google Workspace CLI (`@googleworkspace/cli`). Google Drive, Sheets 등 Workspace API 통합 CLI |
| **Spreadsheet ID** | Google Sheets URL의 `/d/<ID>/edit` 부분에 해당하는 고유 식별자 |
| **Range** | 시트 내 셀 범위. A1 표기법 사용 (예: `Sheet1!A1:D10`, `Sheet1`) |
| **valueInputOption** | 입력 해석 방식. `USER_ENTERED` (수식 파싱) vs `RAW` (문자열 그대로) |
| **Skill shortcut** | gws의 `+read`, `+append` 등 간편 명령어. 직접 API 호출보다 간단한 구문 |

## Analytics

| Term | Definition |
|------|-----------|
| **Quality Score** | 컨텐츠 품질 점수 (자동 계산) |
| **Trending Score** | 인기 트렌드 점수 |
| **Mission Rank** | 크리에이터 달성도 랭킹 |
| **Tag Count** | 태그별 사용 횟수 집계 |
| **Game Session** | 게임 세션 통계 |
