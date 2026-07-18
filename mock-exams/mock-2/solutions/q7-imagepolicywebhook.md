# q7 정답 — ImagePolicyWebhook (노드/컨트롤플레인)

## 0) 백업
```bash
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/kube-apiserver.yaml.bak
```

## 1) admission config 작성 — /etc/kubernetes/admission/config.yaml
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: ImagePolicyWebhook
    configuration:
      imagePolicy:
        kubeConfigFile: /etc/kubernetes/admission/kubeconfig.yaml
        allowTTL: 50
        denyTTL: 50
        retryBackoff: 500
        defaultAllow: false        # ★ 웹훅 장애 시 이미지 거부
```
(웹훅 백엔드 접속용 `/etc/kubernetes/admission/kubeconfig.yaml` 도 함께 준비)

## 2) kube-apiserver.yaml 수정
```yaml
    - --enable-admission-plugins=...,ImagePolicyWebhook       # 기존 목록에 추가
    - --admission-control-config-file=/etc/kubernetes/admission/config.yaml
```
```yaml
    # volumeMounts:
    - name: admission
      mountPath: /etc/kubernetes/admission
      readOnly: true
  # volumes:
  - name: admission
    hostPath:
      path: /etc/kubernetes/admission
      type: DirectoryOrCreate
```

## 3) 검증
```bash
sudo crictl ps | grep kube-apiserver
grep -E 'ImagePolicyWebhook|admission-control-config-file' /etc/kubernetes/manifests/kube-apiserver.yaml
```

> **함정:** `defaultAllow: false` 여야 "백엔드 불가 시 거부". `--admission-control-config-file` 경로와
> hostPath 볼륨을 반드시 세트로. 디렉터리 통째로 마운트(config + kubeconfig 둘 다 필요).
