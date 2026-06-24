# 10강 실습 — Falco (런타임 탐지)

> Falco 는 **노드(호스트)의 systemd 서비스**로 동작합니다. 클러스터 리소스가 아니에요.
> 룰 파일은 노드의 `/etc/falco/`, 로그는 `journalctl`, 탐지 대상은 클러스터 워크로드.

## 전제조건 — Falco 설치 (실습 전 1회, 노드에서)

시험장엔 미리 깔려 있지만, 자가 실습 환경엔 직접 설치해야 합니다.
**먼저 탐지 대상 파드가 어느 노드인지 확인**하고, 그 노드에서 설치하세요(모르면 모든 워커에).

```bash
kubectl get pod -n falco-ex -o wide     # NODE 컬럼 확인
# 그 노드에 SSH 후:
./setup-falco.sh                        # Falco 설치 + Modern eBPF 서비스 기동 (1회)
```

> 서비스 이름은 드라이버에 따라 `falco-modern-bpf`(권장) / `falco-bpf` / `falco-kmod` 중 하나예요.
> 아래 명령의 `falco-modern-bpf` 는 본인이 쓰는 서비스명으로 바꾸세요. (`systemctl list-units 'falco*'` 로 확인)

```bash
kubectl apply -f workload.yaml          # 탐지 대상(suspicious) 배포
```

## 문제 1 — 커스텀 룰 작성 (노드)
컨테이너 안에서 셸(sh/bash) 실행 시 경고하는 룰을 `/etc/falco/falco_rules.local.yaml` 에 추가하라.
(기본 `falco_rules.yaml` 은 건드리지 말 것) 작성 후 서비스 재시작. 정답: `solutions/falco_rules.local.yaml`
```bash
sudo systemctl restart falco-modern-bpf
sudo journalctl -fu falco-modern-bpf | grep -i "shell"     # 경고가 뜨면 성공
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
