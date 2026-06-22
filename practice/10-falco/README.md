# 10강 실습 — Falco (런타임 탐지)

> Falco 는 노드(호스트)에 설치돼 동작합니다. 룰 작성은 노드의 파일, 탐지 대상은 클러스터 워크로드.

```bash
kubectl apply -f start.yaml      # 탐지 대상(suspicious) 배포
```

## 문제 1 — 커스텀 룰 작성 (노드)
컨테이너 안에서 셸(sh/bash)이 실행되면 경고하는 룰을 **`/etc/falco/falco_rules.local.yaml`** 에 추가하라.
(기본 `falco_rules.yaml` 은 건드리지 말 것) 작성 후 `sudo systemctl restart falco`.
정답: `solutions/falco_rules.local.yaml`

검증:
```bash
sudo journalctl -fu falco | grep -i "shell"     # 경고가 주기적으로 뜨면 성공
```

## 문제 2 — 탐지 후 대응
경고에 나온 악성 워크로드를 멈춰라. **Pod 를 직접 지우지 말고**(재생성됨) Deployment 를 스케일 0 으로.

검증:
```bash
kubectl scale deploy/suspicious -n falco-ex --replicas=0
kubectl get pods -n falco-ex      # 파드 사라짐
```

## 정리
```bash
kubectl delete -f start.yaml
```
