# CampForge

## 핵심 설계 원칙

### Camp = 조합이지 구현이 아니다

캠프는 스킬 코드를 직접 포함하지 않는다. identity(누구인가) + knowledge(무엇을 아는가) + 어떤 스킬을 조합할지 선언만 한다. 모든 스킬은 `packages/`에 독립 패키지로 존재하고, 캠프의 `package.json`이 의존성으로 선언한다.

이렇게 한 이유: 스킬 간 의존성(예: v8-admin → gql-ops)이 존재하고, 같은 스킬을 여러 캠프에서 공유할 수 있어야 한다. 스킬이 캠프 안에 박혀 있으면 의존성 관리와 재조합이 불가능하다.

### skillpm이 유일한 스킬 설치 경로

스킬 설치는 항상 [skillpm](https://skillpm.dev/)을 통한다. adapter install.sh에서 파일을 직접 복사하거나 경로를 하드코딩하지 않는다. skillpm이 npm의 의존성 해결 위에서 동작하므로 스킬 간 의존성도 자동으로 따라온다.

### npm workspaces로 로컬 개발, GitHub Release tarball로 배포

- **로컬**: 루트 `package.json`의 workspaces가 `packages/*`와 `camps/*`를 링크한다. `npm install` 한 번이면 모든 패키지가 연결된다.
- **배포**: `scripts/release-pack.sh`로 패키지별 tarball을 만들고 GitHub Release에 첨부한다. npm 레지스트리에 퍼블리시하지 않는다.
- **원격 설치**: `install-remote.sh`가 tarball URL로 `package.json`을 구성한 뒤 `npx skillpm install`을 실행한다.

npm public publish를 안 하는 이유: 일부 스킬(v8-admin, 9c-backoffice, iap-*)에 내부 URL과 조직 전용 로직이 포함되어 있다. 전부 동일한 방식(tarball)으로 관리해야 "이건 npm, 저건 아니고" 같은 분기가 생기지 않는다.

### adapter는 캠프별 맥락만 처리

adapter install.sh의 역할은 세 가지뿐이다:
1. `npx skillpm install`을 리포 루트에서 실행 (스킬 resolve)
2. 캠프의 `package.json`에 선언된 의존성만 타겟에 복사 (grep 필터)
3. identity/knowledge를 플랫폼에 맞게 배치

스킬 목록을 adapter에 하드코딩하지 않는다. `package.json`이 single source of truth다.

## 작업 시 주의사항

- 스킬을 추가하려면 `packages/`에 새 패키지를 만들고, 캠프의 `package.json`에 의존성을 추가한다. 캠프 안에 `skills/` 디렉토리를 만들지 않는다.
- adapter install.sh를 수정할 때 스킬 이름을 직접 쓰지 않는다. `node_modules/@campforge/*/skills/*/` 글로브와 `package.json` grep으로 동적 해결한다.
- `install-remote.sh`의 tarball URL에는 버전이 포함된다. 패키지 버전을 올리면 install-remote.sh의 파일명도 함께 업데이트해야 한다.
- workspace에서 `skillpm install`은 반드시 리포 루트에서 실행해야 한다. 캠프 디렉토리에서 실행하면 hoisted node_modules를 못 찾는다.
