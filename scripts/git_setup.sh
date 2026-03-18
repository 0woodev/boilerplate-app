#!/bin/bash
set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

# git 인증용 base URL
GIT_BASE="https://x-access-token:${GITHUB_TOKEN}@github.com"

# ============================================================
# 필수 값 검증
# ============================================================
for var in PROJECT_NAME GITHUB_OWNER GITHUB_OWNER_TYPE GITHUB_TOKEN \
           BOILERPLATE_OWNER BOILERPLATE_FE_REPO BOILERPLATE_BE_REPO; do
  [ -n "${!var}" ] || error "${var} 이 config.env 에 설정되지 않았습니다."
done
info "필수 값 검증 완료"

# ============================================================
# 의존성 확인
# ============================================================
for cmd in git curl; do
  command -v "$cmd" &> /dev/null || error "'$cmd' 가 설치되어 있지 않습니다."
done
info "의존성 확인 완료 (git, curl)"

GITHUB_API="https://api.github.com"
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"
PRIVATE=$( [ "$GITHUB_VISIBILITY" = "private" ] && echo "true" || echo "false" )

# ============================================================
# GitHub repo 존재 여부 확인
# ============================================================
repo_exists() {
  local repo_name=$1
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "$AUTH_HEADER" \
    "${GITHUB_API}/repos/${GITHUB_OWNER}/${repo_name}")
  [ "$status" = "200" ]
}

# ============================================================
# GitHub repo 생성
# ============================================================
create_github_repo() {
  local repo_name=$1
  local description=$2

  if repo_exists "$repo_name"; then
    warn "레포가 이미 존재합니다: ${GITHUB_OWNER}/${repo_name}"
    return
  fi

  local api_url
  if [ "$GITHUB_OWNER_TYPE" = "org" ]; then
    api_url="${GITHUB_API}/orgs/${GITHUB_OWNER}/repos"
  else
    api_url="${GITHUB_API}/user/repos"
  fi

  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${repo_name}\", \"description\": \"${description}\", \"private\": ${PRIVATE}}" \
    "$api_url")

  [ "$status" = "201" ] || error "레포 생성 실패: ${repo_name} (HTTP $status)"
  info "레포 생성 완료: ${GITHUB_OWNER}/${repo_name}"
}

# ============================================================
# 플레이스홀더 치환
# ============================================================
replace_placeholders() {
  local dir=$1

  find "$dir" -type f \
    ! -path '*/.git/*' \
    \( -name "*.md" -o -name "*.tf" -o -name "*.yml" -o -name "*.yaml" \
       -o -name "*.py" -o -name "*.txt" \) | while read -r f; do
    sed -i.bak \
      -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
      -e "s|{{FE_DOMAIN}}|${FE_DOMAIN}|g" \
      -e "s|{{BE_DOMAIN}}|${BE_DOMAIN}|g" \
      -e "s|{{AWS_REGION}}|${AWS_REGION}|g" \
      -e "s|{{AWS_ACCOUNT_ID}}|${AWS_ACCOUNT_ID}|g" \
      -e "s|{{GITHUB_OWNER}}|${GITHUB_OWNER}|g" \
      -e "s|{{TF_STATE_BUCKET}}|${TF_STATE_BUCKET}|g" \
      "$f" && rm -f "${f}.bak"
  done
}

# ============================================================
# boilerplate 클론 → remote 교체 → push → submodule 등록
# ============================================================
setup_sub_repo() {
  local boilerplate_repo=$1
  local new_repo_name=$2
  local submodule_path=$3

  # submodule 이미 등록되어 있으면 스킵
  if git -C "$ROOT_DIR" submodule status "$submodule_path" &>/dev/null; then
    warn "submodule 이 이미 등록되어 있습니다: ${submodule_path}"
    return
  fi

  local tmp_dir
  tmp_dir=$(mktemp -d)
  local plain_remote="https://github.com/${GITHUB_OWNER}/${new_repo_name}.git"
  local auth_remote="${GIT_BASE}/${GITHUB_OWNER}/${new_repo_name}.git"

  info "${boilerplate_repo} 클론 중..."
  git clone "${GIT_BASE}/${BOILERPLATE_OWNER}/${boilerplate_repo}.git" "$tmp_dir"

  replace_placeholders "$tmp_dir"

  git -C "$tmp_dir" remote set-url origin "$auth_remote"

  if [ -n "$(git -C "$tmp_dir" status --porcelain)" ]; then
    git -C "$tmp_dir" add -A
    git -C "$tmp_dir" commit -m "chore: apply project config from boilerplate"
  fi

  git -C "$tmp_dir" push -u origin main
  info "푸시 완료: ${GITHUB_OWNER}/${new_repo_name}"

  git -C "$ROOT_DIR" submodule add "$plain_remote" "$submodule_path"

  rm -rf "$tmp_dir"
  info "submodule 등록 완료: ${submodule_path} → ${new_repo_name}"
}

# ============================================================
# 1. GitHub 레포 생성
# ============================================================
info "===== GitHub 레포 생성 ====="
create_github_repo "$PROJECT_NAME"  "Main repository for ${PROJECT_NAME}"
create_github_repo "$FE_REPO_NAME"  "Frontend for ${PROJECT_NAME}"
create_github_repo "$BE_REPO_NAME"  "Backend for ${PROJECT_NAME}"

# ============================================================
# 2. boilerplate 기반으로 fe/be 초기화
# ============================================================
info "===== FE 초기화 ====="
setup_sub_repo "$BOILERPLATE_FE_REPO" "$FE_REPO_NAME" "fe"

info "===== BE 초기화 ====="
setup_sub_repo "$BOILERPLATE_BE_REPO" "$BE_REPO_NAME" "be"

# ============================================================
# 3. main repo submodule 커밋
# ============================================================
info "===== Main repo 커밋 ====="
cd "$ROOT_DIR"

if [ -n "$(git status --porcelain)" ]; then
  git add .gitmodules fe be
  git commit -m "chore: add fe/be submodules for ${PROJECT_NAME}"
  git push "${GIT_BASE}/${GITHUB_OWNER}/${PROJECT_NAME}.git" main
  info "Main repo 업데이트 완료"
else
  warn "Main repo 에 변경사항 없음 (이미 커밋된 상태)"
fi

# ============================================================
# 완료
# ============================================================
echo ""
info "===== Git 셋업 완료 ====="
echo ""
echo "  FE repo : https://github.com/${GITHUB_OWNER}/${FE_REPO_NAME}"
echo "  BE repo : https://github.com/${GITHUB_OWNER}/${BE_REPO_NAME}"
echo ""
echo "  다음 단계: bash scripts/aws_setup.sh"
echo ""
