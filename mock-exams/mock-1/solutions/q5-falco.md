# q5 정답 — Falco 컨테이너 셸 실행 탐지 룰 (노드 작업)

## 0) 서비스명 먼저 확인 (함정)
```bash
systemctl list-units 'falco*'      # falco-modern-bpf / falco-bpf / falco-kmod 중 하나
```
아래 예시는 `falco-modern-bpf` 기준. 본인 유닛명으로 바꿔서 사용.

## 1) 커스텀 룰 작성 — /etc/falco/falco_rules.local.yaml
기본 `falco_rules.yaml` 은 건드리지 말고 **local** 파일에만 추가한다.
Falco 기본 룰셋에 이미 `Terminal shell in container` 매크로가 있으니 재사용해도 되고,
직접 룰을 쓸 수도 있다. 직접 작성 예:

```yaml
# /etc/falco/falco_rules.local.yaml
- rule: Shell spawned in container (custom)
  desc: Detect shell execution inside a container
  condition: >
    spawned_process and container
    and proc.name in (sh, bash, ash, zsh, ksh)
  output: >
    Shell spawned in container (user=%user.name container=%container.name
    proc=%proc.name cmdline=%proc.cmdline image=%container.image.repository)
  priority: WARNING
  tags: [container, shell, mitre_execution]
```

## 2) 적용 + 검증
```bash
sudo systemctl restart falco-modern-bpf
sudo journalctl -fu falco-modern-bpf | grep -i "Shell spawned in container"
# 다른 터미널에서 트리거:
kubectl run tmp --image=busybox:1.36 --restart=Never -it -- sh    # 셸 진입 → 경고 발생하면 성공
```

> **함정(노션):** 유닛명이 `falco` 가 아니라 `falco-modern-bpf`. 없다고 falco 를 새로 설치하지 말 것.
> 이미 modern-bpf 로 돌고 있는 경우가 많다.
