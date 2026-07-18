# CKS 모의고사 (3회차)

기존 `practice/`(개념 1개씩 익히기)와 달리, **실제 시험처럼 여러 도메인이 섞인 6~7문제 세트**를
회차별로 풀어보는 실전 모의고사입니다. 노션 "실제 출제된 문제 정리"(본인 58점 복기 + Reddit 80점
합격자 16문제 + 후기 교차확인)를 기반으로 재출제 확률 높은 유형(S등급) 위주로 구성했습니다.

> 환경 전제: **k8s 1.32 / containerd / Cilium / 3노드** (구축 가이드와 동일).
> ingress-nginx 설치 필요(TLS 문제). Istio·Cilium mutual auth 는 별도 설치/활성 필요(해당 문제에 안내).

## 회차 구성
| 회차 | 문제 수 | 주요 주제 | 라이브 채점 |
|------|--------|----------|------------|
| [mock-1](mock-1/README.md) | 7 | PSS·NetworkPolicy·TLS Ingress·RBAC·Falco·apiserver·trivy | q1~q4 |
| [mock-2](mock-2/README.md) | 7 | Cilium mutual auth·SecurityContext·SA토큰·Audit·bom·노드업그레이드·ImagePolicyWebhook | q1(구조)·q2·q3 |
| [mock-3](mock-3/README.md) | 6 | Istio mTLS·Secrets암호화·PSS·TLS Secret·kubelet·Falco(dev/mem) | q3·q4·q6 |

**표기:** (C) 클러스터 리소스=라이브 자동채점 / (N) 노드 작업=verify.sh 가 수동 점검 명령 안내 / (I) Istio=검증 생략

## 사용법 (회차별)
```bash
cd mock-1
kubectl apply -f setup.yaml     # 문제 환경 생성
# ... README.md 의 문제를 직접 풀기 ...
bash verify.sh                  # 자동 채점 (C 문제 PASS/FAIL, N 문제 MANUAL 안내)
cat solutions/qN-*.md           # 막히면 정답 확인
```

## 전체 정리
```bash
./reset.sh      # m1-* m2-* m3-* 네임스페이스 + 관련 리소스 일괄 삭제
```

## 노드 문제 안내
`kubelet/apiserver/audit/falco/kubelet/secrets암호화` 같은 노드 작업은 SSH 로 노드에 들어가 수정합니다.
verify.sh 는 이 문제들을 `[MANUAL]` 로 표시하고 점검 명령을 출력합니다.
⚠️ 노드의 `/etc/kubernetes/manifests/*.yaml` 수정 전에는 **반드시 백업**하세요.

## 사전 설치가 필요한 문제
- **TLS Ingress (mock-1 q3, mock-3 q4):** ingress-nginx 컨트롤러 → `../practice/06-tls/setup-ingress-nginx.sh`
- **Cilium mutual auth (mock-2 q1):** SPIRE 활성화 → `../practice/05-networkpolicy/setup-mutual-auth.sh`
- **Istio mTLS (mock-3 q1):** istioctl 설치 → `mock-3/solutions/q1-istio-mtls.md`

## PPT (시험지)
각 회차 폴더의 `mock-N.pptx` 는 문제만 담은 "시험지"입니다(정답은 `solutions/` 에만).
`build-mock-N.js` 로 다시 생성할 수 있습니다: `node build-mock-N.js`.
> PPT 는 `.gitignore` 로 git 에 올리지 않습니다(로컬 전용). 예제·정답·verify 만 커밋됩니다.

## 점수 누수 방지 (노션 4장 — 매 문제 습관)
- [ ] 컨텍스트/네임스페이스 확인 (`kubectl config current-context`, `-n`)
- [ ] 작업 후 **검증 명령** 실행 (검증 생략이 최대 누수)
- [ ] 문제 동사 정확히: delete / replace / scale
- [ ] 서비스/유닛명 함정 (`falco` ❌ → `falco-modern-bpf` ✅)
- [ ] `getent group <name>` (grep 부분매칭 위험 회피)
