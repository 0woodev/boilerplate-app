# CLAUDE.md — boilerplate-app

이 프로젝트는 **풀스택 개발자를 위한 boilerplate**다.
BE(Python Lambda) + FE(React/Vite) + 인프라(Terraform)를 하나의 레포에서 관리한다.

Claude Code가 이 레포를 처음 열 때 읽는 컨텍스트 파일.

---

## 레포 구조

```
boilerplate-app/        ← 이 레포 (orchestrator)
├── be/                 ← backend 서브모듈 (boilerplate-be)
├── fe/                 ← frontend 서브모듈 (boilerplate-fe)
├── scripts/
│   ├── setup.sh        ← 초기 프로젝트 생성 (1회)
│   └── teardown.sh     ← 프로젝트 삭제
├── docs/
│   └── ai-philosophy.md  ← AI 협업 철학 (멀티 에이전트 패턴)
└── CLAUDE.md           ← 이 파일
```

`be/`, `fe/`는 각자 독립 git 레포이며 git submodule로 등록되어 있다.
각 서브모듈 안에도 `.claude/` 디렉토리와 스킬이 있다.

---

## 빠른 컨텍스트 복원

이전 세션에서 이어서 작업한다면:

```bash
cat be/CLAUDE.md    # BE 작업 현황 + 진행 현황
cat fe/CLAUDE.md    # FE 작업 현황 + 진행 현황
```

---

## 서브모듈 작업 방법

```bash
# be/ 작업 시
cd be
git checkout dev      # 작업 브랜치
# ... 작업 ...
git add . && git commit -m "feat: ..."
git push origin dev

# 루트에서 서브모듈 포인터 업데이트
cd ..
git add be
git commit -m "chore: update be submodule"
git push
```

---

## 스킬 사용

```
/create-api       → be/ 디렉토리에서 새 API 엔드포인트 생성
/apply-new-tech   → 새 기술 도입 방법 조사 및 추천
/update-README-md → 소스코드 기반으로 모든 README.md 최신화
```

### /update-README-md 실행 타이밍

- **setup.sh 완료 직후** (boilerplate에서 분리된 시점) — 1회 필수 실행
- **주요 기능 추가/변경 후** — 주기적 실행 권장
- **PR 생성 전** — README 최신 여부 확인

---

## 서브모듈 추가 (be/fe 외)

프로젝트에 macro, worker, admin 등 **새 서브레포**가 필요할 때:

```bash
# 1. GitHub 레포 생성
gh repo create {GITHUB_OWNER}/{PROJECT_NAME}-macro --private

# 2. 로컬에서 초기화 + push
mkdir /tmp/macro-init && cd /tmp/macro-init
git init && echo "# {PROJECT_NAME}-macro" > README.md
git add . && git commit -m "chore: init"
git remote add origin git@github.com:{GITHUB_OWNER}/{PROJECT_NAME}-macro.git
git push -u origin main

# 3. 서브모듈로 등록
cd {PROJECT_ROOT}
git submodule add git@github.com:{GITHUB_OWNER}/{PROJECT_NAME}-macro.git macro
git add .gitmodules macro
git commit -m "chore: add macro submodule"
git push

# 4. (선택) dev 브랜치 생성
cd macro && git checkout -b dev && git push -u origin dev && cd ..

# 5. (선택) GitHub Actions vars 등록 — scripts/github.sh 가 있으면
cd macro && bash scripts/github.sh setup dev ../../dev.env
```

서브모듈 추가 후 **반드시 `/update-README-md` 실행**해서 README 최신화.

---

## AI 멀티 에이전트 협업

이 boilerplate는 멀티 에이전트 협업을 지원하도록 설계되어 있다.
자세한 내용: `docs/ai-philosophy.md`

**핵심 패턴:**
- BE 에이전트, FE 에이전트, Conductor 에이전트를 분리 운영
- 에이전트 간 통신은 파일 신호(`~/.ai-workspace/signals/*.done`)로
- Conductor가 완료 신호를 감지해 다음 작업 트리거

```bash
# Conductor 루프 예시
while true; do
  if [ -f ~/.ai-workspace/signals/be.done ]; then
    rm ~/.ai-workspace/signals/be.done
    claude -p "fe 작업 시작: ..."
  fi
  sleep 30
done
```

---

## Ground Rules

### Branch Strategy (브랜치 전략)

2-tier: dev(검증) / prod(운영).

```
main ──────────────────────────── prod 배포 (자동)
 │
 └── dev ──────────────────────── dev 배포 (자동), 데모/검증용
      │
      ├── feat/auth-middleware ── 기능 개발 (feature)
      ├── fix/cors-error ──────── 버그 수정 (bugfix)
      └── refactor/api-layer ──── 리팩토링
```

#### New Feature (새 기능)

```
1. main → feat/xxx 브랜치 생성
2. feat에서 작업 + 작은 단위 커밋
3. feat → dev (PR, squash merge) → dev 환경에서 검증
4. 문제 시 feat에서 수정 → dev에 새 PR
5. 검증 완료 → feat → main (PR, squash merge) → prod 배포
```

> **feat → dev (검증), feat → main (배포). dev → main 아님.**
> dev에는 검증 중인 다른 feat이 섞여 있을 수 있으므로 feat에서 직접 main으로 merge한다.

