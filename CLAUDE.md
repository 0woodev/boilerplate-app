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
/create-api    → be/ 디렉토리에서 새 API 엔드포인트 생성
/apply-new-tech → 새 기술 도입 방법 조사 및 추천
```

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

## 환경 설정

```bash
# 환경 파일
cp sample.env dev.env
cp sample.env prod.env
# 각 파일에서 PROJECT_NAME, AWS_ACCOUNT_ID, GITHUB_TOKEN 등 설정
```

프로젝트 초기화:
```bash
bash scripts/setup.sh    # GitHub 레포 생성 + AWS 백엔드 초기화
cd be && make gh-setup STAGE=dev
cd be && make gh-setup STAGE=prod
```
