#!/usr/bin/env bash
# ============================================================
# Cilium 무거운 부가기능(SPIRE mutual auth + L7 Envoy) 토글 스크립트
#   목적: control-plane 메모리 절약. 실습 때만 켜고, 끝나면 바로 끈다.
#   ⚠️ Cilium 본체(CNI)는 절대 안 건드림 — SPIRE/L7 만 on/off.
#
#   사용법:
#     ./cilium-heavy.sh status         # 지금 뭐가 켜져 있나 + 메모리
#     ./cilium-heavy.sh off            # 실습 끝! SPIRE+L7 끄고 정리 (평소 상태)
#     ./cilium-heavy.sh on             # SPIRE+L7 둘 다 켜기
#     ./cilium-heavy.sh spire on|off   # SPIRE(5강 mutual auth)만
#     ./cilium-heavy.sh l7    on|off   # L7 Envoy(6강 문제4 SNI 등)만
#
#   전제: apiserver 가 살아 있어야 함(kubectl 필요). 죽어 있으면 먼저 복구.
#   설치 방식(helm / cilium CLI / 순수 kubectl)을 자동 감지해서 처리.
# ============================================================
set -u
NS=kube-system

# ── 전제 확인: kubectl 통하나
if ! kubectl version >/dev/null 2>&1 && ! kubectl get --raw='/healthz' >/dev/null 2>&1; then
  echo "✗ apiserver(kubectl)에 접속 불가. 먼저 apiserver 를 살리세요."
  echo "  (노드에서: /etc/kubernetes/manifests/kube-apiserver.yaml 프로브 완화 → crictl 로 확인)"
  exit 1
fi

# ── 설치 방식 감지
HAS_HELM=0; HAS_CILIUM=0
command -v helm   >/dev/null 2>&1 && helm -n $NS list 2>/dev/null | grep -q cilium && HAS_HELM=1
command -v cilium >/dev/null 2>&1 && HAS_CILIUM=1

restart_cilium() {
  echo "   ↻ cilium / operator 재기동"
  kubectl -n $NS rollout restart ds/cilium deploy/cilium-operator >/dev/null 2>&1
}

# ── 설정 반영: helm > cilium CLI > 순수 kubectl(configmap) 순으로 시도
apply_setting() {  # $1=spire on|off  $2=l7 on|off  (빈 값이면 그 항목 유지)
  local spire="$1" l7="$2"
  if [ $HAS_HELM = 1 ]; then
    echo "   방식: Helm (--reuse-values)"
    local args=()
    [ -n "$spire" ] && args+=( --set authentication.mutual.spire.enabled=$([ "$spire" = on ] && echo true || echo false)
                               --set authentication.mutual.spire.install.enabled=$([ "$spire" = on ] && echo true || echo false) )
    [ -n "$l7" ]    && args+=( --set l7Proxy=$([ "$l7" = on ] && echo true || echo false)
                               --set envoy.enabled=$([ "$l7" = on ] && echo true || echo false) )
    helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1
    helm upgrade cilium cilium/cilium -n $NS --reuse-values "${args[@]}" \
      && echo "   ✓ helm 적용" || echo "   ✗ helm 실패(차트/레포 확인)"
  elif [ $HAS_CILIUM = 1 ]; then
    echo "   방식: cilium CLI (config set)"
    [ -n "$spire" ] && cilium config set mesh-auth-mutual-enabled $([ "$spire" = on ] && echo true || echo false) >/dev/null 2>&1
    [ -n "$l7" ]    && cilium config set enable-l7-proxy         $([ "$l7" = on ] && echo true || echo false) >/dev/null 2>&1
    echo "   ✓ cilium config 적용"
  else
    echo "   방식: kubectl (cilium-config ConfigMap 직접 패치)"
    [ -n "$spire" ] && kubectl -n $NS patch cm cilium-config --type merge \
        -p "{\"data\":{\"mesh-auth-mutual-enabled\":\"$([ "$spire" = on ] && echo true || echo false)\"}}" >/dev/null 2>&1
    [ -n "$l7" ]    && kubectl -n $NS patch cm cilium-config --type merge \
        -p "{\"data\":{\"enable-l7-proxy\":\"$([ "$l7" = on ] && echo true || echo false)\"}}" >/dev/null 2>&1
    echo "   ✓ configmap 패치"
  fi
}

# ── off 일 때 잔여 워크로드 정리(메모리 즉시 회수)
cleanup_off() {  # $1=spire  $2=l7  (해당 항목이 off 일 때만)
  [ "$1" = off ] && { kubectl delete ns cilium-spire --ignore-not-found --wait=false >/dev/null 2>&1 && echo "   ✓ cilium-spire 네임스페이스 삭제"; }
  [ "$2" = off ] && { kubectl -n $NS delete ds cilium-envoy --ignore-not-found >/dev/null 2>&1 && echo "   ✓ cilium-envoy DaemonSet 삭제"; }
}

do_toggle() {  # $1=spire on|off|''   $2=l7 on|off|''
  apply_setting "$1" "$2"
  cleanup_off "${1:-keep}" "${2:-keep}"
  restart_cilium
  echo "   완료. 반영까지 20~40초. 확인: ./cilium-heavy.sh status"
}

status() {
  echo "==================== Cilium 부가기능 상태 ===================="
  echo "-- SPIRE (mutual auth) 파드 --"
  kubectl get pods -n cilium-spire 2>/dev/null | grep -vE "No resources|^NAME" | sed 's/^/   /' || true
  kubectl get ns cilium-spire >/dev/null 2>&1 || echo "   (cilium-spire 없음 = SPIRE 꺼짐)"
  echo "-- L7 Envoy --"
  kubectl -n $NS get ds cilium-envoy >/dev/null 2>&1 && echo "   cilium-envoy DaemonSet 있음(L7 켜짐)" || echo "   (cilium-envoy 없음 = 별도 Envoy 꺼짐)"
  echo "-- cilium-config 플래그 --"
  kubectl -n $NS get cm cilium-config -o jsonpath='   enable-l7-proxy={.data.enable-l7-proxy}{"\n"}   mesh-auth-mutual-enabled={.data.mesh-auth-mutual-enabled}{"\n"}' 2>/dev/null || true
  echo "-- 노드 메모리(이 노드) --"
  free -h 2>/dev/null | sed 's/^/   /'
  echo "============================================================="
}

# ── 커맨드 파싱
CMD="${1:-status}"
case "$CMD" in
  status)  status ;;
  off)     echo "==> SPIRE + L7 끄기 (실습 끝, 평소 상태)"; do_toggle off off ;;
  on)      echo "==> SPIRE + L7 켜기";                     do_toggle on  on  ;;
  spire)   sub="${2:-}"; [ "$sub" = on -o "$sub" = off ] || { echo "사용: $0 spire on|off"; exit 1; }
           echo "==> SPIRE $sub"; do_toggle "$sub" "" ;;
  l7)      sub="${2:-}"; [ "$sub" = on -o "$sub" = off ] || { echo "사용: $0 l7 on|off"; exit 1; }
           echo "==> L7 Envoy $sub"; do_toggle "" "$sub" ;;
  -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "알 수 없는 명령: $CMD"; echo "사용: $0 {status|off|on|spire on|off|l7 on|off}"; exit 1 ;;
esac
