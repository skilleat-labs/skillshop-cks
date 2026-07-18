// CKS 모의고사 2회차 PPT 생성 — 실행: node build-mock-2.js
const { buildExam } = require("../exam_deck");
const { BLUE } = require("../../../ppt-template/deck_lib");

buildExam({
  num: 2, count: 7, minutes: 90,
  subtitle: "Cilium mutual auth · SecurityContext · SA토큰 · Audit · bom · 노드업그레이드 · ImagePolicyWebhook",
  outFile: "mock-2.pptx",
  questions: [
    {
      title: "Cilium NetworkPolicy — mutual auth", points: 9, tag: "C", ctx: "ns m2-cnp · deploy target",
      tasks: [
        "CiliumNetworkPolicy 로: m2-cnp-client Pod → target 접근 허용.",
        "그 접근에는 mutual authentication 필수.",
        "host 접근은 mutual auth 없이 허용 (fromEntities: host).",
        "핵심: kind CiliumNetworkPolicy · authentication.mode required · fromEntities host",
      ],
      verify: ["$ kubectl get cnp target-mutual-auth -n m2-cnp -o yaml", { t: "# enforcement 는 SPIRE 활성 필요", c: BLUE }],
    },
    {
      title: "SecurityContext — immutable 컨테이너", points: 8, tag: "C", ctx: "ns m2-sc · deploy worker",
      tasks: [
        "non-root 실행 (runAsUser 30000, runAsNonRoot true).",
        "readOnlyRootFilesystem: true.",
        "allowPrivilegeEscalation: false + capabilities drop ALL.",
      ],
      verify: [
        "$ kubectl exec -n m2-sc deploy/worker -- id      # 비-root",
        "$ kubectl exec -n m2-sc deploy/worker -- touch /x  # Read-only",
      ],
    },
    {
      title: "SA 토큰 automount 비활성화 + projected volume", points: 8, tag: "C", ctx: "ns m2-sa · sa robot",
      tasks: [
        "SA robot 과 Pod app 둘 다 automountServiceAccountToken: false.",
        "대신 projected volume 으로 토큰을 /var/run/secrets/tokens 에 read-only 마운트.",
      ],
      verify: ["$ kubectl get sa robot -n m2-sa -o jsonpath='{.automountServiceAccountToken}'", { t: "# false", c: BLUE }],
    },
    {
      title: "Audit Logging", points: 8, tag: "N", ctx: "노드 · 컨트롤플레인",
      tasks: [
        "audit-policy.yaml 를 노드로 복사 → apiserver 에 audit 플래그.",
        "로그 보존: --audit-log-maxbackup=2 --audit-log-maxage=7 등.",
        "volumeMounts + volumes(hostPath) 세트로 (하나라도 빠지면 apiserver 기동 실패).",
      ],
      verify: ["$ sudo tail -1 /var/log/kubernetes/audit.log", { t: "# JSON 요청 로그", c: BLUE }],
    },
    {
      title: "bom — SPDX SBOM 생성", points: 7, tag: "N", ctx: "로컬/노드 CLI",
      tasks: [
        "nginx:1.18 의 SPDX SBOM 을 생성해 파일로 저장.",
        "특정 컴포넌트(예: openssl) 존재와 버전을 찾아라.",
        "함정: 여러 이미지는 --image 플래그를 반복 (>> 누적 금지).",
      ],
      verify: ["$ bom generate --image nginx:1.18 --output /tmp/m2-sbom.spdx", "$ grep -i -A2 'PackageName: .*openssl' /tmp/m2-sbom.spdx"],
    },
    {
      title: "노드 안전 업그레이드 (kubeadm)", points: 8, tag: "N", ctx: "노드",
      tasks: [
        "worker 노드가 패치 1버전 뒤처짐.",
        "drain → kubeadm upgrade node → kubelet/kubectl 업그레이드 → 재시작 → uncordon.",
        "함정: control-plane 은 upgrade apply, worker 는 upgrade node.",
      ],
      verify: ["$ kubectl drain <node> --ignore-daemonsets --delete-emptydir-data", "$ kubeadm upgrade node"],
    },
    {
      title: "ImagePolicyWebhook", points: 7, tag: "N", ctx: "노드 · 컨트롤플레인",
      tasks: [
        "admission config 로 이미지 정책 웹훅 구성.",
        "defaultAllow: false (웹훅 장애 시 이미지 거부).",
        "apiserver 에 --admission-control-config-file + 디렉터리 volume 마운트.",
      ],
      verify: ["$ grep -E 'ImagePolicyWebhook|admission-control-config-file' /etc/kubernetes/manifests/kube-apiserver.yaml"],
    },
  ],
});
