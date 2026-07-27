# 11강 실습 — System Hardening

문제 1·2 는 매니페스트(YAML) 수정, 문제 3·4 는 노드 작업입니다. (문제 2 는 노드 로드 + 매니페스트 둘 다)

```bash
kubectl apply -f problem-1.yaml     # 문제 1 환경(ns sys-ex + deploy app)
# 문제 2 는 problem-2.yaml 을 수정해서 apply (아래 문제 2 참고)
```

## 문제 1 — seccomp 적용 · ns `sys-ex`, deploy `app` (YAML)
`app` 에 `seccompProfile.type: RuntimeDefault` 를 적용하라. 정답: `solutions/problem-1.yaml`
```bash
kubectl get deploy app -n sys-ex -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}'   # RuntimeDefault
```

## 문제 2 — AppArmor (노드) · 준비된 매니페스트 `problem-2.yaml` 를 수정
시험 단골 3단계. 프로파일 파일은 `files/k8s-apparmor-deny-write`, 정답: `solutions/problem-2-apparmor.md`
허용 문서: `kubernetes.io/docs/tutorials/security/apparmor/`
```bash
# ① worker 노드에 SSH → 프로파일 로드 (base/control-plane 아님!)
scp files/k8s-apparmor-deny-write <user>@worker1:/tmp/ && ssh worker1
sudo cp /tmp/k8s-apparmor-deny-write /etc/apparmor.d/ && sudo apparmor_parser -q /etc/apparmor.d/k8s-apparmor-deny-write
# ② 프로파일 "이름" 확인 (★파일명 아님! 파일 안 'profile very-secure')
sudo aa-status | grep very-secure ;  exit
# ③ problem-2.yaml 에 securityContext.appArmorProfile 추가 후 적용
kubectl apply -f problem-2.yaml
kubectl exec -n sys-ex secure-pod -- touch /tmp/x   # deny 프로파일이면 Permission denied → 적용됨
```
> ★ **최대 함정: 파일명 ≠ 프로파일명.** `localhostProfile` 엔 파일명(`k8s-apparmor-deny-write`)이 아니라 파일 안 `profile` 뒤의 **이름(`very-secure`)** 을 쓴다. `aa-status` 로 확인.
> 지정 방식: **k8s 1.32** 는 `securityContext.appArmorProfile`(type: `Localhost`, localhostProfile: `<프로파일명>`) **필드**. (구버전 `container.apparmor.security.beta.kubernetes.io/<컨테이너>` annotation 은 1.30 deprecated)
> 프로파일은 파드가 뜰 노드에 **먼저 로드**돼야 스케줄됨(안 하면 Blocked).

## 문제 3 — 컨테이너 런타임 소켓 하드닝 (노드)
> ⚠️ **이 환경은 containerd 라 Docker 데몬이 없습니다.** `docker` 그룹·`/var/run/docker.sock` 이 없어 아래 Docker 명령은 **그대로는 실패**합니다. 시험 대비로 개념·명령은 익히되, 실제 실습은 **containerd 버전**(소켓 권한 확인)으로 하세요. 정답/대체과제: `solutions/problem-3-runtime.md`
```bash
# (A) Docker 기준 — 시험 개념 (이 환경에선 실행 불가)
getent group docker                     # grep 금지(부분매칭 위험)
sudo gpasswd -d <user> docker
sudo chmod 660 /var/run/docker.sock     # 확인: ls -l -> srw-rw---- (660)

# (B) containerd 기준 — 우리 환경에서 실습 가능
ls -l /run/containerd/containerd.sock   # 소켓 접근 = 노드 root 급 → 권한 최소 유지(root:root 660)
```

## 문제 4 — 노드 안전 업그레이드 (노드)
순서: drain -> kubeadm upgrade node -> kubelet 재시작 -> uncordon. 정답 명령: `solutions/node-upgrade.md`

## 정리
```bash
kubectl delete -f problem-1.yaml
```
