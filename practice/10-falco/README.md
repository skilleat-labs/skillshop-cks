# 10강 실습 — Falco (런타임 탐지)

> Falco 는 노드(호스트)에 설치돼 동작합니다. 룰 작성은 노드 파일, 탐지 대상은 클러스터 워크로드.

```bash
kubectl apply -f workload.yaml      # 탐지 대상(suspicious) 배포
```

## 문제 1 — 커스텀 룰 작성 (노드)
컨테이너 안에서 셸(sh/bash) 실행 시 경고하는 룰을 `/etc/falco/falco_rules.local.yaml` 에 추가하라.
(기본 `falco_rules.yaml` 은 건드리지 말 것) 작성 후 `sudo systemctl restart falco`. 정답: `solutions/falco_rules.local.yaml`
```bash
sudo journalctl -fu falco | grep -i "shell"     # 경고가 뜨면 성공
```

## 문제 2 — 탐지 후 대응
악성 워크로드를 멈춰라. Pod 를 직접 지우지 말고(재생성됨) Deployment 를 스케일 0 으로.
```bash
kubectl scale deploy/suspicious -n falco-ex --replicas=0
kubectl get pods -n falco-ex      # 파드 사라짐
```

## 정리
```bash
kubectl delete -f workload.yaml
```
