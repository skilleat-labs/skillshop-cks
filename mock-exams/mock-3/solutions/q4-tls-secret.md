# q4 정답 — 참조된 secretName(api-tls)에 맞춰 TLS Secret 생성

## 1) 참조 이름 먼저 확인 (함정 방지)
```bash
kubectl get ingress api -n m3-tls -o jsonpath='{.spec.tls[0].secretName}'; echo   # api-tls
```

## 2) 정확히 같은 이름으로 TLS Secret 생성
```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout /tmp/m3.key -out /tmp/m3.crt -subj "/CN=api.m3.example.com"
kubectl create secret tls api-tls -n m3-tls --cert=/tmp/m3.crt --key=/tmp/m3.key
```

## 검증
```bash
kubectl get secret api-tls -n m3-tls -o jsonpath='{.type}'; echo    # kubernetes.io/tls
export NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
export HTTPS_PORT=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
curl -vk https://api.m3.example.com:$HTTPS_PORT --resolve api.m3.example.com:$HTTPS_PORT:$NODE_IP
# 우리 인증서(CN=api.m3.example.com)로 handshake 되면 성공 (기본 fake 인증서 아님)
```

> **함정:** Ingress 는 수정하지 않는다. Secret **이름을 정확히 api-tls** 로 맞추는 게 포인트.
