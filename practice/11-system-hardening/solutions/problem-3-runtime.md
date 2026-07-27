# 문제 3 정답 — 컨테이너 런타임 소켓 하드닝 (Docker 개념 + containerd 실습)

> ⚠️ **환경 주의:** 이 실습 클러스터는 런타임이 **containerd** 라 **Docker 데몬이 없다.**
> `docker` 그룹도 `/var/run/docker.sock` 도 존재하지 않으므로 **Docker 명령은 그대로는 실패**한다.
> → 시험은 Docker 로 물어볼 수 있으니 **개념+명령을 기억**하되, 우리 환경 실습은 **containerd 버전**으로 한다.

## 공통 개념 (시험에서 묻는 것)
런타임 소켓/그룹에 접근할 수 있으면 **사실상 노드 root**다. 소켓으로 호스트 파일시스템을
통째로 마운트한 특권 컨테이너를 띄울 수 있기 때문. 그래서 **소켓 접근을 최소 권한으로** 통제한다.

---

## A) Docker 기준 (시험 대비 · 이 환경에선 실행 불가)
```bash
# docker 그룹 멤버십 = 사실상 root → 불필요 사용자 제거
getent group docker            # ← grep 금지(부분매칭 위험). 정확히 그룹 멤버 확인
sudo gpasswd -d <user> docker  # 그룹에서 제거

# 소켓 권한 조이기
sudo chmod 660 /var/run/docker.sock
sudo chown root:docker /var/run/docker.sock
ls -l /var/run/docker.sock     # srw-rw---- (660) 확인

# 데몬 하드닝 /etc/docker/daemon.json  (있다면)
# { "icc": false, "no-new-privileges": true, "userns-remap": "default", "live-restore": true }
sudo systemctl restart docker
```

## B) containerd 기준 (우리 환경에서 실제 실습 가능)
```bash
# 1) 소켓 존재/권한 확인 — 이 소켓 접근 = 노드 root 급
ls -l /run/containerd/containerd.sock        # 기본 srw-rw---- root:root

# 2) 소켓에 접근 가능한 주체를 최소로 (root 전용 유지 확인)
sudo chmod 660 /run/containerd/containerd.sock
sudo chown root:root /run/containerd/containerd.sock

# 3) crictl 이 이 소켓을 쓰도록 설정돼 있는지 (/etc/crictl.yaml)
grep runtime-endpoint /etc/crictl.yaml       # unix:///run/containerd/containerd.sock
sudo crictl ps                               # 소켓으로 컨테이너 조회(권한 있어야 됨)

# 4) 설정 파일 하드닝 개념 — /etc/containerd/config.toml
#    · SystemdCgroup = true (cgroup 일관성)
#    · 불필요한 CRI 기능/권한 최소화, 신뢰 레지스트리만 허용
sudo systemctl restart containerd            # config 변경 시
```

## 검증
```bash
# Docker 환경:    ls -l /var/run/docker.sock          → 660(srw-rw----), 그룹에서 사용자 빠짐
# containerd 환경: ls -l /run/containerd/containerd.sock → root:root 660 유지
getent group docker    # (Docker 환경) 대상 사용자가 목록에 없어야
```

## 핵심 요약
- 원칙 하나: **런타임 소켓 접근 = root 권한** → 접근 주체·소켓 권한을 최소로.
- 도구만 다르다: Docker=`docker` 그룹/`docker.sock`, containerd=`containerd.sock`/`config.toml`.
- 사용자 제거 시 **`getent group <name>`** 사용(`grep` 부분매칭 함정 회피).
