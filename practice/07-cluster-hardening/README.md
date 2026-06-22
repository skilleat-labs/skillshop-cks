# 7강 실습 — Cluster Hardening (노드에서 직접 수정)

> 이 강은 네임스페이스 YAML이 아니라 **노드의 설정 파일**을 고칩니다. 컨트롤플레인/워커 노드에 SSH로 들어가 진행하세요.
> ⚠️ 매니페스트를 잘못 고치면 클러스터가 멈출 수 있으니 **수정 전 백업**(`cp x x.bak`) 필수.

## 문제 1 — kubelet 익명 접근 차단 (워커/모든 노드)
`/var/lib/kubelet/config.yaml` 에서:
- `authentication.anonymous.enabled: false`
- `authorization.mode: Webhook`
- `readOnlyPort: 0`
적용 후 `sudo systemctl restart kubelet`

검증:
```bash
curl -sk https://<노드IP>:10250/pods    # Unauthorized 면 성공
curl -s  http://<노드IP>:10255/pods     # 거부/무응답 이어야 함
```

## 문제 2 — kube-apiserver 익명 인증 끄기 (컨트롤플레인)
`/etc/kubernetes/manifests/kube-apiserver.yaml` 의 command 에:
- `--anonymous-auth=false`
- `--authorization-mode=Node,RBAC`
static pod 라 파일 저장 시 자동 재기동. `watch crictl ps` 로 재기동 확인.

## 문제 3 — etcd 클라이언트 인증서 인증 (컨트롤플레인)
`/etc/kubernetes/manifests/etcd.yaml` 에:
- `--client-cert-auth=true`
- `--peer-client-cert-auth=true`

정답 라인은 `solutions.md` 참고.
