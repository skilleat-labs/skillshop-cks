#!/usr/bin/env bash
# ============================================================
# CKS 도구 일괄 설치 스크립트
#   시험장(Ubuntu 터미널)과 최대한 동일한 도구 세트를 한 번에 깐다.
#   설치 대상: trivy / bom / kubesec / cosign / kube-bench
#
#   - macOS(Apple Silicon·Intel) 와 Linux(amd64·arm64) 모두 지원
#   - 이미 설치돼 있으면 건너뜀 (--force 로 재설치)
#   - 관리자 권한이 필요한 건 sudo 로만 (그 외엔 sudo 안 씀)
#
#   사용법:
#     ./install-cks-tools.sh            # 없는 것만 설치
#     ./install-cks-tools.sh --force    # 있어도 다시 설치
#     ./install-cks-tools.sh trivy bom  # 지정한 것만 설치
#
#   ⚠️ kube-bench 는 "노드"에서 실행해야 의미가 있는 도구다.
#      Mac 에 깔아도 노드 검사는 못 한다 → 클러스터 Job 으로 돌려라:
#         bash run-kube-bench.sh          (같은 폴더에 있음)
# ============================================================
set -u

# ---- 옵션 파싱 ------------------------------------------------
FORCE=0
WANT=()
for a in "$@"; do
  case "$a" in
    --force) FORCE=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) WANT+=("$a") ;;
  esac
done
# 지정 없으면 전체
if [ ${#WANT[@]} -eq 0 ]; then
  WANT=(trivy bom kubesec cosign kube-bench)
fi

# ---- OS / ARCH 판별 ------------------------------------------
OS="$(uname -s)"; ARCH="$(uname -m)"
case "$OS" in
  Darwin) GOOS=darwin ;;
  Linux)  GOOS=linux ;;
  *) echo "지원하지 않는 OS: $OS"; exit 1 ;;
esac
case "$ARCH" in
  x86_64|amd64) GOARCH=amd64 ;;
  arm64|aarch64) GOARCH=arm64 ;;
  *) echo "지원하지 않는 ARCH: $ARCH"; exit 1 ;;
esac

# 설치 위치: 쓰기 가능한 곳 우선
if [ -w /usr/local/bin ]; then BIN=/usr/local/bin
elif [ -d "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then BIN="$HOME/.local/bin"
else BIN=/usr/local/bin; fi
HAS_BREW=0; command -v brew >/dev/null 2>&1 && HAS_BREW=1

echo "==> OS=$GOOS ARCH=$GOARCH  설치경로=$BIN  brew=$([ $HAS_BREW = 1 ] && echo yes || echo no)"
case ":$PATH:" in *":$BIN:"*) : ;; *) echo "   ⚠️  $BIN 가 PATH 에 없다. 쉘 설정에 추가해라: export PATH=\"$BIN:\$PATH\"";; esac
echo ""

# ---- 헬퍼 ----------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }
skip() { [ $FORCE -eq 0 ] && have "$1"; }
tmpd() { mktemp -d 2>/dev/null || mktemp -d -t cks; }

# GitHub 최신 태그 조회 (실패 시 fallback 인자 반환)
latest_tag() { # $1=owner/repo  $2=fallback
  local t
  t="$(curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
       | grep '"tag_name"' | head -1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
  [ -n "$t" ] && echo "$t" || echo "$2"
}

install_bin() { # $1=이름  $2=url(tar.gz 또는 raw binary)  $3=tar안의바이너리경로(옵션)
  local name="$1" url="$2" inner="${3:-}" d; d="$(tmpd)"
  echo "   ↓ $url"
  if [[ "$url" == *.tar.gz || "$url" == *.tgz ]]; then
    curl -fsSL "$url" -o "$d/a.tgz" || { echo "   ✗ 다운로드 실패"; return 1; }
    tar -xzf "$d/a.tgz" -C "$d" || { echo "   ✗ 압축해제 실패"; return 1; }
    local src="$d/${inner:-$name}"
    [ -f "$src" ] || src="$(find "$d" -type f -name "$name" | head -1)"
    [ -f "$src" ] || { echo "   ✗ 바이너리 못 찾음"; return 1; }
    install_to "$name" "$src"
  else
    curl -fsSL "$url" -o "$d/$name" || { echo "   ✗ 다운로드 실패"; return 1; }
    install_to "$name" "$d/$name"
  fi
}

install_to() { # $1=이름 $2=소스경로
  chmod +x "$2"
  if [ -w "$BIN" ]; then mv "$2" "$BIN/$1"
  else sudo mv "$2" "$BIN/$1"; fi
  echo "   ✓ $BIN/$1"
}

# ============================================================
# trivy — CVE 스캐너
# ============================================================
inst_trivy() {
  if skip trivy; then echo "== trivy: 이미 있음 ($(trivy --version 2>/dev/null | head -1))"; return; fi
  echo "== trivy 설치"
  if [ $HAS_BREW = 1 ]; then brew install trivy && return; fi
  # 공식 설치 스크립트
  curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b "$BIN" \
    && return
  echo "   ✗ trivy 설치 실패"
}

