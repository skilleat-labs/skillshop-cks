# q2 정답 — Secrets 암호화 at rest (노드/컨트롤플레인)

## 0) 백업
```bash
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/kube-apiserver.yaml.bak
```

## 1) 암호화 설정 파일 — /etc/kubernetes/enc/enc.yaml
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources: ["secrets"]
    providers:
      - aescbc:                       # 또는 aesgcm/secretbox
          keys:
            - name: key1
              secret: <base64 32바이트>   # head -c 32 /dev/urandom | base64
      - identity: {}                  # 마지막에 identity (읽기 호환)
```
```bash
sudo mkdir -p /etc/kubernetes/enc
head -c 32 /dev/urandom | base64      # 이 값을 secret 에 넣는다
```

## 2) kube-apiserver.yaml 수정
```yaml
    - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml
```
```yaml
    # volumeMounts:
    - name: enc
      mountPath: /etc/kubernetes/enc
      readOnly: true
  # volumes:
  - name: enc
    hostPath:
      path: /etc/kubernetes/enc
      type: DirectoryOrCreate
```

## 3) 기존 secret 재암호화 (중요 — 안 하면 기존 건 평문 그대로)
```bash
kubectl get secrets -A -o json | kubectl replace -f -
```

## 검증
```bash
# etcd 에서 secret 이 암호화됐는지 (k8s:enc:aescbc 프리픽스)
sudo ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  --key=/etc/kubernetes/pki/apiserver-etcd-client.key \
  get /registry/secrets/default/<some-secret> | hexdump -C | head
```

> **함정:** ① `identity: {}` 를 provider 목록 **끝**에 둬야 기존 평문도 읽힌다.
> ② 설정만 하고 `kubectl replace` 재암호화를 안 하면 이미 저장된 secret 은 평문으로 남는다.
