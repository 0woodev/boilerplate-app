# boilerplate-app

새로운 프로젝트를 시작할 때 GitHub 레포 생성 및 기본 구조를 자동으로 세팅해주는 boilerplate 도구.

## 레포 구조

```
boilerplate-app/          ← 이 레포 (setup 실행 위치)
├── .gitignore
├── config.env            ← 실제 설정값 (gitignore 처리)
├── config.env.sample     ← 설정 템플릿
└── scripts/
    ├── setup.sh          ← 새 프로젝트 세팅
    └── init_boilerplate.sh ← boilerplate 레포 최초 업로드용
```

## 연관 레포

| 레포 | 역할 |
|---|---|
| [boilerplate-fe](https://github.com/0woodev/boilerplate-fe) | Frontend 템플릿 |
| [boilerplate-be](https://github.com/0woodev/boilerplate-be) | Backend 템플릿 |

## 사용 방법

### 새 프로젝트 시작 시

```bash
# 1. 클론
git clone https://github.com/0woodev/boilerplate-app.git {app_name}
cd {app_name}

# 2. config.env 작성 (최초 실행 시 sample 자동 복사)
bash scripts/setup.sh

# 3. config.env 값 채우기
vi config.env

# 4. 다시 실행
bash scripts/setup.sh
```

### setup.sh 실행 결과

1. GitHub에 `{app_name}`, `{app_name}-fe`, `{app_name}-be` 레포 생성
2. `boilerplate-fe` 클론 → remote를 `{app_name}-fe`로 교체 → push
3. `boilerplate-be` 클론 → remote를 `{app_name}-be`로 교체 → push
4. 현재 레포에 `fe/`, `be/`를 git submodule로 등록
5. S3 버킷 + DynamoDB 테이블 생성 (Terraform state 백엔드용)

## config.env 설정

```bash
PROJECT_NAME="my-app"          # 새 프로젝트 이름
DOMAIN="0woodev.com"           # 도메인 ({app_name}.0woodev.com 형태로 사용)

GITHUB_OWNER="0woodev"         # GitHub 유저명 또는 org명
GITHUB_OWNER_TYPE="user"       # "user" | "org"
GITHUB_VISIBILITY="public"     # "public" | "private"
GITHUB_TOKEN=""                # GitHub PAT (repo, delete_repo 권한 필요)

BOILERPLATE_OWNER="0woodev"    # boilerplate 레포 소유자
BOILERPLATE_FE_REPO="boilerplate-fe"
BOILERPLATE_BE_REPO="boilerplate-be"

AWS_REGION="ap-northeast-2"
AWS_ACCOUNT_ID=""
```

## 생성되는 인프라 구조 (예정)

```
{app_name}.0woodev.com        ← FE (CloudFront + S3)
{app_name}-api.0woodev.com   ← BE (API Gateway + Lambda)
```

## 의존성

- `git`
- `curl`
- `aws` CLI (선택 — 없으면 Terraform 백엔드 생성 스킵)

## 히스토리

- 초기 설계: Python + boto3 + DynamoDB + Lambda + Terraform + SQS + GitHub(3 repo) 구성
- FE 인프라: CloudFront + S3 + ACM + Route53 (비용 최적화)
- BE 인프라: Terraform (GitHub Actions CI/CD + S3 state 백엔드)
- `gh` CLI 의존성 제거 → `curl` + `git`으로 대체
- config.env gitignore 처리, config.env.sample 템플릿화

## 앞으로 할 것

- [ ] `fe/` 내부 구조 및 FE 배포 방식 확정
- [ ] `be/` 내부 구조 (Lambda, DynamoDB wrapper, Layer 등)
- [ ] Terraform 인프라 코드 (lambda.tf, api_gateway.tf, cloudfront.tf 등)
- [ ] GitHub Actions CI/CD workflow (OIDC 인증, terraform plan/apply)
- [ ] boto3 DynamoDB wrapper 라이브러리
