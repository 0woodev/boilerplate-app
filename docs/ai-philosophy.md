# AI 협업 철학 (AI Collaboration Philosophy)

## 비전

이 프로젝트는 단순한 boilerplate가 아니다.
**클로드코드를 여러 에이전트로 운영해, 마치 여러 명의 개발자가 협력하듯 일하는 방식을 내재화한 프레임워크**다.

---

## 핵심 아이디어

### 에이전트 팀으로 일하기

Claude Code는 하나의 AI 세션이지만, 여러 세션을 동시에 열어 각자 다른 역할을 맡길 수 있다.

| 역할 | 예시 |
|---|---|
| BE 에이전트 | `be/` 디렉토리에서 API 개발 |
| FE 에이전트 | `fe/` 디렉토리에서 컴포넌트 개발 |
| AI/ML 에이전트 | 별도 레포에서 모델 서빙 |
| Conductor | 작업 분배·조율·완료 확인 |

이 구조는 팀의 PO/PM이 티켓을 발행하고, 개발자들이 각자 맡은 파트를 작업하는 방식과 같다.

---

## Conductor 패턴

Conductor는 오케스트라의 지휘자처럼, 각 에이전트의 작업을 정의하고 모니터링하는 역할을 한다.

### 역할
- 큰 목표를 작은 작업 단위로 분해
- 각 에이전트(세션)에 작업 할당
- 완료 신호를 감지해 다음 단계 트리거
- 에이전트 간 의존성·순서 관리

### 작동 원리

Conductor는 주기적으로 공유 파일을 확인해 작업 상태를 판단한다.

```
작업 디렉토리 예시:
~/.ai-workspace/
  tasks/
    be-api.md          ← BE 에이전트가 읽을 작업 지시서
    fe-component.md    ← FE 에이전트가 읽을 작업 지시서
  signals/
    be-api.done        ← BE 에이전트가 완료 후 생성하는 신호 파일
    fe-component.done  ← FE 에이전트가 완료 후 생성하는 신호 파일
```

Conductor 루프 (shell script 예시):

```bash
#!/bin/bash
# conductor.sh - 완료 신호를 감지하고 다음 단계를 트리거

WORKSPACE=~/.ai-workspace

while true; do
  if [ -f "$WORKSPACE/signals/be-api.done" ]; then
    rm "$WORKSPACE/signals/be-api.done"
    echo "BE API 완료 감지. FE 작업 트리거..."
    claude -p "$(cat $WORKSPACE/tasks/fe-component.md)"
  fi
  sleep 30
done
```

에이전트(Claude Code)는 작업 완료 시 신호 파일을 생성한다:

```bash
# 에이전트가 작업 마지막에 실행
touch ~/.ai-workspace/signals/be-api.done
```

### 비용 효율성

- Conductor가 `sleep 30` 상태일 때 **토큰 소비 없음**
- 신호 파일 감지 시점에만 Claude 세션 활성화
- 대규모 병렬 작업도 비용 효율적으로 운영 가능

---

## agent-deck

[agent-deck](https://github.com/asheshgoplani/agent-deck)은 여러 Claude Code 세션을 TUI로 관리하는 도구다.

- **tmux 기반** — 내부적으로 tmux 세션을 생성·관리
- **Conductor 기능** — 모든 에이전트 세션을 한 화면에서 모니터링
- **별도 tmux 불필요** — agent-deck이 tmux를 추상화함

설치:
```bash
brew install agent-deck  # 또는 GitHub 릴리즈에서 바이너리 다운로드
```

사용:
```bash
agent-deck  # TUI 실행
```

---

## 파일 기반 세션 연속성

Claude Code 세션은 컨텍스트가 초기화되면 이전 대화를 기억하지 못한다.
이 문제를 `PROGRESS.md` 패턴으로 해결한다.

### 패턴
1. 각 서브레포(`be/`, `fe/`)에 `PROGRESS.md` 유지
2. 세션 시작 시 Claude가 이 파일을 읽어 맥락 복원
3. 작업 종료 시 Claude가 이 파일을 업데이트

### 예시 (`be/PROGRESS.md` 일부)
```markdown
## Pending 작업 (다음 대화에서 이어서)

1. CloudFront + S3 FE 인프라 구성
2. 인증 미들웨어 (JWT/Cognito)
3. CloudWatch 알람
```

---

## 스킬(Skill) 시스템

Claude Code의 `/skill-name` 명령어를 통해 반복 작업을 자동화한다.

| 스킬 | 용도 |
|---|---|
| `/create-api` | 새 API 엔드포인트 스캐폴딩 (handler.py + terraform) |
| `/apply-new-tech` | 새 기술 도입 방법 조사·평가 |

스킬 파일 위치: `{repo}/.claude/skills/{skill-name}/SKILL.md`

---

## 핵심 원칙

1. **반복은 스킬로** — 두 번 이상 하는 작업은 스킬로 만든다
2. **맥락은 파일로** — 대화 내용이 아닌 파일이 진실의 원천
3. **에이전트는 독립적으로** — 각 에이전트는 자신의 디렉토리에 집중
4. **Conductor가 조율** — 에이전트 간 통신은 파일 신호로
5. **비용을 의식하라** — idle 상태에서 토큰을 쓰지 않도록 설계
