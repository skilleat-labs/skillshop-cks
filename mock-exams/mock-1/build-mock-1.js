// CKS 모의고사 1회차 PPT 생성 — 실행: node build-mock-1.js
const { buildExam } = require("../exam_deck");
const { BLUE } = require("../../../ppt-template/deck_lib");

buildExam({
  num: 1, count: 7, minutes: 90,
  subtitle: "PSS · NetworkPolicy · TLS Ingress · RBAC · Falco · apiserver · trivy",
  outFile: "mock-1.pptx",
  questions: [
    {
      title: "Restricted PSS — Deployment 수정", points: 8, tag: "C", ctx: "ns m1-pss · deploy web",
      tasks: [
        "ns m1-pss 는 enforce=restricted — web 파드가 거부되어 뜨지 않는다.",
        "web Deployment 를 restricted 정책에 맞게 수정해 Running 시켜라.",
        "restricted 4대: runAsNonRoot · seccompProfile RuntimeDefault · allowPrivilegeEscalation false · capabilities drop ALL",
      ],
      verify: ["$ kubectl get pods -n m1-pss", { t: "# web-... Running 이면 성공", c: BLUE }],
    },
    {
      title: "NetworkPolicy — deny-all + DNS + 특정 ns 허용", points: 9, tag: "C", ctx: "ns m1-netpol",
      tasks: [
        "기본은 모든 ingress 차단(deny-all).",
        "team=trusted 라벨 ns(m1-netpol-client) 의 Pod → db 만 허용.",
        "Pod 들이 DNS 쓰도록 egress 53(UDP/TCP) 허용.",
      ],
      verify: [
        "$ kubectl exec -n m1-netpol-client deploy/client -- wget -qO- --timeout=3 http://db.m1-netpol",
        { t: "# 응답 O", c: BLUE },
        "$ kubectl exec -n m1-netpol deploy/intruder -- wget -qO- --timeout=3 http://db",
        { t: "# timeout (차단)", c: BLUE },
      ],
    },
    {
      title: "TLS Ingress — ssl-redirect + tls 블록", points: 8, tag: "C", ctx: "ns m1-tls · ingress shop",
      tasks: [
        "자체서명 인증서(CN=shop.m1.example.com)로 TLS Secret shop-tls 생성.",
        "Ingress 에 tls 블록(host + secretName shop-tls) 추가.",
        "HTTP→HTTPS 강제: nginx.ingress.kubernetes.io/ssl-redirect: \"true\"",
      ],
      verify: ["$ kubectl get ingress shop -n m1-tls -o yaml", { t: "# tls + ssl-redirect 어노테이션 확인", c: BLUE }],
    },
    {
      title: "RBAC — 위험한 ClusterRoleBinding 제거", points: 7, tag: "C", ctx: "ns m1-rbac · sa ci-bot",
      tasks: [
        "ci-bot 이 ClusterRoleBinding 으로 클러스터 전역 cluster-admin 을 가진다.",
        "시스템 기본 바인딩은 두고, SA 에 붙은 위험한 것만 찾아 삭제하라.",
      ],
      verify: [
        "$ kubectl get clusterrolebindings -o wide | grep cluster-admin",
        "$ kubectl auth can-i '*' '*' --as=system:serviceaccount:m1-rbac:ci-bot",
        { t: "# yes → (삭제) → no", c: BLUE },
      ],
    },
    {
      title: "Falco — 컨테이너 셸 실행 탐지 룰", points: 8, tag: "N", ctx: "노드 · /etc/falco/",
      tasks: [
        "컨테이너 안에서 sh/bash 실행 시 Warning 을 남기는 커스텀 룰 작성.",
        "/etc/falco/falco_rules.local.yaml 에 추가 (기본 룰 파일은 수정 금지).",
        "함정: 서비스명은 falco 가 아니라 보통 falco-modern-bpf.",
      ],
      verify: [
        "$ systemctl list-units 'falco*'          # 유닛명 먼저",
        "$ sudo journalctl -fu falco-modern-bpf | grep -i 'Shell spawned'",
      ],
    },
    {
      title: "kube-apiserver — 익명 접근 차단", points: 7, tag: "N", ctx: "노드 · 컨트롤플레인",
      tasks: [
        "kube-apiserver.yaml 에 --anonymous-auth=false",
        "--authorization-mode=Node,RBAC + NodeRestriction admission 활성",
        "수정 전 반드시 백업. static pod 라 저장 시 자동 재기동.",
      ],
      verify: ["$ curl -sk https://localhost:6443/api", { t: "# Unauthorized(401) 이어야 성공", c: BLUE }],
    },
    {
      title: "이미지 취약점 스캔 (trivy)", points: 7, tag: "C", ctx: "로컬 CLI",
      tasks: [
        "nginx:1.18 의 HIGH·CRITICAL 취약점을 스캔.",
        "결과를 /tmp/m1-scan.json 에 저장.",
        "함정: SBOM 생성(bom) 아님 — 스캔은 trivy image.",
      ],
      verify: ["$ trivy image --severity HIGH,CRITICAL --format json -o /tmp/m1-scan.json nginx:1.18"],
    },
  ],
});
