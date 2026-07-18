# CKS 모의고사 1회차 (7문제)

> 실제 시험처럼 여러 도메인이 섞여 있습니다. 제한시간 목표 **90분**. 합격선 감각: 67%+.
> 환경: k8s 1.32 / containerd / Cilium / 3노드. 클러스터 리소스 문제는 `setup.yaml` 로 환경을 만든 뒤 풉니다.

## 준비
```bash
kubectl apply -f setup.yaml      # q1~q4 환경 생성 (q5·q6 노드작업, q7 로컬 CLI 는 별도)
```

## ⚠️ 점수 누수 방지 (매 문제 습관)
- [ ] 문제마다 컨텍스트/네임스페이스 확인 (`kubectl config current-context`, `-n` 정확히)
- [ ] 작업 후 **검증 명령**으로 확인 (검증 생략이 최대 누수)
- [ ] 문제 동사 정확히: **delete vs replace vs scale**
- [ ] 서비스/유닛명 함정 (`falco` ❌ → `falco-modern-bpf` ✅), `getent group <name>` 사용

---

## q1 · Restricted PSS — Deployment 수정 (배점 8) · ns `m1-pss`
네임스페이스 `m1-pss` 는 `enforce=restricted` 라 `web` 파드가 거부되어 뜨지 않는다.
`web` Deployment 를 수정해 **restricted 정책을 만족**시키고 Running 시켜라.
- 힌트: restricted 4대 필드는 `spec.template.spec` 의 pod/container securityContext 에.
- 검증: `kubectl get pods -n m1-pss` → Running

## q2 · NetworkPolicy — deny-all + DNS + 특정 ns 허용 (배점 9) · ns `m1-netpol`
`m1-netpol` 에 다음을 만족하는 NetworkPolicy 를 작성하라.
- 기본은 모든 ingress **차단**(deny-all)
- 단, **`team=trusted` 라벨이 붙은 네임스페이스**(= `m1-netpol-client`)의 Pod 에서 오는 접근은 `db` 로 허용
- Pod 들이 DNS 를 쓸 수 있게 **egress 53(UDP/TCP)** 허용
- 검증:
```bash
kubectl exec -n m1-netpol-client deploy/client -- wget -qO- --timeout=3 http://db.m1-netpol | head -c 20   # 응답
kubectl exec -n m1-netpol       deploy/intruder -- wget -qO- --timeout=3 http://db                          # timeout
```

## q3 · TLS Ingress — ssl-redirect + tls 블록 (배점 8) · ns `m1-tls`, ingress `shop`
`shop` Ingress 는 현재 HTTP 전용이다. 다음을 **직접 추가**하라.
- 자체서명 인증서(CN=`shop.m1.example.com`)로 TLS Secret `shop-tls` 생성
- Ingress 에 `tls` 블록(host `shop.m1.example.com`, secretName `shop-tls`)
- **HTTP→HTTPS 강제** 어노테이션 `nginx.ingress.kubernetes.io/ssl-redirect: "true"`
- 검증: `kubectl get ingress shop -n m1-tls -o yaml` 에 tls + 어노테이션 존재, `kubectl get secret shop-tls -n m1-tls`

## q4 · RBAC — 위험한 ClusterRoleBinding 제거 (배점 7) · ns `m1-rbac`, sa `ci-bot`
`ci-bot` 이 **ClusterRoleBinding** 으로 클러스터 전역 `cluster-admin` 을 갖는다.
시스템 기본 바인딩은 두고, **SA 에 붙은 위험한 바인딩만** 찾아 삭제하라.
```bash
kubectl get clusterrolebindings -o wide | grep cluster-admin     # SA-bound 한 줄 찾기
kubectl auth can-i '*' '*' --as=system:serviceaccount:m1-rbac:ci-bot   # yes → (삭제) → no
```

## q5 · Falco — 컨테이너 셸 실행 탐지 룰 (배점 8) · **노드 작업**
컨테이너 안에서 셸(`sh`/`bash`)이 실행되면 Warning 을 남기는 커스텀 룰을 노드의
`/etc/falco/falco_rules.local.yaml` 에 추가하라. (기본 `falco_rules.yaml` 은 수정 금지)
- **함정:** 서비스명은 `falco` 가 아니라 보통 `falco-modern-bpf`. `systemctl list-units 'falco*'` 로 먼저 확인.
- 정답/검증: `solutions/q5-falco.md`

## q6 · kube-apiserver 익명 접근 차단 (배점 7) · **노드 작업(컨트롤플레인)**
`/etc/kubernetes/manifests/kube-apiserver.yaml` 에:
- `--anonymous-auth=false`
- `--authorization-mode=Node,RBAC`
- `--enable-admission-plugins=...,NodeRestriction`
> ⚠️ **수정 전 백업 필수** (`sudo cp ... ~/kube-apiserver.yaml.bak`). 정답: `solutions/q6-apiserver.md`

## q7 · 이미지 취약점 스캔 (trivy) (배점 7) · **로컬 CLI**
`nginx:1.18` 이미지의 **HIGH·CRITICAL** 취약점을 스캔하고 결과를 `/tmp/m1-scan.json` 에 저장하라.
- **함정:** SBOM 생성(bom)이 아니라 **CVE 스캔(trivy)**. 문제 동사로 구분.
- 정답: `solutions/q7-trivy.md`

---

## 채점 (자동)
```bash
bash verify.sh        # q1~q4 라이브 채점, q5·q6 는 [MANUAL], q7 은 결과파일 확인
```

## 정리
```bash
../reset.sh           # m1-* 네임스페이스 + ClusterRoleBinding 정리
```
