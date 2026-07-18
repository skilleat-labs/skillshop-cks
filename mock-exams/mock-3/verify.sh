#!/usr/bin/env bash
# CKS 모의고사 3회차 자동 채점
# q3·q4·q6(scale): 라이브 / q2·q5: [MANUAL] / q1: [SKIP·Istio 필요]
set -u
PASS=0; FAIL=0
ok(){ echo "  ✅ PASS $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ FAIL $1"; FAIL=$((FAIL+1)); }

echo "== q1 · Istio mTLS STRICT =="
echo "  [SKIP] Istio 설치 환경에서만 채점. kubectl get peerauthentication -n m3-istio 로 수동 확인."

echo "== q2 · Secrets 암호화 at rest (노드) =="
echo "  [MANUAL] grep encryption-provider-config /etc/kubernetes/manifests/kube-apiserver.yaml"
echo "           + etcdctl 로 secret 이 k8s:enc:aescbc 프리픽스인지 확인, 기존 secret 재암호화(kubectl replace) 여부"

echo "== q3 · PSS ns 강제 (m3-pss) =="
LBL=$(kubectl get ns m3-pss -o jsonpath='{.metadata.labels}' 2>/dev/null)
echo "$LBL" | grep -q '"pod-security.kubernetes.io/enforce":"restricted"' && ok "enforce=restricted" || ng "enforce=restricted 라벨 없음"
echo "$LBL" | grep -q '"pod-security.kubernetes.io/warn":"restricted"' && ok "warn=restricted" || ng "warn=restricted 라벨 없음"

echo "== q4 · TLS Secret api-tls (m3-tls) =="
kubectl get secret api-tls -n m3-tls -o jsonpath='{.type}' 2>/dev/null | grep -q "kubernetes.io/tls" && ok "api-tls (TLS 타입) 존재" || ng "api-tls TLS Secret 없음"
# Ingress 는 건드리지 않았는지(secretName 유지)
kubectl get ingress api -n m3-tls -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null | grep -q "api-tls" && ok "Ingress secretName=api-tls 유지" || ng "Ingress 가 변경됨"

echo "== q5 · kubelet 하드닝 (노드) =="
echo "  [MANUAL] grep -E 'anonymous|readOnlyPort|mode' /var/lib/kubelet/config.yaml"
echo "           curl -sk https://<노드IP>:10250/pods → Unauthorized"

echo "== q6 · Falco 대응 (suspicious scale 0) =="
REP=$(kubectl get deploy suspicious -n m3-falco -o jsonpath='{.spec.replicas}' 2>/dev/null)
if [ "$REP" = "0" ]; then ok "suspicious replicas=0 (대응 완료)"; else ng "suspicious replicas=$REP (0 으로 스케일 필요)"; fi
echo "  [MANUAL·룰] 노드 /etc/falco/falco_rules.local.yaml 에 /dev/mem 탐지 룰 추가 여부는 journalctl 로 확인"

echo ""
echo "라이브 채점 결과: PASS=$PASS  FAIL=$FAIL  (q1 SKIP, q2·q5 노드 수동)"
