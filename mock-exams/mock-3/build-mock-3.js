// CKS 모의고사 3회차 PPT 생성 — 실행: node build-mock-3.js
const { buildExam } = require("../exam_deck");
const { BLUE } = require("../../../ppt-template/deck_lib");

buildExam({
  num: 3, count: 6, minutes: 75,
  subtitle: "Istio mTLS · Secrets 암호화 · PSS · TLS Secret · kubelet · Falco(dev/mem)",
  outFile: "mock-3.pptx",
  questions: [
    {
      title: "Istio mTLS — STRICT PeerAuthentication", points: 10, tag: "I", ctx: "ns m3-istio",
      tasks: [
        "m3-istio 워크로드 간 통신을 mTLS STRICT 로 강제.",
        "① ns 에 istio-injection=enabled  ② 기존 Pod rollout restart  ③ PeerAuthentication STRICT.",
        "함정: istio-system 적용=mesh 전체 / 특정 ns 적용=스코프 한정.",
      ],
      verify: ["$ kubectl get peerauthentication -n m3-istio", { t: "# Istio 설치 환경에서만 검증", c: BLUE }],
    },
    {
      title: "Secrets 암호화 at rest", points: 9, tag: "N", ctx: "노드 · 컨트롤플레인",
      tasks: [
        "EncryptionConfiguration 으로 etcd 저장 시 secret 암호화.",
        "apiserver --encryption-provider-config + hostPath 볼륨.",
        "기존 secret 재암호화: kubectl get secrets -A -o json | kubectl replace -f -",
      ],
      verify: ["$ grep encryption-provider-config /etc/kubernetes/manifests/kube-apiserver.yaml"],
    },
    {
      title: "PSS 네임스페이스 강제", points: 7, tag: "C", ctx: "ns m3-pss",
      tasks: [
        "m3-pss 에 restricted 를 enforce 하고 warn 도 켜라.",
        "라벨: pod-security.kubernetes.io/enforce=restricted, warn=restricted",
      ],
      verify: ["$ kubectl label ns m3-pss pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/warn=restricted", "$ kubectl get ns m3-pss --show-labels"],
    },
    {
      title: "참조된 secretName 에 맞춰 TLS Secret 생성", points: 8, tag: "C", ctx: "ns m3-tls · ingress api",
      tasks: [
        "api Ingress 에 이미 tls.secretName: api-tls 가 지정됐는데 그 Secret 이 없다.",
        "Ingress 는 건드리지 말고, api-tls 라는 정확히 같은 이름으로 TLS Secret 생성.",
        "CN=api.m3.example.com",
      ],
      verify: ["$ kubectl get ingress api -n m3-tls -o jsonpath='{.spec.tls[0].secretName}'", { t: "# 이름 먼저 확인 후 create secret tls", c: BLUE }],
    },
    {
      title: "kubelet 하드닝", points: 8, tag: "N", ctx: "노드 · 워커",
      tasks: [
        "/var/lib/kubelet/config.yaml 에서 authentication.anonymous.enabled: false",
        "authorization.mode: Webhook · readOnlyPort: 0",
        "적용 후 sudo systemctl restart kubelet.",
      ],
      verify: ["$ curl -sk https://<노드IP>:10250/pods   # Unauthorized", "$ curl -s http://<노드IP>:10255/pods    # 거부/무응답"],
    },
    {
      title: "Falco /dev/mem 탐지 + 대응", points: 8, tag: "C", ctx: "룰=노드 / 대응=클러스터 · ns m3-falco",
      tasks: [
        "① /dev/mem 접근을 탐지하는 커스텀 Falco 룰 작성(노드) → 문제 Pod 식별.",
        "② 악성 워크로드를 멈춰라 — Pod 직접 삭제 금지(재생성됨).",
        "Deployment 를 replicas: 0 으로 스케일.",
      ],
      verify: ["$ kubectl scale deploy/suspicious -n m3-falco --replicas=0", "$ kubectl get pods -n m3-falco   # 파드 사라짐"],
    },
  ],
});
