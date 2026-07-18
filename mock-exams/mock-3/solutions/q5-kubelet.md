# q5 정답 — kubelet 하드닝 (노드)

## 0) 백업
```bash
sudo cp /var/lib/kubelet/config.yaml ~/kubelet-config.yaml.bak
```

## 1) /var/lib/kubelet/config.yaml 수정
```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: false          # 익명 접근 차단
  webhook:
    enabled: true
authorization:
  mode: Webhook             # AlwaysAllow 금지
readOnlyPort: 0            # 익명 읽기전용 포트(10255) 비활성
```

## 2) 재시작
```bash
sudo systemctl restart kubelet
sudo systemctl status kubelet     # active (running)
```

## 3) 검증
```bash
# 익명 접근이 막혔는지 (Unauthorized 나와야 성공)
curl -sk https://<노드IP>:10250/pods    # Unauthorized
curl -s  http://<노드IP>:10255/pods     # 거부/무응답 (readOnlyPort 0)
kubectl get --raw "/api/v1/nodes/<node>/proxy/pods" >/dev/null && echo "정상 인증은 동작"
```

> **함정:** 재시작 후 kubelet 이 안 뜨면 config 오타. `journalctl -u kubelet -e` 로 확인, 백업으로 원복.
