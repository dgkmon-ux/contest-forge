#!/usr/bin/env bash
# contest-forge 문서 정합성 검사
#
# 이 스킬은 여러 마크다운 파일이 서로를 참조하는 구조라, 한 파일만 고치고
# 다른 파일을 안 고쳐서 생기는 모순이 반복해서 나왔다. 사람 눈으로는 계속
# 놓치는 종류라 기계로 잡는다.
#
# 사용:
#   bash scripts/check-docs.sh            정합성만 검사
#   bash scripts/check-docs.sh --public   공개 배포용 유출 검사까지 (CI가 이걸 쓴다)
#
# 종료코드 0 = 통과, 1 = 실패

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PUBLIC=0
[ "${1:-}" = "--public" ] && PUBLIC=1

FAIL=0; SEC=0
note()  { printf '      %s\n' "$1"; }
fail()  { printf 'FAIL  %s\n' "$1"; FAIL=1; SEC=1; }
pass()  { printf 'ok    %s\n' "$1"; }
begin() { SEC=0; printf '\n== %s ==\n' "$1"; }
done_ok() { [ "$SEC" -eq 0 ] && pass "$1"; }

MD_FILES=$(find . -name '*.md' -not -path './.git/*' | sort)

# plan.md / STATE.md 는 산출물 이름이고 레포의 실체는 템플릿이다
resolve() {
  case "$(basename "$1")" in
    plan.md)  echo "assets/plan.template.md" ;;
    STATE.md) echo "assets/STATE.template.md" ;;
    *)        echo "$1" ;;
  esac
}

# 레포에 없어도 정상인 이름 — 파이프라인이 실행 중에 만들어내는 산출물
GENERATED='brief|rubric|research|ideas|plan|submission|script|business|video-storyboard|STATE|INDEX|HANDOFF|SESSION-HANDOFF|INTENT|COGNITION|README'

locate() { # 파일명 → 레포 안 실제 경로 (없으면 빈 문자열)
  local n; n=$(basename "$1")
  for d in . references assets assets/rubrics scripts; do
    [ -f "$d/$n" ] && { echo "${d#./}/$n" | sed 's|^\./||; s|^/||'; return; }
  done
  [ -f "$1" ] && { echo "${1#./}"; return; }
  echo ""
}

# ---------------------------------------------------------------- 1
begin "frontmatter"
if head -1 SKILL.md | grep -q '^---$'; then
  for key in name description; do
    awk 'NR>1 && /^---$/{exit} NR>1' SKILL.md | grep -q "^$key:" \
      || fail "SKILL.md: frontmatter에 $key 없음"
  done
else
  fail "SKILL.md: frontmatter 없음"
fi
done_ok "frontmatter 정상"

# ---------------------------------------------------------------- 2
# 규약: 한 줄 안에서 §n 앞에 가장 가까운 <파일>.md 가 대상이다.
#       앞에 파일명이 없으면 자기 파일의 절을 가리킨다.
begin "섹션 참조"

INDEX=$(mktemp); REFS=$(mktemp)
trap 'rm -f "$INDEX" "$REFS"' EXIT

