# 활동 로그

> 최근 50개 커밋의 한 줄 요약. 작성/압축 규칙은 `CLAUDE.md` → **"Activity Log"** 섹션 참조.
> 가장 최근이 맨 위.

| 날짜 | scope | 요약 |
|---|---|---|
| 2026-06-23 | fe | PatchNote 화면: usePatchNotes 훅 + 날짜별 타임라인(Markdown 바디·title/body 편집) + nav/route + MSW |
| 2026-06-23 | be | PatchNote 데모 도메인: model+API(GET공개/CUD인증)+terraform + generate_patch_notes.py(L1 멱등+L2 LLM초안) + CI |
| 2026-06-23 | fe | hj-adlog 풀스택 이식: TS·Tailwind·shadcn(기본셋12)·TanStack Query·MSW·앱셸·헤더인증(X-Auth-User) 스켈레톤 |
| 2026-06-23 | be | 로컬 DynamoDB 워크플로(local-db*·create/sync 스크립트) + access.py(bcrypt, X-Auth-User placeholder) |
| 2026-06-23 | root | Activity Log·커밋 관례 추가 + what-to-do·update-README-md 스킬 hj-adlog 역이식 |
| 2026-06-23 | infra | CI 캐시키 내용기반화(plan read-only)·pipefail·force-unlock·deletion_protection·IAM 권한 보강 |
| 2026-06-23 | be | hj-adlog 범용분 역이식: ids·Decimal직렬화·get_header·로컬endpoint·/health·$default fallback·db-ops 문서 |
