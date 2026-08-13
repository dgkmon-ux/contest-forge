# contest-forge

공모전·해커톤 참가를 **요강 분석 → 아이디어 수렴 → MVP → 발표자료**까지 하나의 파이프라인으로 진행하는 [Claude Code](https://claude.com/claude-code) 스킬.

한국 공모전 실정에 맞춰 만들었다. 국내 공고는 HWP 첨부 전용이거나 JS 렌더 SPA인 경우가 많아 자동 수집이 잘 안 된다는 전제에서 출발한다.

## 무엇을 하는가

```
① recon    요강 전문 → brief.md (필수항목 12) + rubric.md (심사표 정규화)
② ideate   3축 리서치 → 아이디어 12개 발산 → 루브릭 채점 → 상위 3개 견적서
           ⏸ 사용자가 1개 고를 때까지 정지
③ mvp      선택안 → plan.md (15섹션 풀기획안) + 유형별 MVP
④ report   submission.md (제출 규격 검사) + deck.html (16:9) + script.md (대본·Q&A)
```

산출물은 `~/contests/<slug>/`에 쌓이고, `STATE.md`로 세션이 바뀌어도 이어서 작업한다. 여러 공모전을 병행하면 `~/contests/INDEX.md`가 마감 임박순 대시보드가 된다.

## 설계 원칙

**루브릭이 지배한다.** 아이디어 채점·MVP 범위·발표 목차가 전부 `rubric.md`의 항목과 배점을 참조한다. "이게 어느 심사항목을 먹는가"를 답할 수 없는 작업은 하지 않는다.

**수치를 지어내지 않는다.** 모든 통계에 출처 URL을 달고, 못 찾으면 `[출처 필요]`로 남긴 뒤 산출 직후 미해결 목록을 보고한다. 성과지표는 숫자가 아니라 측정방법으로 쓴다 — "차단율 87%"가 아니라 "차단율: 준비된 공격 중 차단된 비율".

**사람이 판단할 지점에서 멈춘다.** 게이트 두 곳(참가 자격·요강 필수항목, 아이디어 선택)에서 강제 정지한다. 참가 자격이나 IP 귀속 조건에서 걸리면 즉시 중단한다 — 참가할 수 없는 대회를 끝까지 준비하는 것이 최악의 실패다.

**공식 배점만 점수로 쓴다.** 주최사 선호나 데이터 활용도 같은 숨은 가중치는 실재하지만 배점에 섞지 않는다. `ideas.md`의 별도 컬럼(적합도·신뢰도·근거)으로 분리해, 요강이 정한 순위를 조용히 뒤집지 않게 한다.

**요강은 URL이 있으면 1회만 선탐색하고, 실패하면 즉시 붙여넣기를 요청한다.** 실패 비용보다 성공 시 절약되는 왕복이 크다. 두 번 시도하지 않는다. `.hwp`는 읽을 수 없으므로 PDF 변환을 요청한다.

## 공모전 유형별 분기

| 유형 | 판별 | MVP 산출물 |
|---|---|---|
| `idea-contest` | 제출물이 문서·PPT뿐, 분석·구현 요구 없음 | 클릭 가능한 단일 HTML 목업 |
| `analysis-model` | 제출물은 문서뿐인데 **실제 데이터 분석·모델 구현을 요구** | 학습된 모델 1개 + 기준모델 대비 지표표 + 시각화 산출물 |
| `hackathon` | 기간 내 개발, 작동하는 결과물 | 실행 가능한 레포 + 시나리오 e2e |
| `startup-grant` | 사업계획서·시장성 | 목업 + 사업성 자료 (PSST 4축) |
| `ai-nativeness` | AI 활용 과정 자체를 채점 | 레포 + 증거 5축 |

`idea-contest`와 `analysis-model`은 제출물 목록만 보면 똑같다 — 갈리는 곳은 **심사기준과 분야 정의**다. 심사항목에 `데이터 이해`·`분석 적정성`·`모델 성능` 배점이 있거나, 분야 정의에 `모델을 개발하고`·`알고리즘을 구현하며` 같은 동사가 있으면 `analysis-model`이다. 이 유형에서 아이디어만 서술하면 해당 배점(흔히 20~30%)이 통째로 날아간다. 유일하게 **합성 데이터 금지 규칙이 뒤집히는** 유형이기도 하다 — 공개 API·포털 실데이터로 학습하되 집계 단위만 쓰고 출처 원장을 남긴다.

`ai-nativeness`는 현장에서 과제를 받는 형식이라 ②를 건너뛰고, 대신 심사자가 읽을 **작업 과정 증거**를 강제 생성한다 — `INTENT.md`(목표·제약·작업분해·의도 갱신 로그), 커밋 규약(`why`/`제약`/`검증`), `verification.log`, `COGNITION.md`(어디서 깨지는가·AI 제안을 거부하고 바꾼 지점), `SESSION-HANDOFF.md`.

## 설치

```bash
git clone https://github.com/dgkmon-ux/contest-forge.git ~/.claude/skills/contest-forge
```

Windows PowerShell:

```powershell
git clone https://github.com/dgkmon-ux/contest-forge.git "$env:USERPROFILE\.claude\skills\contest-forge"
```

## 사용

```
/contest-forge                    진행 중 공모전을 마감 임박순으로 제시
/contest-forge contest-b          해당 공모전을 STATE.md의 단계부터 재개
/contest-forge <새 이름>           새로 등록 (요강 전문을 붙여넣으면 시작)
```

`disable-model-invocation: true`라 **명시 호출로만 뜬다.** 홈 디렉터리에 폴더를 만들고 긴 파이프라인을 시작하므로 "발표자료 만들어줘" 같은 일반 요청에 자동 발동하지 않게 막아 두었다.

> `argument-hint`와 `disable-model-invocation`은 Claude Code 전용 필드다. claude.ai 업로드나 Skills API로 패키징하려면 두 줄을 지워야 한다 — 허용 필드 밖이라 하드 에러가 난다.

## 구조

```
SKILL.md                      라우팅 · 게이트 · 관통 규칙
references/1-recon.md         요강 구조화 · 심사표 정규화
           2-ideate.md        3축 리서치 · 발산과 수렴
           3-mvp.md           유형별 구현 · ai-nativeness 모드
           4-report.md        제출문서 · 발표덱 · 대본
assets/plan.template.md       15섹션 기획안 골격
       STATE.template.md
       inquiry-template.md    주최·운영사 문의 템플릿 (요강에 없는 항목용)
       rubrics/*.md           유형별 루브릭 프리셋 5종
examples/sample-contest/      가상 공모전 1건의 형식 예시
scripts/check-docs.sh         문서 정합성 검사
```

단계에 진입할 때 해당 reference만 읽는다(progressive disclosure). SKILL.md는 라우팅과 규약만 담는다.

## 문서 정합성 검사

파일 여러 개가 서로를 참조하는 구조라 한쪽만 고쳐서 생기는 모순이 반복해서 나왔다. 사람 눈으로는 계속 놓쳐서 기계로 잡는다.

```bash
bash scripts/check-docs.sh
```

검사 항목 — frontmatter 필수 키, `§n` 교차참조 유효성(파일·절 단위), 참조한 파일의 존재, 4단계와 루브릭 프리셋 연결, 과거에 실제로 났던 모순 패턴의 재발, 공개본 유출 표현(`--public`).

`§n` 표기 규약: 같은 파일의 절을 가리킨다. 다른 파일이면 `plan.md §12`처럼 파일명을 앞에 붙인다. 이 규약을 깨면 검사기가 잡는다.

`examples/sample-contest/`는 산출물이 어떤 모양이어야 하는지 보여주는 가상 사례다. 배점이 `rubric.md`와 일치하는지, 주최사 적합도가 점수에 섞이지 않았는지, 견적서의 약점 항목이 채워졌는지를 눈으로 확인하는 기준선으로 쓴다.

## 루브릭 프리셋에 대하여

`assets/rubrics/`의 배점은 **추정치**다. 국내 공모전에서 통용되는 형태를 정리한 것이며, 요강에 심사기준이 명시되어 있으면 그것이 우선이다. 프리셋에서 가져온 항목은 산출물에 `출처=프리셋(추정)`으로 표시된다.

## 라이선스

MIT
