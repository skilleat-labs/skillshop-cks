# 6강 실습 — TLS + Ingress

> ingress-nginx 컨트롤러 필요. 호스트는 `/etc/hosts` 에 노드IP로 등록하거나 `curl --resolve` 로 테스트.
> 시험 중 허용 문서: **https://kubernetes.io/docs** (Ingress TLS), **NGINX Ingress** 문서.

## 사전 준비 — ingress-nginx 컨트롤러 설치 (1회)
컨트롤러가 없으면 문제 1·2·3 모두 테스트가 안 된다. 실습 전 한 번 실행:
```bash
./setup-ingress-nginx.sh
# 또는 수동으로:
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml
```
> VM(baremetal/kubeadm) 클러스터는 컨트롤러가 **NodePort** 로 뜬다. 아래 curl 예시의 `443` 대신
> 스크립트가 출력한 HTTPS NodePort 를 써야 한다. 편의상 아래처럼 변수로 잡아두면 편하다:
```bash
export NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
export HTTPS_PORT=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
echo "$NODE_IP:$HTTPS_PORT"
```

## 방법 A — 시험 방식 (권장)
```bash
./exam-start.sh                          # 초기화(Secret 삭제) + work/ 생성
vim work/q2-shop-ingress.yaml
kubectl apply -f work/q2-shop-ingress.yaml
bash verify.sh                           # 자동 채점(TLS 핸드셰이크 포함)
```
> `work/` 파일에는 **힌트가 없습니다.** 실제 시험도 필드 목록을 알려주지 않으니, 스스로 떠올리는 연습을 하세요.
> 막히면 `./exam-start.sh --hints` 로 힌트를 넣어 다시 생성하거나, `solutions/` 를 확인하면 됩니다.

| 유형 | 문제 | work 파일 |
|------|------|-----------|
| **CLI** | q1(shop-tls 생성), q3(api-tls 생성) | 없음 — `openssl` + `kubectl create secret tls` |
| **수정** | q2(Ingress 에 TLS 추가) | `work/q2-shop-ingress.yaml` |
| **생성** | q4(Cilium SNI egress 필터) | `work/q4-cnp-sni.yaml` |

> `exam-start.sh` 는 ingress-nginx 설치 여부를 먼저 확인하고, 노드IP·HTTPS NodePort 를 출력합니다.
> 문제 3 인증서는 `/tmp/api-tls/`, 문제 4 서버 TLS Secret 은 자동 생성됩니다.

## 방법 B — 환경만 올리기
```bash
kubectl apply -f setup.yaml        # 문제 1·2 환경 (shop)
kubectl apply -f problem-3.yaml    # 문제 3 환경 (api)
kubectl apply -f problem-4.yaml    # 문제 4 환경 (tls-egress) — 서버 Secret 은 exam-start.sh 가 생성
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
# VM(NodePort) 환경: :443 대신 HTTPS NodePort 를 지정
curl -vk https://shop.example.com:$HTTPS_PORT --resolve shop.example.com:$HTTPS_PORT:$NODE_IP
```

## 문제 3 — 제공된 인증서로 지정된 secretName 에 맞춰 Secret 생성 · ns `tls-ex2`, ingress `api`
(시험 단골) `api` Ingress 에는 이미 `tls.secretName: api-tls` 가 지정돼 있는데 그 Secret 이 없어서 기본(가짜) 인증서가 뜬다.
인증서/키는 **`/tmp/api-tls/` 에 미리 준비돼 있다**(문제 1처럼 직접 만들지 않는다).
**Ingress 는 건드리지 말고**, 그 파일로 `api-tls` 라는 **정확히 같은 이름**의 TLS Secret 을 만들어 TLS 를 살려라. 정답: `solutions/problem-3.md`
```bash
ls /tmp/api-tls/                                                                     # tls.crt tls.key (주어진 파일)
kubectl get ingress api -n tls-ex2 -o jsonpath='{.spec.tls[0].secretName}'; echo   # api-tls (먼저 이름 확인)
kubectl get secret api-tls -n tls-ex2 -o jsonpath='{.type}'                          # kubernetes.io/tls
# VM(NodePort) 환경: :443 대신 HTTPS NodePort 를 지정
curl -vk https://api.example.com:$HTTPS_PORT --resolve api.example.com:$HTTPS_PORT:$NODE_IP   # 우리 인증서로 handshake
```

## 문제 4 — Cilium SNI 기반 egress TLS 필터링 · ns `tls-egress`, deploy `client` (CiliumNetworkPolicy)
표준 NetworkPolicy 는 IP·포트까지만 본다. Cilium 은 L7 프록시로 **TLS SNI(접속 호스트명)** 를 검사해
HTTPS 목적지를 **호스트명 단위**로 통제할 수 있다(암호는 안 푼다 — SNI 만).
`client` 파드가 **HTTPS 는 SNI `allowed.example.com` 인 곳만** 나가고, 다른 SNI 는 차단되게 하라(+DNS 허용).
정답: `solutions/problem-4.yaml` · `solutions/problem-4.md`
```bash
SRV=$(kubectl get svc httpsvc -n tls-egress -o jsonpath='{.spec.clusterIP}')
kubectl exec -n tls-egress deploy/client -- curl -sk -m8 -o /dev/null -w '%{http_code}\n' \
  https://allowed.example.com/ --resolve allowed.example.com:443:$SRV   # 허용 → 200
kubectl exec -n tls-egress deploy/client -- curl -sk -m8 \
  https://blocked.example.com/ --resolve blocked.example.com:443:$SRV   # 차단 → curl exit 35
```
> 핵심: `CiliumNetworkPolicy` egress `toPorts.serverNames`. 표준 NetworkPolicy 로는 불가능한, "Cilium 이 TLS 로 하는 것".

## 정리
```bash
kubectl delete -f setup.yaml -f problem-3.yaml -f problem-4.yaml
kubectl delete secret shop-tls -n tls-ex 2>/dev/null
```
> ingress-nginx 컨트롤러는 **안 지웁니다**(다른 실습에서도 쓸 수 있게 남겨둠).
> 완전히 제거하려면: `kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml`
