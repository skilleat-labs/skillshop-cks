# k8s / 00-vulnerable — 1강 "털린 스킬샵" (무방비 배포)

securityContext·NetworkPolicy·TLS를 **일부러 뺀** 취약 버전입니다.
실제로 배포해서 해커 침투(횡적 이동·카드 유출)를 재현하는 용도예요.

## 배포

```bash
kubectl apply -f k8s/00-vulnerable/
kubectl get pods -n skillshop -w     # 전부 Running 될 때까지
```

파일이 번호순(00→60)으로 적용돼 네임스페이스 → Secret → DB → 서비스 → Ingress 순서로 생성됩니다.

> 이미지는 `skilleat/skillshop-*:1.0` 을 당겨옵니다. Docker Hub 저장소가 **public**이어야 별도 설정 없이 pull 됩니다. (private이면 imagePullSecret 필요)
> order-svc·payment-svc는 시작할 때 DB에 붙으므로, DB가 먼저 Ready 되기 전엔 잠깐 CrashLoopBackOff 후 자동 복구됩니다.

## 접속

Ingress를 쓰려면 클러스터에 ingress-nginx 컨트롤러가 있어야 합니다.

```bash
# 컨트롤러가 없다면 (예시)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml
```

그다음 노드 IP를 hosts에 등록:

```bash
echo "<노드_IP> skillshop.local" | sudo tee -a /etc/hosts
# 브라우저: http://skillshop.local
```

가장 간단하게는 포트포워딩으로 바로 확인:

```bash
kubectl port-forward -n skillshop svc/frontend 8080:8080
# http://localhost:8080
```

## 공격 재현 (시연)

```bash
# frontend 컨테이너 안으로
kubectl exec -it -n skillshop deploy/frontend -- sh

# 1) root로 실행 중인지
id                                            # uid=0(root)
# 2) 횡적 이동 — 아무 제한 없이 결제 서비스에 닿음
curl -s http://payment-svc:8080/health
# 3) 카드 정보 평문 유출
curl -s http://payment-svc:8080/cards
```

이 무방비 상태를 `99-hardened`(다음 단계)에서 한 겹씩 막습니다:
SecurityContext(2강) · PSS(3강) · RBAC(4강) · NetworkPolicy(5강) · TLS(6강) ...
