# CKS 실습 문제 모음 (강의별)

스킬샵 본체와 분리된, **시험처럼 군더더기 없는** 실습 세트입니다.
각 폴더에서 `start.yaml` 적용 → `README.md`의 문제를 직접 풀기 → 검증 → `solutions/`로 확인.

| 폴더 | 주제 | 형태 |
| --- | --- | --- |
| `02-securitycontext` | SecurityContext / immutable | 네임스페이스 YAML |
| `03-pss` | Pod Security Standards | 네임스페이스 YAML |
| `04-rbac` | RBAC + ServiceAccount | 네임스페이스 YAML |
| `05-networkpolicy` | NetworkPolicy (CNI 필요) | 네임스페이스 YAML |
| `06-tls` | TLS + Ingress (ingress-nginx 필요) | 네임스페이스 YAML |
| `07-cluster-hardening` | kubelet·etcd·apiserver | **노드 작업** |
| `08-audit-logging` | Audit | **노드 작업** |
| `09-supply-chain` | Trivy·Dockerfile·Admission | 로컬+노드 |
| `10-falco` | 런타임 탐지·대응 | 노드 + 워크로드 |
| `11-system-hardening` | seccomp·AppArmor·Docker·노드 업그레이드 | YAML + 노드 |

> 네임스페이스형은 NetworkPolicy(05)·Ingress(06) 빼면 어느 클러스터에서나 바로 됩니다.
> 노드형(07·08·10·11 일부)은 컨트롤플레인/워커 노드에 SSH로 들어가 진행하고, **수정 전 백업**을 꼭 하세요.
