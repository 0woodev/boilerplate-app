#!/bin/bash
set -e

# ============================================================
# 색상 출력
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ============================================================
# config.env 로드
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
CONFIG_FILE="${ROOT_DIR}/config.env"
CONFIG_SAMPLE="${ROOT_DIR}/config.env.sample"

if [ ! -f "$CONFIG_FILE" ]; then
  [ -f "$CONFIG_SAMPLE" ] || error "config.env.sample 파일이 없습니다."
  cp "$CONFIG_SAMPLE" "$CONFIG_FILE"
  warn "config.env 를 열어 값을 채운 후 다시 실행해주세요."
  exit 0
fi

source "$CONFIG_FILE"
info "config.env 로드 완료"

GIT_BASE="https://x-access-token:${GITHUB_TOKEN}@github.com"
GITHUB_API="https://api.github.com"
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"

# ============================================================
# 필수 값 검증
# ============================================================
for var in GITHUB_TOKEN BOILERPLATE_OWNER BOILERPLATE_FE_REPO BOILERPLATE_BE_REPO; do
  [ -n "${!var}" ] || error "${var} 이 config.env 에 설정되지 않았습니다."
done

# ============================================================
# GitHub repo 생성
# ============================================================
create_github_repo() {
  local repo_name=$1
  local description=$2

  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "$AUTH_HEADER" \
    "${GITHUB_API}/repos/${BOILERPLATE_OWNER}/${repo_name}")

  if [ "$status" = "200" ]; then
    warn "레포가 이미 존재합니다: ${BOILERPLATE_OWNER}/${repo_name}"
    return
  fi

  if [ "$GITHUB_OWNER_TYPE" = "org" ]; then
    api_url="${GITHUB_API}/orgs/${BOILERPLATE_OWNER}/repos"
  else
    api_url="${GITHUB_API}/user/repos"
  fi

  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${repo_name}\", \"description\": \"${description}\", \"private\": false}" \
    "$api_url")

  [ "$status" = "201" ] || error "레포 생성 실패: ${repo_name} (HTTP $status)"
  info "레포 생성 완료: ${BOILERPLATE_OWNER}/${repo_name}"
}

# ============================================================
# git init → commit → push
# ============================================================
init_and_push() {
  local dir=$1
  local repo_name=$2

  cd "$dir"

  if [ ! -d ".git" ]; then
    git init
    git branch -M main
    info "git init 완료: $dir"
  fi

  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "feat: initial boilerplate"
  else
    warn "커밋할 변경사항이 없습니다: ${repo_name}"
  fi

  local remote_url="${GIT_BASE}/${BOILERPLATE_OWNER}/${repo_name}.git"
  git remote remove origin 2>/dev/null || true
  git remote add origin "$remote_url"
  git push -u origin main
  info "푸시 완료: ${BOILERPLATE_OWNER}/${repo_name}"
}

# ============================================================
# boilerplate-fe, boilerplate-be 가 있는 상위 디렉토리
# (boilerplate-app 와 같은 레벨에 위치)
# ============================================================
BOILERPLATE_BASE_DIR="${ROOT_DIR}/.."

# ============================================================
# 1. GitHub 레포 생성
# ============================================================
info "===== GitHub 레포 생성 ====="
create_github_repo "$BOILERPLATE_FE_REPO" "Boilerplate for frontend"
create_github_repo "$BOILERPLATE_BE_REPO" "Boilerplate for backend"

# ============================================================
# 2. git init & push
# ============================================================
info "===== boilerplate-fe 초기화 & 푸시 ====="
init_and_push "${BOILERPLATE_BASE_DIR}/${BOILERPLATE_FE_REPO}" "$BOILERPLATE_FE_REPO"

info "===== boilerplate-be 초기화 & 푸시 ====="
init_and_push "${BOILERPLATE_BASE_DIR}/${BOILERPLATE_BE_REPO}" "$BOILERPLATE_BE_REPO"

# ============================================================
# 완료
# ============================================================
echo ""
info "===== boilerplate 레포 업로드 완료 ====="
echo ""
echo "  FE : https://github.com/${BOILERPLATE_OWNER}/${BOILERPLATE_FE_REPO}"
echo "  BE : https://github.com/${BOILERPLATE_OWNER}/${BOILERPLATE_BE_REPO}"
echo ""
