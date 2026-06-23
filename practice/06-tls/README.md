# 6강 실습 — TLS + Ingress

> ingress-nginx 컨트롤러 필요. 호스트는 `/etc/hosts` 에 노드IP로 등록하거나 `curl --resolve` 로 테스트.
> 시험 중 허용 문서: **https://kubernetes.io/docs** (Ingress TLS), **NGINX Ingress** 문서.

```bash
kubectl apply -f setup.yaml        # 문제 1·2 환경 (shop)
kubectl apply -f problem-3.yaml    # 문제 3 환경 (api)
```

## 문제 1 — TLS Secret 만들기 · ns `tls-ex`
`shop.example.com` 자체 서명 인증서를 만들어 `shop-tls` TLS Secret 으로 등록.
```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 365 -keyout tls.key -out tls.crt -subj "/CN=shop.example.com"
kubectl create secret tls shop-tls -n tls-ex --cert=tls.crt --key=tls.key
kubectl get secret shop-tls -n tls-ex -o jsonpath='{.type}'   # kubernetes.io/tls
```

## 문제 2 — HTTP Ingress 에 TLS 직접 추가 · ns `tls-ex`, ingress `shop`
`shop` Ingress 에 tls 블록(`shop-tls`, host shop.example.com)과 ssl-redirect 어노테이션을 **직접 작성**. 정답: `solutions/problem-2.yaml`
```bash
curl -vk https://shop.example.com --resolve shop.example.com:443:<노드IP>
```

## 문제 3 — 지정된 secretName 에 맞춰 Secret 생성 · ns `tls-ex2`, ingress `api`
(시험 단골) `api` Ingress 에는 이미 `tls.secretName: api-tls` 가 지정돼 있는데 그 Secret 이 없어서 기본(가짜) 인증서가 뜬다.
**Ingress 는 건드리지 말고**, `api-tls` 라는 **정확히 같은 이름**으로 TLS Secret 을 만들어 TLS 를 살려라. (CN = api.example.com) 정답: `solutions/problem-3.md`
```bash
kubectl get ingress api -n tls-ex2 -o jsonpath='{.spec.tls[0].secretName}'; echo   # api-tls (먼저 이름 확인)
kubectl get secret api-tls -n tls-ex2 -o jsonpath='{.type}'                          # kubernetes.io/tls
curl -vk https://api.example.com --resolve api.example.com:443:<노드IP>              # 우리 인증서로 handshake
```

## 정리
```bash
kubectl delete -f setup.yaml -f problem-3.yaml
kubectl delete secret shop-tls -n tls-ex 2>/dev/null
```
