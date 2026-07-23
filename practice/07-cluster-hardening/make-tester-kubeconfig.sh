#!/usr/bin/env bash
# 문제 4용 — 테스트 신원 'tester' 의 kubeconfig 를 만든다.
# 클러스터 CA 에 CSR API 로 서명받으므로 SSH·CA 키 접근이 필요 없다.
# 결과: /tmp/tester.kubeconfig  (CN=tester, RBAC 는 아직 없음 = 아무 권한 없음)
set -u
OUT=/tmp/tester.kubeconfig
D=$(mktemp -d)

echo "==> 1. 키 + CSR 생성 (CN=tester)"
openssl genrsa -out "$D/tester.key" 2048 >/dev/null 2>&1
openssl req -new -key "$D/tester.key" -out "$D/tester.csr" -subj "/CN=tester/O=cks-test" >/dev/null 2>&1

echo "==> 2. 쿠버네티스 CSR 제출 + 승인"
kubectl delete csr tester --ignore-not-found >/dev/null 2>&1
cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata: { name: tester }
spec:
  request: $(base64 -w0 < "$D/tester.csr" 2>/dev/null || base64 < "$D/tester.csr" | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages: ["client auth"]
  expirationSeconds: 86400
EOF
kubectl certificate approve tester >/dev/null
# 인증서가 발급될 때까지 잠깐 대기
for i in 1 2 3 4 5; do
  CERT=$(kubectl get csr tester -o jsonpath='{.status.certificate}' 2>/dev/null)
  [ -n "$CERT" ] && break; sleep 1
done
[ -z "$CERT" ] && { echo "   ❌ 인증서 발급 실패"; exit 1; }
echo "$CERT" | base64 -d > "$D/tester.crt"

echo "==> 3. kubeconfig 조립 → $OUT"
CA=$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
cat > "$OUT" <<EOF
apiVersion: v1
kind: Config
clusters:
- name: k
  cluster: { server: $SERVER, certificate-authority-data: $CA }
users:
- name: tester
  user:
    client-certificate-data: $(base64 -w0 < "$D/tester.crt" 2>/dev/null || base64 < "$D/tester.crt" | tr -d '\n')
    client-key-data: $(base64 -w0 < "$D/tester.key" 2>/dev/null || base64 < "$D/tester.key" | tr -d '\n')
contexts:
- name: k
  context: { cluster: k, user: tester }
current-context: k
EOF
rm -rf "$D"; kubectl delete csr tester --ignore-not-found >/dev/null 2>&1

echo ""
echo "완료. 이 파일이 'tester' 신원이다 (아직 RBAC 없음 = 아무것도 못 함):"
echo "   $OUT"
echo "   kubectl --kubeconfig $OUT auth can-i get pods   # 지금은 no"
