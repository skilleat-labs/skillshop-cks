# q6 정답 — Falco /dev/mem 탐지 + 대응

## 1) 커스텀 룰 작성 — /etc/falco/falco_rules.local.yaml (노드)
```bash
systemctl list-units 'falco*'      # 유닛명 먼저 확인 (falco-modern-bpf 등)
```
```yaml
# /etc/falco/falco_rules.local.yaml
- rule: Read sensitive device mem (custom)
  desc: Detect access to /dev/mem or /dev/kmem inside a container
  condition: >
    open_read and container
    and fd.name in (/dev/mem, /dev/kmem)
  output: >
    Sensitive device access (container=%container.name proc=%proc.name
    file=%fd.name image=%container.image.repository ns=%k8s.ns.name pod=%k8s.pod.name)
  priority: CRITICAL
  tags: [container, filesystem, mitre_credential_access]
```
```bash
sudo systemctl restart falco-modern-bpf
sudo journalctl -fu falco-modern-bpf | grep -i "Sensitive device access"
```

## 2) 문제 Pod 식별 → Deployment 스케일 0 (대응)
```bash
kubectl get pods -n m3-falco -o wide          # 어느 Deployment 인지 확인 → suspicious
# Pod 를 직접 지우면 ReplicaSet 이 재생성한다. Deployment 를 0 으로.
kubectl scale deploy/suspicious -n m3-falco --replicas=0
kubectl get pods -n m3-falco                   # 파드 사라짐
```

> **함정:** `kubectl delete pod` 는 재생성됨 → 반드시 Deployment `replicas: 0` (또는 delete deploy).
> 유닛명 함정(`falco-modern-bpf`)도 동일.
