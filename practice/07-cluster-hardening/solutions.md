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

## 문제 4 — apiserver 익명 차단 + kubeconfig 접근 테스트
### (1) apiserver 수정 — /etc/kubernetes/manifests/kube-apiserver.yaml
```
- --anonymous-auth=false
- --authorization-mode=Node,RBAC
```
저장 = 자동 재기동. `watch crictl ps` 로 apiserver 새로 뜨는지 확인. 수정 전 백업 필수.

### (2) tester 에게 파드 조회 RBAC 부여
```bash
kubectl create clusterrole pod-reader --verb=get,list --resource=pods
kubectl create clusterrolebinding tester-read --clusterrole=pod-reader --user=tester
```
> `tester` 는 인증서의 CN. kubeconfig 는 `./make-tester-kubeconfig.sh` 가 만든다.

### (3) 검증 — 응답코드/‌can-i 로 판별
```bash
curl -sk https://<노드IP>:6443/api -o /dev/null -w "%{http_code}\n"   # 401 (전엔 403 = 익명 인증됨)
kubectl --kubeconfig /tmp/tester.kubeconfig auth can-i list  pods     # yes
kubectl --kubeconfig /tmp/tester.kubeconfig auth can-i delete pods    # no  (권한 밖)
```
> 함정: ① 익명이 막혔는지는 **401**(인증 실패)로 확인 — 403(권한 없음)과 구분.
> ② RBAC subject 는 `--user=tester` (SA 가 아니라 인증서 CN 사용자).
> ③ apiserver 안 뜨면 `crictl logs <apiserver-id>` → 대부분 플래그 오타. 백업으로 원복.
