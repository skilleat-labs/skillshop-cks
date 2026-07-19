#!/usr/bin/env bash
# 시험 방식 실습 시작 — "매니페스트 파일을 수정해서 배포하라" 형태로 연습한다.
#
#   1) 클러스터를 문제 초기 상태로 되돌리고
#   2) work/ 에 문제별 작업용 YAML 을 만들어 준다 (원본 problem-*.yaml 은 건드리지 않음)
#
# 다시 실행하면 언제든 초기화된다. (work/ 안의 내 작업도 원본으로 덮어씀 — 주의)
set -u
cd "$(dirname "$0")"

echo "==> 1. 클러스터를 문제 초기 상태로 초기화"
kubectl delete deploy api    -n sc-ex1 --ignore-not-found >/dev/null 2>&1
kubectl delete deploy worker -n sc-ex2 --ignore-not-found >/dev/null 2>&1
kubectl delete deploy writer -n sc-ex3 --ignore-not-found >/dev/null 2>&1

# 이전 파드가 완전히 사라질 때까지 대기 —
# 안 기다리면 종료 중인 옛 파드에 exec 이 붙어서 verify.sh 가 오채점된다.
kubectl wait --for=delete pod -l app=api    -n sc-ex1 --timeout=60s >/dev/null 2>&1
kubectl wait --for=delete pod -l app=worker -n sc-ex2 --timeout=60s >/dev/null 2>&1
kubectl wait --for=delete pod -l app=writer -n sc-ex3 --timeout=60s >/dev/null 2>&1

for n in 1 2 3; do kubectl apply -f "problem-$n.yaml" >/dev/null; done

# 새 파드가 뜰 때까지 대기 (문제 3 writer 는 의도적으로 CrashLoop 이라 제외)
kubectl wait --for=condition=Ready pod -l app=api    -n sc-ex1 --timeout=90s >/dev/null 2>&1
kubectl wait --for=condition=Ready pod -l app=worker -n sc-ex2 --timeout=90s >/dev/null 2>&1
echo "   sc-ex1/api, sc-ex2/worker, sc-ex3/writer 재생성됨 (writer 는 CrashLoop 이 정상)"

echo "==> 2. work/ 에 작업용 매니페스트 생성"
mkdir -p work
make_work() {   # $1=번호  $2=파일명  $3=문제설명
  {
    echo "# ============================================================"
    echo "# CKS 실습 (시험 방식) — 문제 $1"
    echo "# $3"
    echo "#"
    echo "# 이 파일을 직접 수정한 뒤 배포하세요:"
    echo "#     kubectl apply -f work/$2"
    echo "# 채점:  bash verify.sh"
    echo "# 초기화: ./exam-start.sh   (이 파일이 원본으로 덮어써집니다)"
    echo "# ============================================================"
    # 원본에서 Namespace 문서는 빼고 워크로드만 준다 (시험처럼 ns 는 이미 존재)
    awk 'BEGIN{RS="---"} /kind: Deployment/{print "---"; print}' "problem-$1.yaml"
  } > "work/$2"
  echo "   work/$2"
}
make_work 1 q1-api.yaml    "ns sc-ex1 / deploy api — UID 10001 non-root 로 실행되게 하라"
make_work 2 q2-worker.yaml "ns sc-ex2 / deploy worker — 루트FS 읽기전용 + 권한상승 금지 + 모든 capability 제거"
make_work 3 q3-writer.yaml "ns sc-ex3 / deploy writer — readOnlyRootFilesystem 유지한 채 CrashLoop 해결(/data 쓰기 가능하게)"

echo ""
echo "준비 완료. 이제 work/ 안의 파일을 고쳐서 apply 하세요."
echo "  vim work/q1-api.yaml && kubectl apply -f work/q1-api.yaml"
echo "  bash verify.sh"
