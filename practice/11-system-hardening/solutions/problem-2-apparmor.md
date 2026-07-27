# 문제 2 정답 — AppArmor (프로파일 로드 → Pod 지정)

AppArmor 는 **프로그램 단위 강제 접근제어(MAC)**. 순서가 핵심이다:
**① 노드에 프로파일 파일 배치 → ② 커널에 로드 → ③ 파드에서 참조**.
프로파일이 로드 안 된 노드에 파드가 스케줄되면 **파드가 뜨지 않는다**(Blocked).

## 1) 노드에 프로파일 배치 + 로드 (해당 파드가 뜰 노드에서)
`/etc/apparmor.d/k8s-deny-write` (예: 모든 쓰기 차단 프로파일):
```
#include <tunables/global>
profile k8s-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>
  file,
  # 모든 파일 쓰기 거부
  deny /** w,
}
```
로드 & 확인:
```bash
sudo apparmor_parser -q /etc/apparmor.d/k8s-deny-write   # 커널에 로드( -r 로 리로드)
sudo aa-status | grep k8s-deny-write                     # 로드됐는지 확인
```
> ⚠️ 멀티노드 함정: 프로파일은 **파드가 뜰 노드**에 로드돼야 한다. 어느 노드일지 모르면
> 모든 워커에 로드하거나, 파드에 `nodeSelector` 로 노드를 고정하라.

## 2) 파드에 지정 — k8s 1.32 는 **필드 방식** (권장)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-pod
  namespace: sys-ex
spec:
  containers:
  - name: c
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      appArmorProfile:
        type: Localhost              # 노드에 로드된 커스텀 프로파일 사용
        localhostProfile: k8s-deny-write   # 'localhost/' 접두어 없이 이름만
```
> `appArmorProfile` 은 **파드 레벨**(`spec.securityContext`) 또는 **컨테이너 레벨** 둘 다 가능.
> `type` 값: `RuntimeDefault`(런타임 기본) / `Localhost`(커스텀) / `Unconfined`(해제).

## 3) 이전 방식(annotation) — 참고용 (1.30 에서 deprecated)
시험 클러스터 버전이 낮으면 요구될 수 있으니 형태만 기억:
```yaml
metadata:
  annotations:
    container.apparmor.security.beta.kubernetes.io/c: localhost/k8s-deny-write
```

## 4) 검증
```bash
kubectl apply -f apparmor-pod.yaml
kubectl get pod apparmor-pod -n sys-ex          # Running 이어야(로드 안 됐으면 Blocked)
kubectl exec -n sys-ex apparmor-pod -- touch /tmp/x   # deny /** w → Permission denied 면 프로파일 적용됨
```

## 핵심 요약
- 순서 고정: 노드에 파일 → `apparmor_parser` 로드 → `aa-status` 확인 → 파드 `appArmorProfile`.
- 1.32 = **필드**(`securityContext.appArmorProfile`), 예전 = annotation.
- `localhostProfile` 에는 **프로파일 이름만**(파일 안 `profile <이름>` 과 일치). annotation 방식만 `localhost/` 접두어를 씀.