# ============================================================
# bom — SPDX SBOM 생성기 (kubernetes-sigs/bom)
# ============================================================
inst_bom() {
  if skip bom; then echo "== bom: 이미 있음 ($(bom version 2>/dev/null | head -1))"; return; fi
  echo "== bom 설치"
  if [ $HAS_BREW = 1 ]; then brew install bom && return; fi
  local tag; tag="$(latest_tag kubernetes-sigs/bom v0.7.1)"
  # ⚠️ bom 릴리스 파일명은 arch-os 순서다: bom-amd64-linux / bom-arm64-linux
  install_bin bom "https://github.com/kubernetes-sigs/bom/releases/download/${tag}/bom-${GOARCH}-${GOOS}" \
    || echo "   ✗ bom 설치 실패 (go install sigs.k8s.io/bom/cmd/bom@latest 로 대체 가능)"
}

# ============================================================
# kubesec — 매니페스트 보안 점수 스캐너 (controlplaneio/kubesec)
# ============================================================
inst_kubesec() {
  if skip kubesec; then echo "== kubesec: 이미 있음 ($(kubesec version 2>/dev/null | head -1))"; return; fi
  echo "== kubesec 설치"
  local tag; tag="$(latest_tag controlplaneio/kubesec v2.14.2)"
  install_bin kubesec \
    "https://github.com/controlplaneio/kubesec/releases/download/${tag}/kubesec_${GOOS}_${GOARCH}.tar.gz" kubesec \
    || echo "   ✗ kubesec 설치 실패"
}

# ============================================================
# cosign — 이미지 서명/검증 (sigstore/cosign)
# ============================================================
inst_cosign() {
  if skip cosign; then echo "== cosign: 이미 있음 ($(cosign version 2>/dev/null | grep -i version | head -1))"; return; fi
  echo "== cosign 설치"
  if [ $HAS_BREW = 1 ]; then brew install cosign && return; fi
  local tag; tag="$(latest_tag sigstore/cosign v2.4.1)"
  install_bin cosign "https://github.com/sigstore/cosign/releases/download/${tag}/cosign-${GOOS}-${GOARCH}" \
    || echo "   ✗ cosign 설치 실패"
}

# ============================================================
# kube-bench — CIS 벤치마크 (aquasecurity/kube-bench)
#   ※ 노드에서 실행해야 의미 있음. Mac 설치는 "돌아만 가는" 수준.
# ============================================================
inst_kube_bench() {
  if skip kube-bench; then echo "== kube-bench: 이미 있음 ($(kube-bench version 2>/dev/null | head -1))"; return; fi
  echo "== kube-bench 설치"
  if [ "$GOOS" = darwin ]; then
    echo "   ℹ️  kube-bench 는 노드 검사 도구다. Mac 엔 참고용으로만 깐다."
    echo "      실제 검사는 클러스터 Job 으로:  bash run-kube-bench.sh"
    if [ $HAS_BREW = 1 ]; then brew install kube-bench && return; fi
  fi
  local tag ver; tag="$(latest_tag aquasecurity/kube-bench v0.10.7)"; ver="${tag#v}"
  install_bin kube-bench \
    "https://github.com/aquasecurity/kube-bench/releases/download/${tag}/kube-bench_${ver}_${GOOS}_${GOARCH}.tar.gz" kube-bench \
    || echo "   ✗ kube-bench 설치 실패"
}

# ---- 실행 ----------------------------------------------------
for t in "${WANT[@]}"; do
  case "$t" in
    trivy)      inst_trivy ;;
    bom)        inst_bom ;;
    kubesec)    inst_kubesec ;;
    cosign)     inst_cosign ;;
    kube-bench) inst_kube_bench ;;
    *) echo "== 알 수 없는 도구: $t (지원: trivy bom kubesec cosign kube-bench)" ;;
  esac
  echo ""
done

# ---- 요약 ----------------------------------------------------
echo "==================== 설치 결과 ===================="
printf "%-12s %s\n" "trivy"      "$(have trivy      && trivy --version 2>/dev/null | head -1      || echo '없음')"
printf "%-12s %s\n" "bom"        "$(have bom        && bom version 2>/dev/null | head -1          || echo '없음')"
printf "%-12s %s\n" "kubesec"    "$(have kubesec    && kubesec version 2>/dev/null | head -1      || echo '없음')"
printf "%-12s %s\n" "cosign"     "$(have cosign     && cosign version 2>/dev/null | grep -i 'gitversion\|^v' | head -1 || echo '설치됨')"
printf "%-12s %s\n" "kube-bench" "$(have kube-bench && kube-bench version 2>/dev/null | head -1  || echo '없음(노드에서 Job 으로 실행)')"
echo "==================================================="
echo "다음: trivy 첫 실행 시 CVE DB(수백MB) 내려받는다 → 미리:  trivy image --download-db-only"
echo "      kube-bench 는 노드 검사이므로:  bash run-kube-bench.sh"
