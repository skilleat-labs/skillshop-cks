# 실습 검토 — 보류(나중에 진행할 것)

VM(구축 가이드: **Kubernetes 1.32 / Ubuntu 22.04 / containerd / Cilium**) 기준 전체 검토 결과 중,
**아직 안 고친 항목**만 여기 기록. (노랑·사소한 항목은 이미 각 README 에 반영 완료)

---

## 🔴 11강 문제 3 — Docker 데몬 하드닝이 containerd 환경과 불일치 (보류)

**파일:** `practice/11-system-hardening/README.md` — "문제 3 — Docker 데몬 (노드)"

**현재 내용:**
```bash
sudo gpasswd -d <user> docker
sudo chmod 660 /var/run/docker.sock     # 확인: ls -l /var/run/docker.sock -> srw-rw----
```

**문제점:**
- 구축 가이드는 런타임이 **containerd** 다. 이 VM 에는 **Docker 데몬이 없다.**
- 따라서 `docker` 그룹도, `/var/run/docker.sock` 파일도 존재하지 않음 → 위 명령이 그대로는 **실패**한다.
- 학생이 문제 3 을 이 환경에서 실습할 수 없음.

**결정해야 할 방향(택1):**
1. **이론/시험대비용으로 명시** — "이 환경은 containerd 라 Docker 소켓이 없다. 이 문제는 Docker 사용 클러스터 대비용 개념 학습" 이라고 README 에 캡션 추가. (가장 간단, 실습은 스킵)
2. **containerd 대체 과제로 교체** — 예: `/run/containerd/containerd.sock` 권한 확인, `/etc/containerd/config.toml` 하드닝(`SystemdCgroup=true`, 불필요 CRI 비활성 등), containerd 소켓 접근 통제.
3. **둘 다** — 개념(문제 원문)은 남기고 containerd 실습 버전을 별도 문제로 추가.

> 추천: 3번(개념 + containerd 실습). CKS 시험 자체는 컨테이너 런타임 하드닝 개념을 묻지만,
> 자가 실습 환경(containerd)에서 손으로 해볼 수 있는 대체 과제가 있으면 학습 효과가 큼.

**작업 시 함께 볼 것:** `practice/11-system-hardening/solutions/` (문제 3 정답 파일이 있으면 같이 수정)
