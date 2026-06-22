# 6강 실습 — TLS + Ingress

> ingress-nginx 컨트롤러 필요. 두 문제는 같은 환경(`setup.yaml`)을 씁니다.

```bash
kubectl apply -f setup.yaml
```

## 문제 1 — TLS Secret 만들기 · ns `tls-ex`
`shop.example.com` 자체 서명 인증서를 만들어 `shop-tls` TLS Secret 으로 등록.
```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 365 -keyout tls.key -out tls.crt -subj "/CN=shop.example.com"
kubectl create secret tls shop-tls -n tls-ex --cert=tls.crt --key=tls.key
kubectl get secret shop-tls -n tls-ex -o jsonpath='{.type}'   # kubernetes.io/tls
```

## 문제 2 — Ingress 에 TLS + HTTPS 강제 · ns `tls-ex`, ingress `shop`
`shop` Ingress 에 TLS(`shop-tls`, host shop.example.com) + ssl-redirect 추가. 정답: `solutions/problem-2.yaml`
```bash
curl -vk https://shop.example.com --resolve shop.example.com:443:<노드IP>
```

## 정리
```bash
kubectl delete -f setup.yaml
kubectl delete secret shop-tls -n tls-ex
```
