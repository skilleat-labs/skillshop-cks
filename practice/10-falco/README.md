# 10강 실습 — Falco (런타임 탐지)

> Falco 는 **노드(호스트)의 systemd 서비스**로 동작합니다. 클러스터 리소스가 아니에요.
> 룰 파일은 노드의 `/etc/falco/`, 로그는 `journalctl`, 탐지 대상은 클러스터 워크로드입니다.
> Falco 는 **방화벽이 아니라 감시 도구** — 접근을 "막는" 게 아니라 "탐지·알림"하고, 대응(정지)은 사람이/kubectl 로 합니다.

## 전제조건 — Falco 설치 + 탐지 대상 배포 (실습 전 1회)

시험장엔 미리 깔려 있지만, 자가 실습 환경엔 직접 설치해야 합니다.
**먼저 탐지 대상 파드가 어느 노드인지 확인**하고, 그 노드에서 설치하세요(모르면 모든 워커에).

```bash
kubectl apply -f workload.yaml          # 탐지 대상(suspicious + intruder) 배포
kubectl get pod -n falco-ex -o wide     # NODE 컬럼 확인 → 그 노드에 설치
# 그 노드에 SSH 후:
./setup-falco.sh                        # Falco 설치 + Modern eBPF 서비스 기동 (1회)
```

> 서비스 이름은 드라이버에 따라 `falco-modern-bpf`(권장) / `falco-bpf` / `falco-kmod` 중 하나입니다.
> 아래 명령의 `falco-modern-bpf` 는 본인 유닛명으로 바꾸세요 (`systemctl list-units 'falco*'` 로 확인).

---

## 문제 1 — Falco 가 동작하는지, 어떤 서비스로 도는지 찾기 (진단)
노드에서 Falco 가 **실제 동작 중인지**, 그리고 **어떤 systemd 유닛(드라이버)** 으로 도는지 확인하라.
찾은 유닛 이름을 `/tmp/falco-service.txt` 에 적어라. 정답/요령: `solutions/p1-service-check.md`
```bash
systemctl list-units 'falco*' --all           # 어떤 falco 유닛이 있나
systemctl is-active falco-modern-bpf           # active 면 동작 중 (본인 유닛명으로)
sudo journalctl -u falco-modern-bpf -n 20 --no-pager
echo falco-modern-bpf > /tmp/falco-service.txt # 동작 중인 유닛명 기록
```

## 문제 2 — 커스텀 룰: 컨테이너 안 셸 실행 탐지 (노드)
컨테이너 안에서 셸(sh/bash)이 실행되면 경고하는 룰을 `/etc/falco/falco_rules.local.yaml` 에 추가하라.
(기본 `falco_rules.yaml` 은 건드리지 말 것) 작성 후 서비스 재시작. 정답: `solutions/falco_rules.local.yaml`
```bash
sudo systemctl restart falco-modern-bpf
sudo journalctl -fu falco-modern-bpf | grep -i shell    # suspicious 가 sh 실행 → 경고 뜨면 성공
```

## 문제 3 — /dev/mem 접근 탐지 후 대응 (탐지 → scale 0)
`intruder` 파드가 privileged 로 `/dev/mem` 을 읽고 있다. 이를 **탐지하는 룰**을 작성하고,
탐지되면 **해당 Deployment 를 scale 0** 으로 멈춰라(파드 직접 삭제 금지 — 재생성됨).
정답/요령·함정: `solutions/p3-devmem.md`, 룰: `solutions/falco_rules.local.yaml`
```bash
# 1) 룰 추가 후 재시작 → 탐지 확인
sudo journalctl -fu falco-modern-bpf | grep -i /dev/mem   # "sensitive file accessed (pod=intruder-..." 
# 2) 대응: 탐지된 Deployment 를 scale 0
kubectl scale deploy/intruder -n falco-ex --replicas=0
kubectl get pods -n falco-ex                               # intruder 파드 사라짐 → 완료
```

> ⚠️ 함정 3가지 — ① `/dev/mem` 은 privileged 컨테이너에만 존재(일반 컨테이너엔 없음),
> ② 서비스명은 `falco` 가 아니라 `falco-modern-bpf` 등, ③ Pod 직접 delete 금지(재생성) → Deployment scale 0.

## 채점 (kubectl 로 확인 가능한 부분)
```bash
bash verify.sh
```
> ⚠️ 룰이 실제로 "발화"했는지는 노드의 `journalctl` 에서만 보입니다(Mac/kubectl 로는 확인 불가).
> verify.sh 는 문제 3의 **대응 결과(intruder scale 0)** 와 워크로드 상태만 자동 채점하고,
> 룰 발화는 노드에서 위 journalctl 명령으로 직접 확인하세요.

## 정리
```bash
kubectl delete -f workload.yaml
```