for f in $MD_FILES; do
  base=${f#./}
  grep -oE '^#{2,3} [0-9]+(\.[0-9]+)?[.[:space:]]' "$f" 2>/dev/null \
    | grep -oE '[0-9]+(\.[0-9]+)?' \
    | sed "s|^|$base\t|" >> "$INDEX"
done

for f in $MD_FILES; do
  base=${f#./}
  awk -v self="$base" '
    { cur=self; rest=$0
      while (match(rest, /[A-Za-z0-9._\/-]+\.md|§[0-9]+(\.[0-9]+)?/)) {
        tok = substr(rest, RSTART, RLENGTH)
        if (tok ~ /^§/) { sub(/^§/, "", tok); print self "\t" FNR "\t" cur "\t" tok }
        else            { cur = tok }
        rest = substr(rest, RSTART + RLENGTH)
      }
    }' "$f" >> "$REFS"
done

REF_N=$(wc -l < "$REFS" | tr -d ' ')
while IFS=$'\t' read -r src line target sec; do
  [ -z "${sec:-}" ] && continue
  path=$(locate "$(resolve "$target")")
  if [ -z "$path" ]; then
    fail "$src:$line — §$sec 의 대상 '$target' 이 레포에 없음"
    continue
  fi
  awk -F'\t' -v f="$path" -v s="$sec" '$1==f && $2==s {ok=1} END{exit !ok}' "$INDEX" \
    || fail "$src:$line — $path 에 §$sec 절이 없음"
done < "$REFS"
done_ok "섹션 참조 ${REF_N}건 모두 유효"

# ---------------------------------------------------------------- 3
begin "파일 참조"
MISS=$(mktemp)
for f in $MD_FILES; do
  base=${f#./}
  grep -oE '`[A-Za-z0-9._/-]+\.md`' "$f" 2>/dev/null | tr -d '`' | sort -u | while read -r ref; do
    basename "$ref" .md | grep -qE "^($GENERATED)$" && continue
    [ -n "$(locate "$(resolve "$ref")")" ] || echo "$base|$ref" >> "$MISS"
  done
done
if [ -s "$MISS" ]; then
  while IFS='|' read -r src ref; do fail "$src — 참조한 '$ref' 가 레포에 없음"; done < "$MISS"
fi
rm -f "$MISS"
done_ok "파일 참조 전부 존재"

# ---------------------------------------------------------------- 4
begin "단계·루브릭 연결"
for n in 1-recon 2-ideate 3-mvp 4-report; do
  [ -f "references/$n.md" ] || fail "references/$n.md 없음"
  grep -q "$n" SKILL.md     || fail "SKILL.md 가 references/$n.md 를 참조하지 않음"
done
for r in assets/rubrics/*.md; do
  name=$(basename "$r" .md)
  grep -q "$name" SKILL.md || fail "SKILL.md 유형 표에 '$name' 프리셋이 없음"
done
done_ok "4단계 + 루브릭 $(ls assets/rubrics/*.md | wc -l | tr -d ' ')종 연결됨"

# ---------------------------------------------------------------- 5
# 과거에 실제로 났던 모순. 다시 들어오면 잡는다.
begin "회귀 방지"
guard() {
  local hits; hits=$(grep -rn "$1" --include='*.md' . 2>/dev/null | grep -v '^\./scripts/')
  [ -z "$hits" ] && return
  fail "$2"
  printf '%s\n' "$hits" | while read -r l; do note "$l"; done
}
guard 'mvp/verification\.log'     "verification.log 는 제출 레포 루트다 (경로 불일치 재발)"
guard '①recon·②ideate를 건너뛰고' "ai-nativeness 는 ②만 건너뛴다 (①은 경량 수행)"
guard '`HANDOFF\.md` — 소통'      "소통 축 문서는 SESSION-HANDOFF.md (이름 충돌 재발)"
guard '§7 위임'                   "위임 절차는 3-mvp.md §3 이다 (깨진 참조 재발)"
done_ok "알려진 모순 패턴 없음"

# ---------------------------------------------------------------- 6
if [ "$PUBLIC" -eq 1 ]; then
  begin "유출 검사 (공개 배포본)"
  hits=$(grep -rnE '코파톤|크래프톤|cofathon|Krafton|TrustGate|실측' --include='*.md' . 2>/dev/null \
         | grep -v '^\./scripts/')
  if [ -n "$hits" ]; then
    fail "공개본에 남으면 안 되는 표현"
    printf '%s\n' "$hits" | while read -r l; do note "$l"; done
  fi
  done_ok "유출 없음"
else
  printf '\n== 유출 검사 ==\nskip  --public 을 붙이면 검사한다 (로컬본은 실측 원본을 의도적으로 보유)\n'
fi

echo
[ "$FAIL" -eq 0 ] && echo "PASS" || echo "FAILED"
exit "$FAIL"
