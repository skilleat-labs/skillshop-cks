# 문제 5 정답 (핵심) — ImagePolicyWebhook

## /etc/kubernetes/admission/config.yaml
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: ImagePolicyWebhook
    configuration:
      imagePolicy:
        kubeConfigFile: /etc/kubernetes/admission/imagepolicy-kubeconfig.yaml
        defaultAllow: false      # 백엔드 불가 시 거부
        allowTTL: 50
        denyTTL: 50
        retryBackoff: 500
```

## kube-apiserver.yaml
```
- --enable-admission-plugins=...,ImagePolicyWebhook
- --admission-control-config-file=/etc/kubernetes/admission/config.yaml
```
+ /etc/kubernetes/admission 디렉토리를 hostPath(DirectoryOrCreate) 로 volume 마운트.
