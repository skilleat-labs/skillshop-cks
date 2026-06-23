# 문제 3 정답 — 지정된 이름(api-tls)으로 TLS Secret 생성

Ingress 는 **건드리지 않는다.** `secretName: api-tls` 가 이미 박혀 있으니, **그 이름 그대로** Secret 만 만들면 TLS 가 살아난다. 인증서 CN 은 호스트(api.example.com)와 일치해야 한다.

```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout tls.key -out tls.crt -subj "/CN=api.example.com"

kubectl create secret tls api-tls -n tls-ex2 --cert=tls.crt --key=tls.key
```

확인:
```bash
kubectl get secret api-tls -n tls-ex2 -o jsonpath='{.type}'   # kubernetes.io/tls
curl -vk https://api.example.com --resolve api.example.com:443:<노드IP>   # 우리 인증서로 handshake
```

> 함정: ① Secret 이름 오타(반드시 api-tls) ② 인증서 CN ≠ tls.hosts/호스트면 인증서 에러 ③ Secret 은 Ingress 와 같은 네임스페이스(tls-ex2)에.
