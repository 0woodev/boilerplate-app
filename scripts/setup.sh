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
# dev.env / prod.env 로드 — 둘 중 하나라도 없으면 sample 복사 후 종료
# (사용자가 값 채운 뒤 재실행)
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
DEV_ENV="${ROOT_DIR}/dev.env"
PROD_ENV="${ROOT_DIR}/prod.env"
DEV_SAMPLE="${ROOT_DIR}/dev.sample.env"
PROD_SAMPLE="${ROOT_DIR}/prod.sample.env"

NEED_FILL=0
for env_pair in "$DEV_ENV:$DEV_SAMPLE" "$PROD_ENV:$PROD_SAMPLE"; do
  target="${env_pair%:*}"
  sample="${env_pair#*:}"
  if [ ! -f "$target" ]; then
    [ -f "$sample" ] || error "sample 파일이 없습니다: $sample"
    cp "$sample" "$target"
    info "$(basename "$sample") → $(basename "$target") 복사 완료"
    NEED_FILL=1
  fi
done

if [ "$NEED_FILL" = "1" ]; then
  warn "dev.env / prod.env 를 열어 값을 채운 후 다시 실행해주세요."
  exit 0
fi

# dev.env 기준으로 진행 (GitHub 레포 생성 등 stage 무관 작업)
source "$DEV_ENV"
info "dev.env / prod.env 로드 완료 (이 스크립트는 dev.env 기준 진행)"

# ============================================================
# 필수 값 검증
# ============================================================
for var in PROJECT_NAME GITHUB_OWNER GITHUB_OWNER_TYPE \
           BOILERPLATE_OWNER BOILERPLATE_FE_REPO BOILERPLATE_BE_REPO \
           AWS_REGION AWS_ACCOUNT_ID; do
  [ -n "${!var}" ] || error "${var} 이 dev.env 에 설정되지 않았습니다."
done
info "필수 값 검증 완료"

# ============================================================
# 의존성 확인
# ============================================================
for cmd in git gh; do
  command -v "$cmd" &> /dev/null || error "'$cmd' 가 설치되어 있지 않습니다."
done
info "의존성 확인 완료 (git, gh)"

# gh 인증 + SSH 사용 가능 여부 체크
gh auth status &> /dev/null || error "'gh auth login' 먼저 실행해주세요."
ssh -T -o BatchMode=yes -o StrictHostKeyChecking=no git@github.com 2>&1 | \
  grep -q "successfully authenticated" || \
  error "GitHub SSH 접근 실패. ~/.ssh/ 키가 GitHub 에 등록되어 있는지 확인하세요."
info "gh 인증 + SSH 접근 확인 완료"

PRIVATE_FLAG=$( [ "$GITHUB_VISIBILITY" = "private" ] && echo "--private" || echo "--public" )

