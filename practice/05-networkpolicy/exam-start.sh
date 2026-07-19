#!/usr/bin/env bash
# 시험 방식 실습 시작 (5강 NetworkPolicy)
#   1) 클러스터를 문제 초기 상태로 되돌리고
#   2) work/ 에 작업용 YAML 을 만든다 (원본 problem-*.yaml 은 보존)
#
# 5강은 세 문제 모두 [생성] 유형이다. 정책을 "새로 작성"하는 게 문제이므로
# work 파일은 요구사항만 적힌 빈 파일로 준다. (환경 파드는 클러스터에 이미 떠 있음)
set -u
cd "$(dirname "$0")"

header() { # $1=번호 $2=파일명 $3=설명
  echo "# ============================================================"
  echo "# CKS 5강 실습 (시험 방식) — 문제 $1  [생성]"
  echo "# $3"
  echo "#"
  echo "# 아래에 정책을 직접 작성한 뒤:  kubectl apply -f work/$2"
  echo "# 검증:   README.md 의 문제 $1 검증 명령 (wget 으로 통신 확인)"
  echo "# 초기화: ./exam-start.sh"
  echo "# ============================================================"
}

echo "==> 1. 클러스터를 문제 초기 상태로 초기화"
# 학생이 만든 정책 제거 (이게 남아 있으면 다음 실습이 오염된다)
kubectl delete networkpolicy --all -n netpol-ex1 --ignore-not-found >/dev/null 2>&1
kubectl delete networkpolicy --all -n netpol-ex2 --ignore-not-found >/dev/null 2>&1
kubectl delete cnp --all -n cnp-ex --ignore-not-found >/dev/null 2>&1
for n in 1 2 3; do kubectl apply -f "problem-$n.yaml" >/dev/null 2>&1; done
kubectl wait --for=condition=Ready pod -l app=db       -n netpol-ex1 --timeout=90s >/dev/null 2>&1
kubectl wait --for=condition=Ready pod -l app=tester   -n netpol-ex2 --timeout=90s >/dev/null 2>&1
kubectl wait --for=condition=Ready pod -l app=target   -n cnp-ex     --timeout=90s >/dev/null 2>&1
echo "   netpol-ex1 / netpol-ex2 / cnp-ex 재생성됨 (정책은 전부 삭제 = 통신 다 열린 상태)"

echo "==> 2. work/ 에 작업용 매니페스트 생성"
mkdir -p work

{ header 1 "q1-netpol.yaml" "ns netpol-ex1 — db 는 app=web 에서 오는 것만 허용하고 나머지는 차단하라"
  echo "# 힌트: podSelector 로 대상(db)을 고르고, ingress.from.podSelector 로 출발지를 제한한다."
  echo "#       kubectl explain networkpolicy.spec.ingress --recursive"
  echo ""
} > work/q1-netpol.yaml
echo "   work/q1-netpol.yaml"

{ header 2 "q2-netpol.yaml" "ns netpol-ex2 — deny-all(Ingress+Egress) 후 DNS(53)만 허용하라"
  echo "# 힌트: 정책 두 개로 나눠 쓰면 쉽다. ① podSelector {} 로 전체 deny"
  echo "#       ② egress 로 UDP/TCP 53 만 허용. (DNS 를 막으면 이름 해석이 죽는다)"
  echo ""
} > work/q2-netpol.yaml
echo "   work/q2-netpol.yaml"

{ header 3 "q3-cnp.yaml" "ns cnp-ex / deploy target — CiliumNetworkPolicy 로 mutual auth 를 요구하라"
  echo "# 요구사항: ① cnp-client 네임스페이스의 Pod → target 접근 허용"
  echo "#           ② 그 접근에는 mutual authentication 필수"
  echo "#           ③ host 접근은 mutual auth 없이 허용"
  echo "# 핵심 3가지: kind: CiliumNetworkPolicy / authentication.mode: \"required\" / fromEntities: [host]"
  echo "# 라벨 매칭은 k8s:io.kubernetes.pod.namespace 사용. 허용문서: https://docs.cilium.io"
  echo "# ⚠️ enforcement 는 SPIRE 활성 필요 → ./setup-mutual-auth.sh (클러스터당 1회)"
  echo ""
} > work/q3-cnp.yaml
echo "   work/q3-cnp.yaml"

echo ""
echo "준비 완료. work/ 파일에 정책을 작성한 뒤 apply 하세요."
echo "  vim work/q1-netpol.yaml && kubectl apply -f work/q1-netpol.yaml"
echo "  kubectl exec -n netpol-ex1 deploy/attacker -- wget -qO- --timeout=3 http://db   # 차단되면 성공"
