# 11강 실습 — System Hardening

문제 1 은 네임스페이스 YAML, 나머지는 노드 작업입니다.

```bash
kubectl apply -f start.yaml
```

## 문제 1 — seccomp 적용 · ns `sys-ex`, deploy `app` (YAML)
`app` 에 컨테이너 런타임 기본 seccomp 프로파일을 적용하라. (`seccompProfile.type: RuntimeDefault`)
정답: `solutions/problem-1.yaml`

검증:
```bash
kubectl get deploy app -n sys-ex \
  -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}'; echo   # RuntimeDefault
```

## 문제 2 — AppArmor (노드)
노드 `/etc/apparmor.d/` 에 프로파일을 로드(`apparmor_parser`)한 뒤, Pod 에 지정한다.
- 최신: `securityContext.appArmorProfile: { type: Localhost, localhostProfile: <이름> }`
- 구버전: `container.apparmor.security.beta.kubernetes.io/<container>: localhost/<이름>` 어노테이션
주의: 프로파일이 **해당 노드에 먼저 로드**돼 있어야 Pod 가 스케줄됨.

## 문제 3 — Docker 데몬 (노드)
- `sudo gpasswd -d <user> docker` (일반 유저를 docker 그룹에서 제거 — docker 그룹은 사실상 root)
- `sudo chmod 660 /var/run/docker.sock`

검증: `ls -l /var/run/docker.sock`  → `srw-rw----`

## 문제 4 — 노드 안전 업그레이드 (노드)
순서: `drain → kubeadm upgrade node → kubelet 재시작 → uncordon`
정답 명령: `solutions/node-upgrade.md`

## 정리
```bash
kubectl delete -f start.yaml
```