# ============================================================
# GitHub repo 존재 여부 확인
# ============================================================
repo_exists() {
  local repo_name=$1
  gh repo view "${GITHUB_OWNER}/${repo_name}" &> /dev/null
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

  gh repo create "${GITHUB_OWNER}/${repo_name}" \
    $PRIVATE_FLAG \
    --description "${description}" \
    > /dev/null

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
# boilerplate 클론 (SSH) → remote 교체 → push → submodule 등록
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
  local ssh_remote="git@github.com:${GITHUB_OWNER}/${new_repo_name}.git"
  local boilerplate_ssh="git@github.com:${BOILERPLATE_OWNER}/${boilerplate_repo}.git"

  info "${boilerplate_repo} 클론 중..."
  git clone "$boilerplate_ssh" "$tmp_dir"

  replace_placeholders "$tmp_dir"

  git -C "$tmp_dir" remote set-url origin "$ssh_remote"

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

  # submodule 등록 (SSH URL 사용 — .gitmodules 에 커밋됨)
  git -C "$ROOT_DIR" submodule add "$ssh_remote" "$submodule_path"

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

# origin을 새 레포로 변경 (SSH)
git remote set-url origin "git@github.com:${GITHUB_OWNER}/${PROJECT_NAME}.git"

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
# 5. Global AWS 리소스 생성 (계정당 1회, Terraform 외부 관리)
#    - OIDC Provider: GitHub Actions 인증
#    - Wildcard ACM Cert: 커스텀 도메인 HTTPS
# ============================================================
info "===== Global AWS 리소스 생성 ====="
if ! command -v aws &> /dev/null; then
  warn "aws CLI 가 없어 Global 리소스 생성을 건너뜁니다."
else

# OIDC Provider
OIDC_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" 2>/dev/null; then
  warn "OIDC Provider 이미 존재합니다: ${OIDC_ARN}"
else
  aws iam create-open-id-connect-provider \
    --url "https://token.actions.githubusercontent.com" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1"
  info "OIDC Provider 생성 완료"
fi

# Wildcard ACM Certificate (us-east-1 고정)
# BE/FE 모두 CloudFront를 사용하므로 us-east-1 인증서 하나로 통일
if [ -z "$DOMAIN" ]; then
  warn "DOMAIN 이 설정되지 않아 ACM 인증서 생성을 건너뜁니다."
else
  EXISTING_CERT=$(aws acm list-certificates \
    --region us-east-1 \
    --query "CertificateSummaryList[?DomainName=='*.${DOMAIN}'].CertificateArn" \
    --output text)

  if [ -n "$EXISTING_CERT" ] && [ "$EXISTING_CERT" != "None" ]; then
    warn "Wildcard ACM 인증서 이미 존재합니다 (us-east-1): ${EXISTING_CERT}"
  else
    info "Wildcard ACM 인증서 생성 중 (us-east-1): *.${DOMAIN}"
    CERT_ARN=$(aws acm request-certificate \
      --domain-name "*.${DOMAIN}" \
      --validation-method DNS \
      --region us-east-1 \
      --query 'CertificateArn' --output text)

    sleep 5  # DNS validation options 생성 대기

    CNAME_NAME=$(aws acm describe-certificate \
      --certificate-arn "$CERT_ARN" \
      --region us-east-1 \
      --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Name' \
      --output text)

    CNAME_VALUE=$(aws acm describe-certificate \
      --certificate-arn "$CERT_ARN" \
      --region us-east-1 \
      --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Value' \
      --output text)

    ZONE_ID=$(aws route53 list-hosted-zones-by-name \
      --dns-name "${DOMAIN}." \
      --query 'HostedZones[0].Id' --output text | sed 's|/hostedzone/||')

    aws route53 change-resource-record-sets \
      --hosted-zone-id "$ZONE_ID" \
      --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"${CNAME_NAME}\",\"Type\":\"CNAME\",\"TTL\":60,\"ResourceRecords\":[{\"Value\":\"${CNAME_VALUE}\"}]}}]}"

    info "DNS validation 레코드 생성 완료. 인증서 검증 대기 중... (최대 3분)"
    aws acm wait certificate-validated --certificate-arn "$CERT_ARN" --region us-east-1
    info "ACM Wildcard 인증서 발급 완료 (us-east-1): ${CERT_ARN}"
  fi
fi

fi  # aws CLI check

# ============================================================
# 6. BE/FE 양쪽에 GitHub Actions vars/env 자동 등록 (dev + prod)
# ============================================================
info "===== GitHub Actions vars/env 등록 (dev + prod) ====="
for stage_env in "$DEV_ENV" "$PROD_ENV"; do
  stage_name=$(basename "$stage_env" .env)
  for sub in "be" "fe"; do
    sub_path="${ROOT_DIR}/${sub}"
    if [ -f "${sub_path}/scripts/github.sh" ]; then
      info "→ ${sub}/scripts/github.sh setup ${stage_name}"
      bash "${sub_path}/scripts/github.sh" setup "${stage_name}" "$stage_env" || \
        warn "${sub} ${stage_name} setup 실패 (수동 실행 필요)"
    else
      warn "${sub}/scripts/github.sh 가 없습니다 — 수동 등록 필요"
    fi
  done
done

# ============================================================
# 완료
# ============================================================
echo ""
info "===== 셋업 완료 ====="
echo ""
echo "  FE repo  : https://github.com/${GITHUB_OWNER}/${FE_REPO_NAME}"
echo "  BE repo  : https://github.com/${GITHUB_OWNER}/${BE_REPO_NAME}"
echo ""
echo "  ── dev ──"
. "$DEV_ENV"
echo "    FE  : ${FE_URL}"
echo "    BE  : ${BE_URL}"
echo "  ── prod ──"
. "$PROD_ENV"
echo "    FE  : ${FE_URL}"
echo "    BE  : ${BE_URL}"
echo ""
echo "  TF state : s3://${TF_STATE_BUCKET}"
echo ""
. "$DEV_ENV"
echo "  다음 단계:"
echo ""
echo "    1. AWS Secrets 등록 (Global 실행 전 필수 — OIDC 생성 전이라 Access Key 필요):"
echo "       gh secret set AWS_ACCESS_KEY_ID --repo ${GITHUB_OWNER}/${BE_REPO_NAME}"
echo "       gh secret set AWS_SECRET_ACCESS_KEY --repo ${GITHUB_OWNER}/${BE_REPO_NAME}"
echo "       gh secret set AWS_ACCESS_KEY_ID --repo ${GITHUB_OWNER}/${FE_REPO_NAME}"
echo "       gh secret set AWS_SECRET_ACCESS_KEY --repo ${GITHUB_OWNER}/${FE_REPO_NAME}"
echo ""
echo "    2. Terraform Global (1회) — OIDC role 생성:"
echo "       BE: ${GITHUB_OWNER}/${BE_REPO_NAME} → Actions → 'Terraform Global' → Run workflow"
echo "       FE: ${GITHUB_OWNER}/${FE_REPO_NAME} → Actions → 'Terraform Global' → Run workflow"
echo ""
echo "    3. dev 브랜치 push → 자동 배포:"
echo "       cd be && git checkout -b dev && git push -u origin dev"
echo "       cd ../fe && git checkout -b dev && git push -u origin dev"
echo ""
