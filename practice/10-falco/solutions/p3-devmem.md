# 문제 3 정답 — /dev/mem 접근 탐지 후 대응 (탐지 → scale 0)

Falco 는 방화벽이 아니라 감시 도구다. `/dev/mem` 접근을 **막는** 게 아니라 **잡아내서 알린다**.
잡아낸 뒤 사람이/자동화가 **대응(악성 워크로드 정지)** 한다.

## 1) 탐지 룰 — /etc/falco/falco_rules.local.yaml 에 추가
```yaml
- rule: Detect /dev/mem access
  desc: detect access to /dev/mem
  condition: open_read and container and fd.name=/dev/mem
  output: "sensitive file accessed (pod=%k8s.pod.name ns=%k8s.ns.name container=%container.id)"
  priority: CRITICAL
```
적용:
```bash
sudo systemctl restart falco-modern-bpf          # 본인 유닛명으로 (문제 1에서 확인)
sudo journalctl -fu falco-modern-bpf | grep -i /dev/mem
# → "sensitive file accessed (pod=intruder-... ns=falco-ex ...)" 뜨면 탐지 성공
```

## 2) 대응 — 탐지된 파드의 Deployment 를 scale 0
로그의 pod 이름으로 소유 Deployment 를 찾아 **스케일 0** (파드 직접 삭제 금지 = 재생성됨).
```bash
kubectl get pods -n falco-ex -o wide             # 어느 파드가 걸렸나 → intruder-xxxx
kubectl scale deploy/intruder -n falco-ex --replicas=0
kubectl get pods -n falco-ex                     # intruder 파드 사라짐 → 대응 완료
```

## 걸리는 함정 3가지 (실습에서 겪은 것)
1. **/dev/mem 은 privileged 컨테이너에만 존재** — 일반 컨테이너엔 파일 자체가 없어 트리거 안 됨
   ("No such file"). workload 의 intruder 가 `privileged: true` 인 이유.
2. **서비스명** — `falco` 가 아니라 `falco-modern-bpf`(또는 `-bpf`/`-kmod`). restart·journalctl 을
   정확한 유닛명으로. (`systemctl list-units 'falco*'`)
3. **Pod 직접 delete 금지** — Deployment 가 즉시 재생성. 반드시 **Deployment 를 scale 0** (또는 삭제).

## 왜 open_read + fd.name 인가
- `open_read` : 파일을 읽기용으로 여는 syscall (open/openat) 이벤트
- `container` : 호스트가 아닌 컨테이너 안에서 발생한 것만 (노이즈 제거)
- `fd.name=/dev/mem` : 대상 경로 정확히 지정
- k8s 필드(`%k8s.pod.name`)가 비면 컨테이너 런타임 enrich 문제 → `%container.name`/`%container.id` 로 대체.
