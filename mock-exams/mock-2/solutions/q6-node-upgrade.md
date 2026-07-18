# q6 정답 — 노드 안전 업그레이드 (kubeadm)

> 대상 패치버전은 문제 지시에 맞춰라(예: 1.32.2). 아래는 절차 템플릿.

## 1) control-plane 에서: 노드 drain
```bash
kubectl drain worker-1 --ignore-daemonsets --delete-emptydir-data --force
```

## 2) 해당 워커 노드(worker-1)에 SSH 후: kubeadm 업그레이드
```bash
apt-mark unhold kubeadm
apt-get update && apt-get install -y kubeadm=1.32.2-1.1
apt-mark hold kubeadm
kubeadm upgrade node
```

## 3) kubelet + kubectl 업그레이드 후 재시작
```bash
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.32.2-1.1 kubectl=1.32.2-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload
systemctl restart kubelet
```

## 4) control-plane 에서: uncordon
```bash
kubectl uncordon worker-1
kubectl get nodes         # worker-1 이 새 버전 & Ready
```

> **함정:** control-plane 노드는 `kubeadm upgrade apply <ver>`, 워커는 `kubeadm upgrade node`.
> drain 시 `--ignore-daemonsets` 필수(Cilium 등 DaemonSet 때문).
