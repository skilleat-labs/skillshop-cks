# q4 정답 — Audit Logging (노드/컨트롤플레인)

## 0) 백업
```bash
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/kube-apiserver.yaml.bak
```

## 1) 정책 파일 배치
`files/audit-policy.yaml` 를 컨트롤플레인 노드로 복사:
```bash
sudo cp audit-policy.yaml /etc/kubernetes/audit-policy.yaml
sudo mkdir -p /var/log/kubernetes
```

## 2) kube-apiserver.yaml 에 플래그 추가 (spec.containers[0].command)
```yaml
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit.log
    - --audit-log-maxage=7
    - --audit-log-maxbackup=2
    - --audit-log-maxsize=50
```

## 3) volumeMounts + volumes (둘 다 필요 — 하나라도 빠지면 apiserver 기동 실패)
```yaml
    # spec.containers[0].volumeMounts 에:
    - name: audit-policy
      mountPath: /etc/kubernetes/audit-policy.yaml
      readOnly: true
    - name: audit-log
      mountPath: /var/log/kubernetes
  # spec.volumes 에:
  - name: audit-policy
    hostPath:
      path: /etc/kubernetes/audit-policy.yaml
      type: File
  - name: audit-log
    hostPath:
      path: /var/log/kubernetes
      type: DirectoryOrCreate
```

## 4) 검증
```bash
sudo crictl ps | grep kube-apiserver          # 재기동 확인
sudo tail -1 /var/log/kubernetes/audit.log     # JSON 요청 로그
```

> **함정:** `volumeMounts` 만 넣고 `volumes` 를 빠뜨리면 apiserver 가 안 뜬다. 두 개를 세트로.
