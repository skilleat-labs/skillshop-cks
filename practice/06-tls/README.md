# 6강 실습 — TLS + Ingress

> ingress-nginx 컨트롤러가 있어야 합니다. `shop.example.com` 은 `/etc/hosts` 에 노드IP로 등록하거나 curl `--resolve` 로 테스트.

```bash
kubectl apply -f start.yaml
```

## 문제 1 — TLS Secret 만들기 · ns `tls-ex`
`shop.example.com` 용 자체 서명 인증서를 만들어 `shop-tls` 라는 TLS Secret 으로 등록하라.

힌트(인증서 생성):
```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout tls.key -out tls.crt -subj "/CN=shop.example.com"
```

검증:
```bash
kubectl get secret shop-tls -n tls-ex -o jsonpath='{.type}'; echo   # kubernetes.io/tls
```

## 문제 2 — Ingress 에 TLS + HTTPS 강제 · ns `tls-ex`, ingress `shop`
HTTP 만 받던 `shop` Ingress 에 다음을 추가하라.
- `shop-tls` 를 이용한 TLS (`spec.tls`, host `shop.example.com`)
- HTTP→HTTPS 자동 리다이렉트 (`nginx.ingress.kubernetes.io/ssl-redirect: "true"`)

검증:
```bash
curl -vk https://shop.example.com --resolve shop.example.com:443:<노드IP>   # TLS handshake 보이면 성공
```

## 정리
```bash
kubectl delete -f start.yaml
kubectl delete secret shop-tls -n tls-ex 2>/dev/null
```
