# CKS 모의고사 2회차 (7문제)

> 노드 작업 비중이 높은 회차(Audit·업그레이드·ImagePolicyWebhook·bom). 제한시간 목표 **90분**.
> 환경: k8s 1.32 / containerd / Cilium / 3노드.

## 준비
```bash
kubectl apply -f setup.yaml      # q1~q3 환경 생성
```

## ⚠️ 점수 누수 방지
- [ ] 컨텍스트/네임스페이스 확인  · [ ] 작업 후 검증  · [ ] 동사(delete/replace/scale) 정확
- [ ] 노드 매니페스트 수정 전 **백업**  · [ ] 서비스/유닛명 함정

---

## q1 · Cilium NetworkPolicy — mutual auth (배점 9) · ns `m2-cnp`, deploy `target`
**CiliumNetworkPolicy** 로 다음을 만족시켜라.
- `m2-cnp-client` 네임스페이스의 Pod → `target` 접근 허용
- 그 접근에는 **mutual authentication 필수**
- **host 접근은 mutual auth 없이** 허용
- 핵심 3가지: ① `kind: CiliumNetworkPolicy` ② `authentication.mode: "required"` ③ `fromEntities: [host]`(auth 블록 없음)
- 허용 문서: https://docs.cilium.io
> ⚠️ **enforcement 는 Cilium SPIRE(mutual auth 기능)가 켜져 있어야 실제 동작.** 현재 클러스터에 꺼져 있으면
> 정책 VALID 가 False 로 뜬다. `../../practice/05-networkpolicy/setup-mutual-auth.sh` 로 1회 활성화.
> (verify.sh 는 SPIRE 없이도 **정책 구조**는 채점한다.) 정답: `solutions/q1-cilium-mutualauth.yaml`

## q2 · SecurityContext — immutable 컨테이너 (배점 8) · ns `m2-sc`, deploy `worker`
`worker` 를 immutable 하게 만들어라.
- non-root 실행(예: `runAsUser: 30000`, `runAsNonRoot: true`)
- `readOnlyRootFilesystem: true`
- `allowPrivilegeEscalation: false`
- 모든 capability 제거 (`capabilities.drop: ["ALL"]`)
- 검증: `kubectl exec -n m2-sc deploy/worker -- id` (비-root), `-- touch /x` → Read-only

## q3 · SA 토큰 automount 비활성화 + projected volume (배점 8) · ns `m2-sa`, sa `robot`, deploy `app`
- SA `robot` 과 Pod `app` **둘 다** `automountServiceAccountToken: false`
- 대신 **projected volume** 으로 SA 토큰을 `/var/run/secrets/tokens` 에 **read-only** 로 수동 마운트
- 검증: `kubectl get sa robot -n m2-sa -o jsonpath='{.automountServiceAccountToken}'` → false

## q4 · Audit Logging (배점 8) · **노드(컨트롤플레인)**
`files/audit-policy.yaml` 를 노드로 복사 → `kube-apiserver.yaml` 에 audit 플래그 + hostPath 볼륨 추가.
- 로그 보존: 예) `--audit-log-maxbackup=2 --audit-log-maxage=7`
- ⚠️ 매니페스트 수정 전 백업. 정답: `solutions/q4-audit.md`

## q5 · bom — SPDX SBOM 생성 (배점 7) · **로컬/노드 CLI**
`nginx:1.18` 의 **SPDX SBOM** 을 생성해 파일로 저장하고, 특정 컴포넌트(예: `openssl`) 존재와 **버전**을 찾아라.
- **함정:** 여러 이미지를 `>>` 로 누적하면 SPDX 가 깨진다 → `--image` 플래그를 **반복** 사용.
- 정답: `solutions/q5-bom.md`

## q6 · 노드 안전 업그레이드 (배점 8) · **노드**
worker 노드가 패치 1버전 뒤처짐. 순서대로 업그레이드하라.
- `drain` → `kubeadm upgrade node` → kubelet/kubectl 업그레이드 → kubelet 재시작 → `uncordon`
- 정답: `solutions/q6-node-upgrade.md`

## q7 · ImagePolicyWebhook (배점 7) · **노드(컨트롤플레인)**
admission config 로 이미지 정책 웹훅을 구성하라.
- `defaultAllow: false` (웹훅 장애 시 이미지 **거부**)
- apiserver 에 `--admission-control-config-file` 연결 + 디렉터리 volume 마운트
- ⚠️ 매니페스트 수정 전 백업. 정답: `solutions/q7-imagepolicywebhook.md`

---

## 채점
```bash
bash verify.sh        # q1(구조)·q2·q3 라이브, q4·q6·q7 [MANUAL], q5 결과파일 확인
```
## 정리
```bash
../reset.sh
```
