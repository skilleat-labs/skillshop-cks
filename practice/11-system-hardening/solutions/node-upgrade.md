# 문제 4 정답 — 워커 노드 업그레이드 (한 노드씩)
```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

apt-mark unhold kubeadm && apt-get install -y kubeadm=1.30.x && apt-mark hold kubeadm
kubeadm upgrade node

apt-mark unhold kubelet kubectl && apt-get install -y kubelet=1.30.x kubectl=1.30.x && apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet

kubectl uncordon <node>
```
> 컨트롤플레인은 `kubeadm upgrade apply v1.30.x`, 워커는 `kubeadm upgrade node`.
> apt-mark unhold→install→hold 세트, daemon-reload·uncordon 빠뜨리지 말 것.
