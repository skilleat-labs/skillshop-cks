# 실습 검토 — 보류(나중에 진행할 것)

VM(구축 가이드: **Kubernetes 1.32 / Ubuntu 22.04 / containerd / Cilium**) 기준 전체 검토 결과 중,
**아직 안 고친 항목**만 여기 기록. (노랑·사소한 항목은 이미 각 README 에 반영 완료)

---

## ✅ 11강 문제 3 — Docker 데몬 하드닝 containerd 불일치 (해결됨)

**해결(택3 채택 — 개념 유지 + containerd 실습 추가):**
- `README.md` 문제 3: 제목을 "컨테이너 런타임 소켓 하드닝"으로, containerd 환경 경고 캡션 + (A)Docker 개념 / (B)containerd 실습 명령 병기.
- 신규 정답 파일: `solutions/problem-3-runtime.md` (Docker 개념 + containerd 소켓/`config.toml` 하드닝 대체과제).
- 신규 정답 파일: `solutions/problem-2-apparmor.md` (프로파일 로드 절차 + 1.32 `appArmorProfile` 필드 완성형 Pod YAML).
- PPT(`labs/11-system-hardening-lab.pptx`) 문제 3 노트는 이미 containerd 안내 반영 완료.

---

_(현재 열린 보류 항목 없음)_
