# 문제 3 정답 — 제공된 인증서로 지정된 이름(api-tls)의 TLS Secret 생성

인증서/키는 이미 `/tmp/api-tls/` 에 준비돼 있다(문제 1처럼 직접 만드는 게 아니다). Ingress 는 **건드리지 않는다.** `secretName: api-tls` 가 이미 박혀 있으니, **그 이름 그대로** 주어진 파일로 Secret 만 만들면 TLS 가 살아난다.

```bash
# 주어진 파일 확인
ls /tmp/api-tls/          # tls.crt  tls.key

# 그 파일로 Secret 생성 (이름 정확히 api-tls)
kubectl create secret tls api-tls -n tls-ex2 \
  --cert=/tmp/api-tls/tls.crt --key=/tmp/api-tls/tls.key
```

확인:
```bash
kubectl get secret api-tls -n tls-ex2 -o jsonpath='{.type}'   # kubernetes.io/tls
curl -vk https://api.example.com --resolve api.example.com:443:<노드IP>   # 우리 인증서로 handshake
```

> 함정: ① Secret 이름 오타(반드시 api-tls) ② 인증서 CN ≠ tls.hosts/호스트면 인증서 에러 ③ Secret 은 Ingress 와 같은 네임스페이스(tls-ex2)에.
