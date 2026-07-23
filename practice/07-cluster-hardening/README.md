# 7강 실습 — Cluster Hardening (노드에서 직접 수정)

> 이 강은 네임스페이스 YAML이 아니라 **노드의 설정 파일**을 고칩니다. 컨트롤플레인/워커 노드에 SSH로 들어가 진행하세요.
> ⚠️ 매니페스트를 잘못 고치면 클러스터가 멈출 수 있으니 **수정 전 백업**(`cp x x.bak`) 필수.

## 문제 1 — kubelet 익명 접근 차단 · **노드 `worker-1` (192.168.56.11)**
> kubelet 은 모든 노드에 있다. 시험은 **어느 노드에서 하라고 지정**한다. 이 문제는 `worker-1` 에서 한다.
> ```bash
> ssh vboxuser@192.168.56.11        # worker-1 로 접속 (또는 VirtualBox 콘솔로 직접 로그인)
> ```
`worker-1` 의 `/var/lib/kubelet/config.yaml` 에서:
- `authentication.anonymous.enabled: false`
- `authorization.mode: Webhook`
- `readOnlyPort: 0`
적용 후 `sudo systemctl restart kubelet`

검증 (control-plane 에서, 대상 노드 IP 로):
```bash
curl -sk https://192.168.56.11:10250/pods    # worker-1 kubelet → Unauthorized 면 성공
curl -s  http://192.168.56.11:10255/pods     # readOnlyPort 닫힘 → 거부/무응답 이어야 함
```
> 다른 노드(control-plane·worker-2)의 kubelet 도 원칙적으로 같은 하드닝이 필요하다. 실전에선 지정된 노드에만,
> 전체 하드닝이 목표면 모든 노드에 반복 적용한다.

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

## 문제 4 — apiserver 익명 접근 차단 + kubeconfig 로 접근 테스트 (컨트롤플레인) · **시험 단골**
(실제 CKS 유형) 특정 신원의 kubeconfig 가 주어지고, apiserver 를 수정한 뒤 그 kubeconfig 로
접근이 의도대로 되는지 **직접 테스트**하는 문제.

**준비 (한 번):**
```bash
./make-tester-kubeconfig.sh        # /tmp/tester.kubeconfig 생성 (CN=tester, 아직 권한 없음)
```

**과제:**
1. 현재 apiserver 는 **익명 인증을 허용**한다. 확인:
   ```bash
   curl -sk https://<노드IP>:6443/api -o /dev/null -w "%{http_code}\n"   # 403 → 익명 인증됨(=허용 상태)
   ```
2. `/etc/kubernetes/manifests/kube-apiserver.yaml` 에서 익명 인증을 끄고(`--anonymous-auth=false`)
   인가 모드를 `Node,RBAC` 로 둬라. (⚠️ 수정 전 백업)
3. 주어진 `tester` 신원이 **파드를 조회(get/list)할 수 있도록** RBAC 를 부여하라(ClusterRole + Binding).

**검증:**
```bash
# ① 익명은 이제 인증 자체가 막힘 (403 → 401 로 바뀜)
curl -sk https://<노드IP>:6443/api -o /dev/null -w "%{http_code}\n"        # 401

# ② tester 는 RBAC 덕에 파드 조회 가능
kubectl --kubeconfig /tmp/tester.kubeconfig auth can-i list pods           # yes
kubectl --kubeconfig /tmp/tester.kubeconfig get pods -n default            # 목록 나옴

# ③ 권한 밖은 여전히 거부 (인증O·인가X → Forbidden)
kubectl --kubeconfig /tmp/tester.kubeconfig auth can-i delete pods         # no
```
정답: `solutions.md` (문제 4). 채점: `bash verify.sh`

> **핵심 개념 — 응답코드로 판별:** 401=인증 실패(익명 차단) · 403=인증 O·권한 X(RBAC 거부) · 200=허용.
> "kubeconfig 로 테스트"는 `kubectl --kubeconfig <파일> auth can-i ...` 로 그 신원이 되어 물어보는 것.
