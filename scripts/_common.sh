#!/bin/bash
# 공통 유틸 - 다른 스크립트에서 source 해서 사용

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
STAGE="${STAGE:-dev}"
CONFIG_FILE="${ROOT_DIR}/${STAGE}.env"
CONFIG_SAMPLE="${ROOT_DIR}/sample.env"

if [ ! -f "$CONFIG_FILE" ]; then
  [ -f "$CONFIG_SAMPLE" ] || error "sample.env 파일이 없습니다: $CONFIG_SAMPLE"
  cp "$CONFIG_SAMPLE" "$CONFIG_FILE"
  info "sample.env → ${STAGE}.env 복사 완료"
  warn "${STAGE}.env 를 열어 값을 채운 후 다시 실행해주세요."
  exit 0
fi

source "$CONFIG_FILE"
info "${STAGE}.env 로드 완료"
