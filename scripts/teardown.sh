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

[ -f "$CONFIG_FILE" ] || error "dev.env 파일이 없습니다: $CONFIG_FILE"
source "$CONFIG_FILE"
info "dev.env 로드 완료"

# ============================================================
# 필수 값 검증
# ============================================================
for var in PROJECT_NAME GITHUB_OWNER GITHUB_TOKEN AWS_REGION AWS_ACCOUNT_ID; do
  [ -n "${!var}" ] || error "${var} 이 dev.env 에 설정되지 않았습니다."
done

GITHUB_API="https://api.github.com"
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"
FE_REPO_NAME="${PROJECT_NAME}-fe"
BE_REPO_NAME="${PROJECT_NAME}-be"
TF_STATE_BUCKET="${GITHUB_OWNER}-${PROJECT_NAME}-tf-state"
LOCK_TABLE="${PROJECT_NAME}-tf-lock"

# ============================================================
# 삭제 확인
# ============================================================
echo ""
warn "===== 삭제 대상 ====="
echo "  GitHub 레포 : ${GITHUB_OWNER}/${PROJECT_NAME}"
echo "  GitHub 레포 : ${GITHUB_OWNER}/${FE_REPO_NAME}"
echo "  GitHub 레포 : ${GITHUB_OWNER}/${BE_REPO_NAME}"
echo "  S3 버킷     : ${TF_STATE_BUCKET}"
echo "  DynamoDB    : ${LOCK_TABLE}"
echo ""
warn "⚠️  이 작업은 되돌릴 수 없습니다. Terraform destroy 가 완료된 후 실행하세요."
echo -n "계속하려면 'yes' 를 입력하세요: "
read -r CONFIRM
[ "$CONFIRM" = "yes" ] || error "취소되었습니다."

# ============================================================
# 1. GitHub 레포 삭제
# ============================================================
delete_github_repo() {
  local repo_name=$1
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE \
    -H "$AUTH_HEADER" \
    "${GITHUB_API}/repos/${GITHUB_OWNER}/${repo_name}")
  if [ "$status" = "204" ]; then
    info "GitHub 레포 삭제 완료: ${GITHUB_OWNER}/${repo_name}"
  elif [ "$status" = "404" ]; then
    warn "GitHub 레포 없음 (이미 삭제됨): ${GITHUB_OWNER}/${repo_name}"
  else
    warn "GitHub 레포 삭제 실패: ${repo_name} (HTTP $status)"
  fi
}

info "===== GitHub 레포 삭제 ====="
delete_github_repo "$BE_REPO_NAME"
delete_github_repo "$FE_REPO_NAME"
delete_github_repo "$PROJECT_NAME"

# ============================================================
# 2. S3 tf-state 버킷 삭제
# ============================================================
info "===== S3 Terraform state 버킷 삭제 ====="
if ! command -v aws &> /dev/null; then
  warn "aws CLI 가 없어 S3/DynamoDB 삭제를 건너뜁니다."
else

  if aws s3api head-bucket --bucket "$TF_STATE_BUCKET" 2>/dev/null; then
    python3 -c "
import subprocess, json

bucket = '${TF_STATE_BUCKET}'
for list_type in ['Versions', 'DeleteMarkers']:
    result = subprocess.run(
        ['aws', 's3api', 'list-object-versions', '--bucket', bucket, '--output', 'json'],
        capture_output=True, text=True
    )
    data = json.loads(result.stdout or '{}')
    objects = [{'Key': o['Key'], 'VersionId': o['VersionId']} for o in data.get(list_type, [])]
    if objects:
        subprocess.run(
            ['aws', 's3api', 'delete-objects', '--bucket', bucket,
             '--delete', json.dumps({'Objects': objects, 'Quiet': True})],
            check=True
        )
        print(f'Deleted {len(objects)} {list_type}')
"
    aws s3api delete-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION"
    info "S3 버킷 삭제 완료: ${TF_STATE_BUCKET}"
  else
    warn "S3 버킷 없음 (이미 삭제됨): ${TF_STATE_BUCKET}"
  fi

  # ============================================================
  # 3. DynamoDB lock 테이블 삭제
  # ============================================================
  info "===== DynamoDB lock 테이블 삭제 ====="
  if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$AWS_REGION" 2>/dev/null; then
    aws dynamodb delete-table --table-name "$LOCK_TABLE" --region "$AWS_REGION"
    info "DynamoDB 테이블 삭제 완료: ${LOCK_TABLE}"
  else
    warn "DynamoDB 테이블 없음 (이미 삭제됨): ${LOCK_TABLE}"
  fi

fi

# ============================================================
# 완료
# ============================================================
echo ""
info "===== 정리 완료 ====="
echo ""
echo "  로컬 폴더를 삭제하려면:"
echo "  rm -rf ${ROOT_DIR}"
echo ""