#### Hotfix (운영 긴급 수정)

```
1. main → hotfix/xxx 브랜치 생성
2. 수정
3. hotfix → main (PR, squash merge) → 즉시 배포
4. main → dev (sync merge)
```

#### dev 브랜치 관리

- dev는 실험장이다. 깨질 수 있다.
- 지저분해지면 main 기준으로 리셋해도 된다.
- dev 환경 데이터는 seed 데이터 — 언제든 초기화 가능.

---

### Commit Convention (커밋 컨벤션)

#### Format (형식)

```
type(scope): short description in English
한국어 설명 (optional)

# Examples:
feat(be): add JWT authentication middleware
JWT 인증 미들웨어 추가

fix(fe): resolve CORS error on API calls
API 호출 시 CORS 에러 수정

refactor: extract common error handler
공통 에러 핸들러 분리
```

#### Type

| type | 용도 |
|---|---|
| `feat` | 새 기능 (new feature) |
| `fix` | 버그 수정 (bug fix) |
| `refactor` | 리팩토링 (동작 변경 없음) |
| `docs` | 문서 (documentation) |
| `chore` | 빌드, 설정, 패키지 등 잡무 |
| `ci` | CI/CD 변경 |
| `test` | 테스트 추가/수정 |
| `style` | 코드 포맷, 세미콜론 등 (동작 변경 없음) |

#### Scope (선택)

| scope | 대상 |
|---|---|
| `be` | backend |
| `fe` | frontend |
| `infra` | terraform, AWS |
| 생략 | 전체 또는 루트 레포 |

#### Commit Attitude (커밋 태도)

- **feat 브랜치에서**: 자유롭게 — `wip`, `tmp`, `fix typo` 다 괜찮다.
- **dev/main으로 squash merge할 때**: 의미 있는 메시지 하나로 정리한다.
- **main merge 전 1분 멈추기**: "dev에서 테스트했나?", "기존 기능 깨뜨리진 않나?"
- **작게 자주 커밋한다** — 작업을 잘게 쪼개서 의미 있는 단위(테스트 통과한 작은 변경)마다 커밋. 거대한 단일 커밋 금지.

---

### Activity Log (활동 로그)

`ACTIVITY.md` (루트, git 추적) 는 최근 작업의 압축 요약. `what-to-do` 스킬이 영역별 git log/CLAUDE.md/README 를 다시 읽지 않고 이걸로 빠르게 컨텍스트를 잡는다.

#### 작성 규칙

- **언제**: 의미 있는 커밋(feat/fix/refactor/docs/chore 등 코드/문서/인프라 변경)이 만들어질 때마다 한 줄 추가. submodule 포인터 단독 업데이트는 제외 (이미 subrepo 커밋이 자기 줄을 차지함).
- **형식**: `| YYYY-MM-DD | scope | one-line summary (#PR) |` — 한 줄 ≤ 100자.
- **scope**: `root` / `be` / `fe` / `infra` / `docs`.
- **순서**: 최신이 맨 위 (역순).
- **WIP/tmp 커밋은 제외** — squash 후 의미 있는 단위만.

#### 압축 규칙

- **50줄 초과 시**: 가장 오래된 10줄을 `PROGRESS.md` 의 `## 활동 로그 아카이브` 섹션 맨 위에 통째로 이관 후 `ACTIVITY.md` 에서 삭제. 줄 자체는 그대로 보존 (이미 한 줄로 압축된 상태이므로 추가 요약 X).
- 아카이브 섹션이 없으면 새로 만든다.

#### 커밋 + 활동 로그를 같이 처리

작은 단위 커밋을 만들 때 변경 파일에 `ACTIVITY.md` 한 줄 추가도 같이 포함시킨다. 별도 커밋으로 분리하지 않는다. (예: `feat(fe): X` 커밋이 `fe/...` 변경 + `ACTIVITY.md` 한 줄 추가를 모두 포함)

---

### Coding Convention (코딩 컨벤션)

#### 공통 (Common)

- 상수: `UPPER_SNAKE_CASE`
- 불필요한 주석 X — 코드로 의도를 표현한다.
- 에러는 삼키지 않는다 — 명시적으로 처리하거나 위로 전파한다.

#### Backend (Python)

- 함수/변수: `snake_case`
- 클래스: `PascalCase`
- 파일명: `snake_case.py`

#### Frontend (JavaScript/React)

- 함수/변수: `camelCase`
- 컴포넌트: `PascalCase` (파일명도 `PascalCase.jsx`)
- 유틸/훅 파일: `camelCase.js`

---

## 환경 설정

```bash
# 환경 파일 (stage별 분리)
cp dev.sample.env dev.env     # dev 환경
cp prod.sample.env prod.env   # prod 환경
# 각 파일에서 PROJECT_NAME, AWS_ACCOUNT_ID 등 설정
# (GitHub 인증은 `gh auth login` + SSH 키 등록으로 대체됨 — 토큰 불필요)
```

프로젝트 초기화:
```bash
bash scripts/setup.sh    # GitHub 레포 생성 + AWS 백엔드 초기화 + GH vars 자동 등록
```

초기화 후 필수:
```bash
/update-README-md         # README.md 최신화 (boilerplate → 프로젝트 전환)
```
