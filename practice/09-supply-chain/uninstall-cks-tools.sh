#!/usr/bin/env bash
# ============================================================
# CKS 도구 원복(제거) 스크립트  — install-cks-tools.sh 의 반대
#   설치했던 도구를 지우고, kube-bench 가 남긴 클러스터 리소스/결과까지 정리한다.
#   설치 방법에 맞춰 제거한다:  brew 로 깔았으면 brew uninstall,
#   바이너리로 깔았으면 그 파일만 삭제 (알려진 bin 경로에서만 → 시스템 파일 안 건드림).
#
#   사용법:
#     ./uninstall-cks-tools.sh              # 5개 도구 + 클러스터 리소스 제거(확인 물음)
#     ./uninstall-cks-tools.sh -y           # 묻지 않고 바로 제거
#     ./uninstall-cks-tools.sh trivy bom    # 지정한 도구만 제거
#     ./uninstall-cks-tools.sh --keep-cluster   # CLI 도구만, 클러스터/결과는 그대로
#
#   ⚠️ kubectl/kubectl config, homebrew 자체, go 등 "우리가 안 깐 것"은 절대 안 지운다.
# ============================================================
set -u

YES=0; KEEP_CLUSTER=0; WANT=()
for a in "$@"; do
  case "$a" in
    -y|--yes) YES=1 ;;
    --keep-cluster) KEEP_CLUSTER=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) WANT+=("$a") ;;
  esac
done
[ ${#WANT[@]} -eq 0 ] && WANT=(trivy bom kubesec cosign kube-bench)

HAS_BREW=0; command -v brew >/dev/null 2>&1 && HAS_BREW=1
# 우리가 바이너리를 깔 수 있는(=지워도 되는) 경로만 화이트리스트
SAFE_DIRS=("/usr/local/bin" "$HOME/.local/bin")

have() { command -v "$1" >/dev/null 2>&1; }

brew_owns() { # $1=formula  → brew 로 설치돼 있으면 0
  [ $HAS_BREW = 1 ] && brew list --formula "$1" >/dev/null 2>&1
}

in_safe_dir() { # $1=경로  → SAFE_DIRS 안이면 0
  local p="$1" d
  for d in "${SAFE_DIRS[@]}"; do [ "$(dirname "$p")" = "$d" ] && return 0; done
  return 1
}

remove_one() { # $1=명령이름  $2=brew포뮬러명(대개 동일)
  local cmd="$1" formula="${2:-$1}"
  if ! have "$cmd" && ! brew_owns "$formula"; then
    echo "   - $cmd: 설치 안 돼 있음(건너뜀)"; return
  fi
  # 1) brew 로 깐 경우
  if brew_owns "$formula"; then
    echo "   · $cmd: brew uninstall $formula"
    brew uninstall "$formula" >/dev/null 2>&1 && echo "     ✓ 제거됨" || echo "     ✗ brew 제거 실패"
    return
  fi
  # 2) 바이너리로 깐 경우 — 경로가 화이트리스트 안일 때만 삭제
  local p; p="$(command -v "$cmd")"
  if in_safe_dir "$p"; then
    echo "   · $cmd: rm $p"
    if [ -w "$p" ] || [ -w "$(dirname "$p")" ]; then rm -f "$p"; else sudo rm -f "$p"; fi
    have "$cmd" && echo "     ✗ 아직 남아있음($(command -v "$cmd")) — PATH 상 다른 사본" || echo "     ✓ 제거됨"
  else
    echo "   ! $cmd: $p — 우리가 깐 경로가 아니라 건드리지 않음(수동 확인). brew/OS 패키지일 수 있음."
  fi
}

echo "==> 제거 대상: ${WANT[*]}"
[ $KEEP_CLUSTER = 0 ] && echo "    + 클러스터 리소스: namespace/kube-bench, 결과 out/"
if [ $YES = 0 ]; then
  printf "진행할까요? [y/N] "; read -r ans; case "$ans" in y|Y) ;; *) echo "취소함."; exit 0 ;; esac
fi
echo ""

echo "== CLI 도구 제거"
for t in "${WANT[@]}"; do
  case "$t" in
    trivy)      remove_one trivy trivy ;;
    bom)        remove_one bom bom ;;
    kubesec)    remove_one kubesec kubesec ;;
    cosign)     remove_one cosign cosign ;;
    kube-bench) remove_one kube-bench kube-bench ;;
    *) echo "   - 알 수 없는 도구: $t" ;;
  esac
done

# 클러스터 정리 (kube-bench Job/네임스페이스 + 로컬 결과 파일)
if [ $KEEP_CLUSTER = 0 ]; then
  echo ""
  echo "== 클러스터/결과 정리"
  if command -v kubectl >/dev/null 2>&1 && kubectl get ns kube-bench >/dev/null 2>&1; then
    kubectl delete ns kube-bench --wait=false >/dev/null 2>&1 && echo "   ✓ namespace/kube-bench 삭제 요청함"
  else
    echo "   - namespace/kube-bench 없음(건너뜀)"
  fi
  if [ -d "$(dirname "$0")/out" ]; then
    rm -rf "$(dirname "$0")/out" && echo "   ✓ out/ (kube-bench 결과) 삭제함"
  fi
fi

# 요약
echo ""
echo "==================== 원복 결과 ===================="
for t in trivy bom kubesec cosign kube-bench; do
  printf "%-12s %s\n" "$t" "$(have "$t" && echo "아직 있음($(command -v "$t"))" || echo "제거됨")"
done
echo "==================================================="
echo "참고: trivy 캐시(CVE DB)는 ~/.cache/trivy 또는 ~/Library/Caches/trivy 에 남을 수 있음."
echo "      완전 삭제:  rm -rf ~/.cache/trivy ~/Library/Caches/trivy"
