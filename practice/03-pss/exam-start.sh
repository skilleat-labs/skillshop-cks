#!/usr/bin/env bash
# 시험 방식 실습 시작 (3강 PSS) — 매니페스트를 수정해서 apply 하는 형태로 연습한다.
#   1) 클러스터를 문제 초기 상태로 되돌리고
#   2) work/ 에 문제별 작업용 YAML 을 만든다 (원본 problem-*.yaml 은 보존)
# 다시 실행하면 초기화된다. (work/ 안의 내 작업도 덮어씀)
set -u
cd "$(dirname "$0")"

# 특정 kind(+name) 문서만 원본에서 추출
extract() { # $1=파일 $2=kind [$3=name]
  # kind/name 은 줄 시작에 앵커한다. 안 그러면 roleRef 안의 "kind: Role" 같은
  # 하위 필드까지 매칭돼 엉뚱한 문서가 딸려온다.
  awk -v k="$2" -v n="${3:-}" 'BEGIN{RS="---"}
    $0 ~ ("(^|\n)kind: " k "\n") {
      if (n=="" || $0 ~ ("(^|\n)  name: " n "\n")) { print "---"; print }
    }' "$1"
}
header() { # $1=번호 $2=파일명 $3=설명
  echo "# ============================================================"
  echo "# CKS 3강 실습 (시험 방식) — 문제 $1"
  echo "# $3"
  echo "#"
  echo "# 이 파일을 수정한 뒤:  kubectl apply -f work/$2"
  echo "# 검증:   README.md 의 문제 $1 검증 명령 참고"
  echo "# 초기화: ./exam-start.sh"
  echo "# ============================================================"
}

echo "==> 1. 클러스터를 문제 초기 상태로 초기화"
kubectl delete deploy web -n pss-ex1 --ignore-not-found >/dev/null 2>&1
kubectl delete deploy app -n pss-ex2 --ignore-not-found >/dev/null 2>&1
kubectl wait --for=delete pod -l app=web -n pss-ex1 --timeout=60s >/dev/null 2>&1
kubectl wait --for=delete pod -l app=app -n pss-ex2 --timeout=60s >/dev/null 2>&1
# 문제 2 로 붙였던 PSS 라벨 제거 (초기 상태 = 라벨 없음)
kubectl label ns pss-ex2 \
  pod-security.kubernetes.io/enforce- pod-security.kubernetes.io/warn- \
  pod-security.kubernetes.io/audit- >/dev/null 2>&1
for n in 1 2; do kubectl apply -f "problem-$n.yaml" >/dev/null; done
kubectl wait --for=condition=Ready pod -l app=app -n pss-ex2 --timeout=90s >/dev/null 2>&1
echo "   pss-ex1(web 은 restricted 위반이라 거부되는 게 정상), pss-ex2 재생성됨"

echo "==> 2. work/ 에 작업용 매니페스트 생성"
mkdir -p work

{ header 1 "q1-web.yaml" "ns pss-ex1 / deploy web — restricted 정책을 만족시켜 Running 시켜라"
  echo "# 힌트: restricted 4대 = runAsNonRoot / seccompProfile RuntimeDefault /"
  echo "#       allowPrivilegeEscalation false / capabilities drop ALL"
  echo "#       위치는 spec.template.spec (파드) 와 containers[] (컨테이너) 로 나뉜다."
  extract problem-1.yaml Deployment
} > work/q1-web.yaml
echo "   work/q1-web.yaml"

{ header 2 "q2-namespace.yaml" "ns pss-ex2 — restricted 를 enforce 하고 warn 도 켜라"
  echo "# 힌트: metadata.labels 에 pod-security.kubernetes.io/<모드>=<레벨> 형태로 추가."
  echo "#       (명령으로 하면: kubectl label ns pss-ex2 ...)"
  extract problem-2.yaml Namespace pss-ex2
} > work/q2-namespace.yaml
echo "   work/q2-namespace.yaml"

echo ""
echo "준비 완료. work/ 파일을 고쳐서 apply 하세요."
echo "  vim work/q1-web.yaml && kubectl apply -f work/q1-web.yaml"
echo "  kubectl get pods -n pss-ex1              # 문제1 검증: Running"
echo "  kubectl get ns pss-ex2 --show-labels     # 문제2 검증: enforce/warn 라벨"
