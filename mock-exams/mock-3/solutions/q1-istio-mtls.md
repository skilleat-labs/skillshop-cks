# q1 정답 — Istio mTLS STRICT (검증 생략 · Istio 필요)

## (사전) Istio 설치 — 클러스터에 없을 때 1회
```bash
# istioctl 설치
curl -L https://istio.io/downloadIstio | sh -
cd istio-*/ && export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo -y
kubectl -n istio-system get pods           # istiod 등 Running 확인
```

## 1) 네임스페이스에 sidecar injection 라벨
```bash
kubectl label namespace m3-istio istio-injection=enabled --overwrite
```

## 2) 기존 Pod 에 사이드카 주입 반영 (rollout restart)
```bash
kubectl rollout restart deployment/httpbin -n m3-istio
kubectl get pod -n m3-istio      # READY 2/2 (앱 + istio-proxy) 확인
```

## 3) PeerAuthentication STRICT 적용
```yaml
# 특정 네임스페이스 스코프로 STRICT
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: m3-istio        # ← ns 지정 = 이 네임스페이스만. istio-system 이면 mesh 전체
spec:
  mtls:
    mode: STRICT
```
```bash
kubectl apply -f -   # 위 YAML
```

## 검증
```bash
kubectl get peerauthentication -n m3-istio
# mTLS 강제 확인: sidecar 없는(=평문) 클라이언트에서 접근 시 거부돼야 함
```

> **함정(노션):** ① 라벨만 붙이고 rollout restart 를 안 하면 기존 Pod 에 사이드카가 없어 mTLS 미적용.
> ② 스코프 — `istio-system`(mesh 전체) vs 특정 ns. 문제가 요구하는 범위에 맞춰 metadata.namespace 지정.
