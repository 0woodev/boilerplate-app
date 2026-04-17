---
name: update-README-md
description: 프로젝트 소스코드 전반을 읽어서 app 레포 + 모든 서브모듈(be, fe, macro 등)의 README.md를 최신 상태로 업데이트합니다. 프로젝트명, 스택, 구조, 사용법, 배포 정보 등을 코드 기반으로 생성.
---

프로젝트 전체의 README.md를 소스코드 기반으로 최신화한다.

**대상:** 루트 레포 + 등록된 모든 서브모듈 (be/, fe/, macro/ 등)

---

## 작업 순서

### 1. 프로젝트 기본 정보 수집

아래를 읽어서 프로젝트 메타데이터를 파악한다:

- `CLAUDE.md` — 프로젝트 설명, 컨벤션, 브랜치 전략
- `PROGRESS.md` — 현재 진행 상태, 완료/진행중/미착수 항목
- `DOMAIN.md` — 도메인 설계 (있는 경우)
- `.gitmodules` — 등록된 서브모듈 목록
- `dev.env` 또는 `dev.sample.env` — PROJECT_NAME, DOMAIN 등

핵심 추출 정보:
- 프로젝트명 (PROJECT_NAME)
- 한 줄 설명
- 스택 요약 (BE/FE/인프라)
- 서브모듈 구성

### 2. 각 서브모듈별 소스코드 분석

서브모듈마다 다음을 확인:

**BE (be/):**
- `be/CLAUDE.md` — 스택, 명령어, 진행 현황
- `be/requirements.txt` — 주요 의존성
- `be/Makefile` — 사용 가능한 명령어
- `be/app/api/` — 등록된 API 엔드포인트 (ROUTE 변수)
- `be/common/models/` — 도메인 모델
- `be/terraform/` — 인프라 구성
- `be/tests/` — 테스트 현황

**FE (fe/):**
- `fe/CLAUDE.md` — 스택, 명령어
- `fe/package.json` — 주요 의존성, scripts
- `fe/src/app/routes.tsx` — 라우트 구조
- `fe/src/features/` — 구현된 기능 목록
- `fe/src/components/ui/` — UI 컴포넌트

**기타 서브모듈 (macro/ 등):**
- 해당 모듈의 README.md, CLAUDE.md, 소스 구조를 읽어서 동일하게 분석

### 3. README.md 생성/업데이트

각 레포별로 아래 구조의 README.md를 작성한다:

```markdown
# {프로젝트명}

> {한 줄 설명}

## 스택

{BE/FE/인프라/기타 모듈별 기술 스택}

## 시작하기

### 사전 준비

{필요한 도구, 계정, 환경변수 등}

### 설치 & 실행

{실제 명령어 — make setup, npm install 등}

## 프로젝트 구조

{디렉토리 트리 + 역할 설명}

## 주요 기능

{구현된 기능 목록 — API endpoints, 페이지, 자동화 등}

## 배포

{브랜치 전략, CI/CD 파이프라인, 환경 URL}

## 관련 레포

{서브모듈 또는 연관 레포 링크}
```

### 4. 각 README.md 파일에 쓰기

- 루트 README.md
- be/README.md
- fe/README.md
- 기타 서브모듈 README.md (macro/ 등)

**주의:**
- 기존 README.md가 있으면 **덮어쓰기** (코드 기반 최신화가 목적)
- CLAUDE.md, PROGRESS.md, DOMAIN.md는 건드리지 않음 (별도 용도)
- 민감 정보 (AWS Account ID, 키 등) 절대 포함 X
- API 엔드포인트 목록은 소스에서 ROUTE 변수 추출해서 자동 생성

---

## 실행 타이밍

1. **boilerplate에서 프로젝트 클론 직후** — setup.sh 완료, 프로젝트명 확정된 시점에 1회 실행
2. **주요 기능 추가/변경 후** — 주기적으로 실행해서 README 최신 유지
3. **PR 생성 전** — README 최신화 여부 확인

---

## 출력 형식

1. **변경된 파일 목록** — 어떤 README가 업데이트됐는지
2. **각 README 주요 변경 사항** — 추가/수정된 섹션
3. **검증** — 링크, 명령어가 실제로 유효한지 확인 결과
