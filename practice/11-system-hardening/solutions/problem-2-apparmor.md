# 문제 2 정답 — AppArmor (노드 로드 → 이름 확인 → 매니페스트 적용)

시험 단골 3단계: **① worker 노드 SSH → 프로파일 로드 → ② 프로파일 "이름" 확인 → ③ 매니페스트에 지정**.
허용 문서: `kubernetes.io/docs/tutorials/security/apparmor/`

---

## ① worker 노드에 프로파일 로드 (그 파드가 뜰 노드에서)
```bash
ssh worker1                                  # ★ 프로파일 적용할 노드로. base/control-plane 아님
# files/k8s-apparmor-deny-write 를 노드 /etc/apparmor.d/ 로 복사해 둔 상태에서:
sudo apparmor_parser -q /etc/apparmor.d/k8s-apparmor-deny-write   # 커널에 로드( -r 리로드)
```

## ② 프로파일 "이름" 확인 (★최대 함정: 파일명 ≠ 프로파일명)
```bash
sudo aa-status | grep very-secure            # 로드된 "이름" 확인
sudo apparmor_status                         # 전체 목록
cat /sys/kernel/security/apparmor/profiles | grep very-secure   # 대안
exit                                         # 노드에서 나오기
```
```
파일:  /etc/apparmor.d/k8s-apparmor-deny-write     ← 파일명
안에:  profile very-secure { ... }                 ← ★ 매니페스트엔 이 이름(very-secure)!
```
> 파일명으로 착각하면 틀린다. `aa-status` 로 확인한 **profile 뒤의 이름**을 써라.

## ③ 매니페스트에 지정 — k8s 1.32 = securityContext 필드 (정답)
`problem-2.yaml` 의 `spec` 에 추가:
```yaml
spec:
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: very-secure     # ← 파일명 아님, 프로파일 "이름"
  containers:
  - name: c
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```
> `appArmorProfile` 은 **파드 레벨**(위) 또는 **컨테이너 레벨** 둘 다 가능.
> `type`: `RuntimeDefault` / `Localhost`(커스텀) / `Unconfined`.

### (참고) 구버전 annotation 방식 — 1.30 에서 deprecated
```yaml
metadata:
  annotations:
    container.apparmor.security.beta.kubernetes.io/c: localhost/very-secure
```
> annotation 방식만 `localhost/` 접두어를 붙인다. 필드 방식은 이름만.

## 적용 + 검증
```bash
kubectl apply -f problem-2.yaml
kubectl get pod secure-pod -n sys-ex                     # Running (로드 안 된 노드면 Blocked)
kubectl get pod secure-pod -n sys-ex -o jsonpath='{..appArmorProfile}'   # {Localhost very-secure}
# deny /** w 프로파일이 걸렸으면 쓰기가 막힌다:
kubectl exec -n sys-ex secure-pod -- touch /tmp/x        # Permission denied 면 적용 성공
```

## 함정 정리
1. **노드 SSH 안 함** → 프로파일은 파드가 뜰 그 노드에 로드해야. 어느 노드일지 모르면 모든 워커에 로드하거나 `nodeSelector` 로 고정.
2. **파일명 ≠ 프로파일명 (최대 함정)** → `aa-status` 로 `profile <이름>` 의 이름 확인 후 그걸 사용.
3. **버전별 문법** → 1.32 는 `securityContext.appArmorProfile`(필드), 구버전은 annotation.
4. **로드 먼저** → `apparmor_parser` 안 하고 매니페스트만 고치면 파드가 Blocked/에러.
