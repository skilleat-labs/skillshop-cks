# 문제 4 정답 — Cilium SNI 기반 egress TLS 필터링

## 무엇을 하는 문제인가
표준 NetworkPolicy 는 **IP·포트**까지만 통제한다. 그래서 `443` 을 열면 그 포트로 나가는
**모든 HTTPS** 가 통과한다 — 어느 사이트든.

Cilium 은 L7 프록시(Envoy)로 **TLS ClientHello 의 SNI**(접속하려는 호스트명)를 들여다볼 수 있어서,
"HTTPS 는 `allowed.example.com` 으로 가는 것만 허용, 나머지는 차단" 처럼 **호스트명 단위**로 통제한다.
암호를 풀지 않고 SNI 만 보므로 서버 인증서를 다룰 필요가 없다.

## 정답
`solutions/problem-4.yaml` 참고. 핵심은 egress `toPorts` 아래 **`serverNames`**:
```yaml
      toPorts:
        - ports:
            - { port: "443", protocol: TCP }
          serverNames:
            - "allowed.example.com"     # 이 SNI 만 허용 (prefix 와일드카드 가능)
```
> `kubectl explain ciliumnetworkpolicy.spec.egress.toPorts.serverNames` 로 확인 가능.

## 검증
```bash
SRV=$(kubectl get svc httpsvc -n tls-egress -o jsonpath='{.spec.clusterIP}')

# 허용된 SNI → 200
kubectl exec -n tls-egress deploy/client -- \
  curl -sk -o /dev/null -w "%{http_code}\n" --max-time 8 \
  https://allowed.example.com/ --resolve allowed.example.com:443:$SRV

# 다른 SNI → TLS 핸드셰이크 거부 (curl exit 35)
kubectl exec -n tls-egress deploy/client -- \
  curl -sk --max-time 8 https://blocked.example.com/ --resolve blocked.example.com:443:$SRV
```

## 함정 / 포인트
- **DNS 를 안 열면** egress 전체가 막혀 이름 해석부터 죽는다. DNS(53) 규칙을 꼭 같이.
- `serverNames` 는 **SNI 만** 본다. 같은 서버 IP 라도 SNI 가 다르면 차단된다(위 예시가 그렇다).
- 표준 NetworkPolicy 로는 이게 불가능하다 — 이게 "Cilium 이 TLS 로 하는 것"의 핵심.
- 실무: 이걸로 "우리 파드는 승인된 외부 도메인으로만 HTTPS 가능" 같은 egress 화이트리스트를 만든다.
