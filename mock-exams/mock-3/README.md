# CKS 모의고사 3회차 (6문제)

> S등급 최우선(Istio mTLS) 포함 회차. 제한시간 목표 **75분**.
> 환경: k8s 1.32 / containerd / Cilium / 3노드.

## 준비
```bash
kubectl apply -f setup.yaml      # q1 앱, q3, q4, q6 환경 생성
```
> ⚠️ **q1(Istio)** 은 클러스터에 Istio 가 설치돼 있어야 검증된다. 미설치 시 `solutions/q1-istio-mtls.md` 의
> `istioctl install` 가이드로 먼저 설치. 이 모의고사의 verify.sh 는 q1 을 **채점하지 않는다**(설치 환경 의존).

## ⚠️ 점수 누수 방지
- [ ] 컨텍스트/네임스페이스  · [ ] 작업 후 검증  · [ ] 동사 정확  · [ ] 노드 수정 전 백업  · [ ] 스코프(mesh 전체 vs ns) 확인

---

## q1 · Istio mTLS — STRICT PeerAuthentication (배점 10) · ns `m3-istio` **[검증 생략·Istio 필요]**
`m3-istio` 의 워크로드 간 통신을 **mTLS STRICT** 로 강제하라. 3단계:
1. 네임스페이스에 **sidecar injection** 라벨(`istio-injection=enabled`)
2. 기존 Pod **`rollout restart`** (사이드카 주입 반영)
3. **`PeerAuthentication`** STRICT 적용
- **함정:** `istio-system` 에 적용하면 mesh 전체 / 특정 ns 에 적용하면 스코프 한정. 문제 지시 범위 확인.
- 정답 + 설치가이드: `solutions/q1-istio-mtls.md`

## q2 · Secrets 암호화 at rest (배점 9) · **노드(컨트롤플레인)**
`EncryptionConfiguration` 으로 etcd 저장 시 secret 을 암호화하라.
- 암호화 설정 파일 작성 → apiserver `--encryption-provider-config` 연결 + hostPath 볼륨
- **기존 secret 재암호화**: `kubectl get secrets -A -o json | kubectl replace -f -`
- ⚠️ 매니페스트 수정 전 백업. 정답: `solutions/q2-secrets-encryption.md`

## q3 · PSS 네임스페이스 강제 (배점 7) · ns `m3-pss`
`m3-pss` 에 **restricted** 를 `enforce` 하고 `warn` 도 켜라.
```bash
kubectl label ns m3-pss \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted
kubectl get ns m3-pss --show-labels
```

## q4 · 참조된 secretName 에 맞춰 TLS Secret 생성 (배점 8) · ns `m3-tls`, ingress `api`
`api` Ingress 에는 이미 `tls.secretName: api-tls` 가 지정돼 있는데 그 Secret 이 없다.
**Ingress 는 건드리지 말고**, `api-tls` 라는 **정확히 같은 이름**으로 TLS Secret 을 만들어라. (CN=`api.m3.example.com`)
```bash
kubectl get ingress api -n m3-tls -o jsonpath='{.spec.tls[0].secretName}'; echo   # 이름 먼저 확인
```
- 정답: `solutions/q4-tls-secret.md`

## q5 · kubelet 하드닝 (배점 8) · **노드(모든/워커)**
`/var/lib/kubelet/config.yaml` 에서:
- `authentication.anonymous.enabled: false`
- `authorization.mode: Webhook`
- `readOnlyPort: 0`
적용 후 `sudo systemctl restart kubelet`. 정답/검증: `solutions/q5-kubelet.md`

## q6 · Falco `/dev/mem` 탐지 + 대응 (배점 8) · **룰=노드, 대응=클러스터** · ns `m3-falco`
1. `/dev/mem` 접근을 탐지하는 커스텀 Falco 룰 작성(노드) → 문제 Pod 식별
2. 악성 워크로드를 멈춰라 — Pod 를 직접 지우지 말고(재생성됨) **Deployment 를 `replicas: 0`** 으로 스케일
```bash
kubectl scale deploy/suspicious -n m3-falco --replicas=0
```
- 정답: `solutions/q6-falco-devmem.md`

---

## 채점
```bash
bash verify.sh        # q3·q4·q6(scale) 라이브, q2·q5 [MANUAL], q1 [SKIP·Istio]
```
## 정리
```bash
../reset.sh
```
