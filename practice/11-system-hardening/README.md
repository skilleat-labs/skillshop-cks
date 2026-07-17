# 11강 실습 — System Hardening

문제 1 은 네임스페이스 YAML, 문제 2~4 는 노드 작업입니다.

```bash
kubectl apply -f problem-1.yaml
```

## 문제 1 — seccomp 적용 · ns `sys-ex`, deploy `app` (YAML)
`app` 에 `seccompProfile.type: RuntimeDefault` 를 적용하라. 정답: `solutions/problem-1.yaml`
```bash
kubectl get deploy app -n sys-ex -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}'   # RuntimeDefault
```

## 문제 2 — AppArmor (노드)
노드 `/etc/apparmor.d/` 에 프로파일 로드(`apparmor_parser`) 후 Pod 에 지정. 프로파일은 해당 노드에 먼저 로드돼야 스케줄됨.
> Pod 지정 방식: 이 환경은 **k8s 1.32** 라 `securityContext.appArmorProfile`(type: `Localhost`, localhostProfile: `<프로파일명>`) **필드**를 씁니다.
> (구버전 `container.apparmor.security.beta.kubernetes.io/<컨테이너>` **annotation** 방식은 1.30 에서 deprecated → 1.32 에선 필드 방식 권장)

## 문제 3 — Docker 데몬 (노드)
```bash
sudo gpasswd -d <user> docker
sudo chmod 660 /var/run/docker.sock     # 확인: ls -l /var/run/docker.sock -> srw-rw----
```

## 문제 4 — 노드 안전 업그레이드 (노드)
순서: drain -> kubeadm upgrade node -> kubelet 재시작 -> uncordon. 정답 명령: `solutions/node-upgrade.md`

## 정리
```bash
kubectl delete -f problem-1.yaml
```
