#!/usr/bin/env bash
# CKS 모의고사 2회차 자동 채점
# q1: 정책 구조(라이브) / q2·q3: 라이브 / q4·q6·q7: [MANUAL] / q5: 결과파일
set -u
PASS=0; FAIL=0
ok(){ echo "  ✅ PASS $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ FAIL $1"; FAIL=$((FAIL+1)); }

echo "== q1 · Cilium mutual auth (정책 구조) =="
CNP=$(kubectl get cnp target-mutual-auth -n m2-cnp -o json 2>/dev/null)
if [ -n "$CNP" ]; then
  echo "$CNP" | grep -q '"mode": *"required"' && ok "authentication.mode: required 존재" || ng "authentication.mode required 없음"
  echo "$CNP" | grep -q '"host"' && ok "fromEntities: host 존재" || ng "fromEntities host 없음"
  echo "$CNP" | grep -q 'm2-cnp-client' && ok "client ns 셀렉터 존재" || ng "client ns 셀렉터 없음"
  VALID=$(kubectl get cnp target-mutual-auth -n m2-cnp -o jsonpath='{.status.conditions[?(@.type=="Valid")].status}' 2>/dev/null)
  echo "     ℹ️ VALID=$VALID  (False 이면 SPIRE 미활성 — enforcement 는 setup-mutual-auth.sh 필요)"
else
  ng "CiliumNetworkPolicy target-mutual-auth 없음"
fi

echo "== q2 · SecurityContext immutable (m2-sc/worker) =="
kubectl exec -n m2-sc deploy/worker -- id 2>/dev/null | grep -q "uid=30000" && ok "non-root(uid=30000)" || ng "non-root 아님"
kubectl exec -n m2-sc deploy/worker -- touch /x 2>&1 | grep -qi "read-only" && ok "readOnlyRootFilesystem" || ng "루트FS 쓰기가능(readOnly 아님)"

echo "== q3 · SA 토큰 automount off + projected volume (m2-sa) =="
kubectl get sa robot -n m2-sa -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null | grep -q "false" && ok "SA automount=false" || ng "SA automount 미설정"
kubectl get deploy app -n m2-sa -o jsonpath='{.spec.template.spec.automountServiceAccountToken}' 2>/dev/null | grep -q "false" && ok "Pod automount=false" || ng "Pod automount 미설정"
kubectl get deploy app -n m2-sa -o json 2>/dev/null | grep -q "serviceAccountToken" && ok "projected serviceAccountToken 볼륨 존재" || ng "projected 토큰 볼륨 없음"

echo "== q4 · Audit Logging (노드) =="
echo "  [MANUAL] 컨트롤플레인: grep -E 'audit-policy-file|audit-log-path' /etc/kubernetes/manifests/kube-apiserver.yaml"
echo "           sudo tail -1 /var/log/kubernetes/audit.log  (JSON 로그)"

echo "== q5 · bom SBOM (로컬) =="
if [ -s /tmp/m2-sbom.spdx ] && head -1 /tmp/m2-sbom.spdx | grep -qi "SPDX"; then ok "/tmp/m2-sbom.spdx (SPDX) 생성됨"; else echo "  [MANUAL] 아직 생성 안 함: bom generate --image nginx:1.18 --output /tmp/m2-sbom.spdx"; fi

echo "== q6 · 노드 업그레이드 (노드) =="
echo "  [MANUAL] kubectl get nodes  → 대상 노드가 목표 패치버전 & Ready"

echo "== q7 · ImagePolicyWebhook (노드) =="
echo "  [MANUAL] grep -E 'ImagePolicyWebhook|admission-control-config-file' /etc/kubernetes/manifests/kube-apiserver.yaml"

echo ""
echo "라이브 채점 결과: PASS=$PASS  FAIL=$FAIL  (q4·q6·q7 노드 수동, q1 enforcement 는 SPIRE 필요)"
