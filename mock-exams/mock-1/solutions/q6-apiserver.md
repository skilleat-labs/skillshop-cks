# q6 정답 — kube-apiserver 익명 접근 차단 (노드/컨트롤플레인)

## 0) 백업 (필수)
```bash
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/kube-apiserver.yaml.bak
```

## 1) 매니페스트 수정 — /etc/kubernetes/manifests/kube-apiserver.yaml
`spec.containers[0].command` 에 아래 플래그를 추가/수정:
```yaml
    - --anonymous-auth=false
    - --authorization-mode=Node,RBAC
    - --enable-admission-plugins=NodeRestriction   # 기존 목록에 콤마로 이어붙이기
```
> static pod 라 파일 저장 시 kubelet 이 자동으로 apiserver 를 재기동한다.

## 2) 검증
```bash
sudo crictl ps | grep kube-apiserver          # 재기동되어 새 컨테이너로 떴는지
# 익명 접근이 막혔는지 (Unauthorized 나와야 성공)
curl -sk https://localhost:6443/healthz        # (인증 없이) 정상 healthz 는 열려있을 수 있으나
curl -sk https://localhost:6443/api            # Unauthorized(401) 이어야 함
kubectl get --raw='/readyz'                    # kubectl(정상 인증)은 여전히 동작해야 함
```

## 문제 발생 시 원복
```bash
sudo cp ~/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

> **함정:** `--enable-admission-plugins` 는 **기존 값에 이어붙여야** 한다(덮어쓰면 다른 플러그인이 빠짐).
> apiserver 가 안 뜨면 `sudo crictl logs <apiserver-container-id>` 로 원인 확인.
