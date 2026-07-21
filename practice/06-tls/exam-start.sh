#!/usr/bin/env bash
# 시험 방식 실습 시작 (6강 TLS + Ingress)
#   1) 클러스터를 문제 초기 상태로 되돌리고
#   2) work/ 에 작업용 YAML 을 만든다 (원본 setup.yaml / problem-3.yaml 은 보존)
#
# 6강 문제 유형:
#   q1 [CLI]  TLS Secret 생성        → 파일 아님. openssl + kubectl create secret tls
#   q2 [수정] Ingress 에 TLS 추가    → work/q2-shop-ingress.yaml 제공
#   q3 [CLI]  지정된 이름으로 Secret → 파일 아님. 이름 확인 후 create secret tls
set -u
cd "$(dirname "$0")"
# ── 힌트 게이트 ────────────────────────────────────────────────
# 기본은 힌트 없이 생성한다. 실제 시험도 필드 목록을 알려주지 않으므로,
# 스스로 떠올리는 연습(recall)이 되도록 하기 위함이다.
# 막히면:  ./exam-start.sh --hints   (힌트를 넣어 다시 생성)
HINTS=0
[ "${1:-}" = "--hints" ] && HINTS=1
hint() { [ "$HINTS" = "1" ] && printf '%s\n' "$@"; return 0; }

extract() { # $1=파일 $2=kind [$3=name]
  awk -v k="$2" -v n="${3:-}" 'BEGIN{RS="---"}
    $0 ~ ("(^|\n)kind: " k "\n") {
      if (n=="" || $0 ~ ("(^|\n)  name: " n "\n")) { print "---"; print }
    }' "$1"
}

echo "==> 0. ingress-nginx 컨트롤러 확인"
if ! kubectl get ns ingress-nginx >/dev/null 2>&1; then
  echo "   ❌ ingress-nginx 가 없습니다. 먼저 ./setup-ingress-nginx.sh 를 실행하세요."
  exit 1
fi
echo "   OK"

echo "==> 1. 클러스터를 문제 초기 상태로 초기화"
# 학생이 만든 Secret 제거 (없어야 문제가 성립)
kubectl delete secret shop-tls -n tls-ex  --ignore-not-found >/dev/null 2>&1
kubectl delete secret api-tls  -n tls-ex2 --ignore-not-found >/dev/null 2>&1
# Ingress 는 tls 블록/어노테이션이 붙었을 수 있으니 지우고 다시 만든다
kubectl delete ingress shop -n tls-ex  --ignore-not-found >/dev/null 2>&1
kubectl delete ingress api  -n tls-ex2 --ignore-not-found >/dev/null 2>&1
kubectl apply -f setup.yaml    >/dev/null
kubectl apply -f problem-3.yaml >/dev/null
kubectl wait --for=condition=Ready pod -l app=shop -n tls-ex  --timeout=90s >/dev/null 2>&1
kubectl wait --for=condition=Ready pod -l app=api  -n tls-ex2 --timeout=90s >/dev/null 2>&1
echo "   tls-ex(shop, HTTP 전용) / tls-ex2(api, secretName 만 지정됨) 재생성됨"

echo "==> 2. work/ 에 작업용 매니페스트 생성"
mkdir -p work
{ echo "# ============================================================"
  echo "# CKS 6강 실습 (시험 방식) — 문제 2  [수정]"
  echo "# ns tls-ex / ingress shop — TLS 를 적용하고 HTTP→HTTPS 를 강제하라"
  echo "#"
  echo "# 해야 할 것: ① shop.example.com 으로 HTTPS 접속이 되게 하라"
  echo "#             ② HTTP 로 들어오면 HTTPS 로 강제 리다이렉트되게 하라"
  hint "# 힌트: nginx.ingress.kubernetes.io/ssl-redirect: \"true\""
  hint "#       (Cilium Ingress 문제라면 ingress.cilium.io/force-https: \"enabled\")"
  hint "#"
  echo "# 적용:   kubectl apply -f work/q2-shop-ingress.yaml"
  echo "# 초기화: ./exam-start.sh"
  [ "$HINTS" = "1" ] || echo "# 막히면: ./exam-start.sh --hints  ·  정답: solutions/"
  echo "# ⚠️ 문제 1(shop-tls Secret 생성)을 먼저 풀어야 TLS 가 실제로 동작합니다."
  echo "# ============================================================"
  extract setup.yaml Ingress shop
} > work/q2-shop-ingress.yaml
echo "   work/q2-shop-ingress.yaml   [수정]"

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
HTTPS_PORT=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null)

echo ""
echo "※ 문제 1·3 은 [CLI] 유형이라 work 파일이 없습니다. 명령으로 Secret 을 만드는 게 문제입니다:"
echo "    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \\"
echo "      -keyout tls.key -out tls.crt -subj \"/CN=shop.example.com\""
echo "    kubectl create secret tls shop-tls -n tls-ex --cert=tls.crt --key=tls.key"
echo "    kubectl get ingress api -n tls-ex2 -o jsonpath='{.spec.tls[0].secretName}'   # q3: 이름 먼저 확인"
echo ""
echo "테스트용 (VM = NodePort):"
echo "    export NODE_IP=$NODE_IP HTTPS_PORT=$HTTPS_PORT"
echo "    curl -vk https://shop.example.com:\$HTTPS_PORT --resolve shop.example.com:\$HTTPS_PORT:\$NODE_IP"
