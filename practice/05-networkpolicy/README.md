# 5강 실습 — NetworkPolicy (+ Cilium)

> 표준 NetworkPolicy(문제 1·2)는 정책 강제 CNI(Calico/Cilium) 필요.
> ✅ **이 실습 환경은 Cilium** 이라 표준 NetworkPolicy 를 강제합니다 → 문제 1·2 는 추가 설정 없이 그대로 진행하면 됩니다.
> (확인: `kubectl get pods -n kube-system | grep cilium` 이 Running)
> 문제 3은 **Cilium CNI + mutual authentication 기능(SPIRE)** 이 켜져 있어야 동작.

## 방법 A — 시험 방식 (권장)
```bash
./exam-start.sh                        # 초기화(기존 정책 삭제) + work/ 생성
vim work/q1-netpol.yaml                # 정책을 직접 작성
kubectl apply -f work/q1-netpol.yaml
bash verify.sh                         # 자동 채점(실제 통신 테스트)
```
> `work/` 파일에는 **힌트가 없습니다.** 실제 시험도 필드 목록을 알려주지 않으니, 스스로 떠올리는 연습을 하세요.
> 막히면 `./exam-start.sh --hints` 로 힌트를 넣어 다시 생성하거나, `solutions/` 를 확인하면 됩니다.

5강은 세 문제 모두 **[생성]** 유형이라, `work/` 파일은 요구사항만 적힌 빈 파일로 제공됩니다.
(`q1-netpol.yaml` · `q2-netpol.yaml` · `q3-cnp.yaml`)

> `./exam-start.sh` 는 **기존 정책을 전부 삭제**하고 시작합니다. 앞 문제의 정책이 남아 있으면
> 다음 문제 통신 결과가 오염되기 때문입니다.

## 방법 B — 환경만 올리고 직접 작성
```bash
kubectl apply -f problem-1.yaml
kubectl apply -f problem-2.yaml
kubectl apply -f problem-3.yaml
```

## 문제 1 — 특정 출발지만 허용 · ns `netpol-ex1`
`db` 는 `app=web` 에서 오는 것만 허용, 나머지 차단.
```bash
kubectl exec -n netpol-ex1 deploy/web      -- wget -qO- --timeout=3 http://db | head -c 30   # 응답
kubectl exec -n netpol-ex1 deploy/attacker -- wget -qO- --timeout=3 http://db                # timeout
```

## 문제 2 — deny-all + DNS 허용 · ns `netpol-ex2`
deny-all(Ingress+Egress) 후 DNS(53)만 허용.
```bash
kubectl exec -n netpol-ex2 deploy/tester -- nslookup kubernetes.default.svc.cluster.local   # 해석됨
# ⚠️ 짧은 이름(kubernetes.default)으로 조회하면 busybox nslookup 이 search 도메인을 안 붙여
#    DNS 가 정상인데도 NXDOMAIN 이 뜬다. 반드시 FQDN 으로 확인할 것.
kubectl exec -n netpol-ex2 deploy/tester -- wget -qO- --timeout=3 http://kubernetes.default   # timeout
```

## 문제 3 — Cilium 상호 인증 · ns `cnp-ex`, deploy `target`
(합격자 공유 유형) **CiliumNetworkPolicy** 로 다음을 만족시켜라.
- `cnp-client` 네임스페이스의 Pod 가 `target` Deployment Pod 에 접근 허용
- 그 접근에는 **mutual authentication 필수**
- **호스트(host) 접근은 mutual auth 없이** 허용

> 시험 중 허용 문서: **https://docs.cilium.io** (Network Policy / Mutual Authentication). CKS는 kubernetes.io 외에 Cilium·Falco·Trivy(bom)·etcd·NGINX Ingress 문서 접근이 허용됨.

핵심 3가지: ① `kind: CiliumNetworkPolicy` (일반 NetworkPolicy 아님) ② `authentication.mode: required` ③ `fromEntities: host` (auth 블록 없음). 정답: `solutions/problem-3.yaml`

```bash
kubectl get ciliumnetworkpolicies -n cnp-ex
# cnp-client → target 접근(인증됨) 동작, 그 외 네임스페이스는 차단
kubectl exec -n cnp-client deploy/client -- wget -qO- --timeout=3 http://target.cnp-ex | head -c 30
```
> **전제조건(클러스터당 1회):** mutual auth 는 Cilium SPIRE 기능이 켜져 있어야 동작합니다. 안 켜져 있으면 정책이 `VALID: False`(mutual auth feature is disabled)로 뜨고 트래픽이 막혀요. 아래 스크립트를 **문제 3 실습 전에 한 번** 실행하세요.
> ```bash
> ./setup-mutual-auth.sh   # cilium/helm 으로 SPIRE+mutual auth 활성화 (1회)
> ```
> 확인: `kubectl get ciliumnetworkpolicy -n cnp-ex` 의 VALID 가 True 여야 함.

> 라벨 매칭은 `io.kubernetes.pod.namespace: <네임스페이스명>` (Cilium 예약 라벨, 자동 부여). mutual auth 실제 동작 확인은 클러스터에 Cilium authentication(SPIRE)이 활성화돼 있어야 함.

## 정리
```bash
kubectl delete -f problem-1.yaml -f problem-2.yaml -f problem-3.yaml
```
