# 7강 정답 (핵심 라인)

## kubelet — /var/lib/kubelet/config.yaml
```yaml
authentication:
  anonymous:
    enabled: false
authorization:
  mode: Webhook
readOnlyPort: 0
```
```bash
sudo systemctl restart kubelet
```

## kube-apiserver — /etc/kubernetes/manifests/kube-apiserver.yaml (spec.containers[].command)
```
- --anonymous-auth=false
- --authorization-mode=Node,RBAC
```

## etcd — /etc/kubernetes/manifests/etcd.yaml
```
- --client-cert-auth=true
- --peer-client-cert-auth=true
```
> static pod(apiserver/etcd)은 파일 저장 = 자동 재기동, kubelet은 수동 restart.
