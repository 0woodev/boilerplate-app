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
# dev.env 로드
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
CONFIG_FILE="${ROOT_DIR}/dev.env"
CONFIG_SAMPLE="${ROOT_DIR}/sample.env"

if [ ! -f "$CONFIG_FILE" ]; then
  [ -f "$CONFIG_SAMPLE" ] || error "sample.env 파일이 없습니다: $CONFIG_SAMPLE"
  cp "$CONFIG_SAMPLE" "$CONFIG_FILE"
  info "sample.env → dev.env 복사 완료"
  warn "dev.env 를 열어 값을 채운 후 다시 실행해주세요."
  exit 0
fi

source "$CONFIG_FILE"
info "dev.env 로드 완료"

# git 인증용 base URL (토큰 포함, git 내부에서만 사용)
GIT_BASE="https://x-access-token:${GITHUB_TOKEN}@github.com"

# ============================================================
# 필수 값 검증
# ============================================================
for var in PROJECT_NAME GITHUB_OWNER GITHUB_OWNER_TYPE GITHUB_TOKEN \
           BOILERPLATE_OWNER BOILERPLATE_FE_REPO BOILERPLATE_BE_REPO \
           AWS_REGION AWS_ACCOUNT_ID; do
  [ -n "${!var}" ] || error "${var} 이 dev.env 에 설정되지 않았습니다."
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
# boilerplate_repo : e.g. boilerplate-fe
# new_repo_name    : e.g. my-app-fe
# submodule_path   : e.g. fe
# ============================================================
setup_sub_repo() {
  local boilerplate_repo=$1
  local new_repo_name=$2
  local submodule_path=$3

  local tmp_dir
  tmp_dir=$(mktemp -d)
  # 토큰 없는 plain URL → .gitmodules 에 저장됨
  local plain_remote="https://github.com/${GITHUB_OWNER}/${new_repo_name}.git"
  # 토큰 포함 URL → git push 인증용
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

  # 기존 submodule 제거 후 새 URL로 재등록
  if git -C "$ROOT_DIR" config --file "$ROOT_DIR/.gitmodules" --get "submodule.${submodule_path}.url" 2>/dev/null; then
    git -C "$ROOT_DIR" submodule deinit -f "$submodule_path" 2>/dev/null || true
    git -C "$ROOT_DIR" rm -f "$submodule_path" 2>/dev/null || true
    rm -rf "$ROOT_DIR/.git/modules/$submodule_path"
    info "기존 submodule 제거 완료: ${submodule_path}"
  fi

  # submodule 등록 (plain URL 사용 - .gitmodules 에 커밋됨)
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

# origin을 새 레포로 변경 (boilerplate-app clone 시 원래 remote 덮어쓰기)
git remote set-url origin "${GIT_BASE}/${GITHUB_OWNER}/${PROJECT_NAME}.git"

git add .gitmodules fe be
git commit -m "chore: add fe/be submodules for ${PROJECT_NAME}"
git push -u origin main
info "Main repo 업데이트 완료"

# ============================================================
# 4. S3 Terraform state 버킷 + DynamoDB lock 테이블 생성
# ============================================================
info "===== Terraform 백엔드 생성 ====="
if ! command -v aws &> /dev/null; then
  warn "aws CLI 가 없어 Terraform 백엔드 생성을 건너뜁니다."
else

if aws s3api head-bucket --bucket "$TF_STATE_BUCKET" 2>/dev/null; then
  warn "S3 버킷이 이미 존재합니다: ${TF_STATE_BUCKET}"
else
  aws s3api create-bucket \
    --bucket "$TF_STATE_BUCKET" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"

  aws s3api put-bucket-versioning \
    --bucket "$TF_STATE_BUCKET" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "$TF_STATE_BUCKET" \
    --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

  info "S3 버킷 생성 완료: ${TF_STATE_BUCKET}"
fi

LOCK_TABLE="${PROJECT_NAME}-tf-lock"
if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$AWS_REGION" 2>/dev/null; then
  warn "DynamoDB 테이블이 이미 존재합니다: ${LOCK_TABLE}"
else
  aws dynamodb create-table \
    --table-name "$LOCK_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$AWS_REGION"
  info "DynamoDB lock 테이블 생성 완료: ${LOCK_TABLE}"
  fi
fi

# ============================================================
# 완료
# ============================================================
echo ""
info "===== 셋업 완료 ====="
echo ""
echo "  FE repo  : https://github.com/${GITHUB_OWNER}/${FE_REPO_NAME}"
echo "  BE repo  : https://github.com/${GITHUB_OWNER}/${BE_REPO_NAME}"
echo "  FE url   : https://${FE_DOMAIN}"
echo "  BE url   : https://${BE_DOMAIN}"
echo "  TF state : s3://${TF_STATE_BUCKET}"
echo ""
