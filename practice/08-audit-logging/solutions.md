# 8강 정답 — kube-apiserver.yaml 에 추가할 것

command(플래그):
```
- --audit-policy-file=/etc/kubernetes/audit-policy.yaml
- --audit-log-path=/var/log/kubernetes/audit.log
- --audit-log-maxage=7
```

volumeMounts (containers[].volumeMounts):
```yaml
- name: audit-policy
  mountPath: /etc/kubernetes/audit-policy.yaml
  readOnly: true
- name: audit-log
  mountPath: /var/log/kubernetes
```

volumes (spec.volumes):
```yaml
- name: audit-policy
  hostPath:
    path: /etc/kubernetes/audit-policy.yaml
    type: File
- name: audit-log
  hostPath:
    path: /var/log/kubernetes
    type: DirectoryOrCreate
```
