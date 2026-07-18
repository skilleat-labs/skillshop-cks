# q3 정답 — TLS Ingress (Secret + tls 블록 + ssl-redirect)

## 1) 자체서명 인증서로 TLS Secret 생성
```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout /tmp/m1.key -out /tmp/m1.crt -subj "/CN=shop.m1.example.com"
kubectl create secret tls shop-tls -n m1-tls --cert=/tmp/m1.crt --key=/tmp/m1.key
```

## 2) Ingress 에 tls 블록 + ssl-redirect 어노테이션 추가
`kubectl edit ingress shop -n m1-tls` 로 아래처럼 수정 (또는 아래 YAML apply):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop
  namespace: m1-tls
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"   # HTTP→HTTPS 강제
spec:
  ingressClassName: nginx
  tls:
    - hosts: ["shop.m1.example.com"]
      secretName: shop-tls
  rules:
    - host: shop.m1.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: shop
                port:
                  number: 80
```

## 3) 검증 (VM = NodePort 환경)
```bash
export NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
export HTTPS_PORT=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
curl -vk https://shop.m1.example.com:$HTTPS_PORT --resolve shop.m1.example.com:$HTTPS_PORT:$NODE_IP
# TLS handshake 가 우리 인증서(CN=shop.m1.example.com)로 이뤄지면 성공
```

> **함정(노션):** `ssl-redirect` 어노테이션은 "Kubernetes Ingress Support" 문서의 어노테이션 표에 있다.
> Cilium Ingress 를 쓰는 문제라면 `ingress.cilium.io/force-https: "enabled"` 를 쓴다. 여기선 ingress-nginx 라 nginx 어노테이션.
