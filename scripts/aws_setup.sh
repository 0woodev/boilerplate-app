#!/bin/bash
set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

# ============================================================
# 필수 값 검증
# ============================================================
for var in PROJECT_NAME AWS_REGION AWS_ACCOUNT_ID; do
  [ -n "${!var}" ] || error "${var} 이 config.env 에 설정되지 않았습니다."
done
info "필수 값 검증 완료"

# ============================================================
# 의존성 확인
# ============================================================
command -v aws &> /dev/null || error "aws CLI 가 설치되어 있지 않습니다."
info "의존성 확인 완료 (aws)"

LOCK_TABLE="${PROJECT_NAME}-tf-lock"

# ============================================================
# S3 Terraform state 버킷 생성
# ============================================================
info "===== S3 버킷 생성 ====="
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

# ============================================================
# DynamoDB lock 테이블 생성
# ============================================================
info "===== DynamoDB 테이블 생성 ====="
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

# ============================================================
# 완료
# ============================================================
echo ""
info "===== AWS 셋업 완료 ====="
echo ""
echo "  TF state bucket : s3://${TF_STATE_BUCKET}"
echo "  TF lock table   : ${LOCK_TABLE}"
echo "  Region          : ${AWS_REGION}"
echo ""
