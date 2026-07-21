#!/usr/bin/env bash
# 시험 방식 실습 시작 (4강 RBAC)
#   1) 클러스터를 문제 초기 상태로 되돌리고
#   2) work/ 에 작업용 YAML 을 만든다 (원본 problem-*.yaml 은 보존)
#
# 문제 성격이 세 가지라 work 파일도 다르게 준다:
#   [수정] 기존 매니페스트를 고쳐서 apply   → 원본 매니페스트를 그대로 제공 (q1, q3)
#   [생성] 새 리소스를 만들어라             → 요구사항만 적힌 빈 파일 제공 (q2, q5)
#   [삭제] 위험한 바인딩을 지워라           → 파일 없음. kubectl delete 로 푼다 (q4, q6)
set -u
cd "$(dirname "$0")"
# ── 힌트 게이트 ────────────────────────────────────────────────
# 기본은 힌트 없이 생성한다. 실제 시험도 필드 목록을 알려주지 않으므로,
# 스스로 떠올리는 연습(recall)이 되도록 하기 위함이다.
# 막히면:  ./exam-start.sh --hints   (힌트를 넣어 다시 생성)
HINTS=0
[ "${1:-}" = "--hints" ] && HINTS=1
hint() { [ "$HINTS" = "1" ] && printf '%s\n' "$@"; return 0; }

extract() { # $1=파일 $2=kind [$3=name]
  # kind/name 은 줄 시작에 앵커한다. 안 그러면 roleRef 안의 "kind: Role" 같은
  # 하위 필드까지 매칭돼 엉뚱한 문서가 딸려온다.
  awk -v k="$2" -v n="${3:-}" 'BEGIN{RS="---"}
    $0 ~ ("(^|\n)kind: " k "\n") {
      if (n=="" || $0 ~ ("(^|\n)  name: " n "\n")) { print "---"; print }
    }' "$1"
}
header() { # $1=번호 $2=파일명 $3=설명 $4=유형
  echo "# ============================================================"
  echo "# CKS 4강 실습 (시험 방식) — 문제 $1  [$4]"
  echo "# $3"
  echo "#"
  echo "# 적용:   kubectl apply -f work/$2"
  echo "# 채점:   bash verify.sh"
  echo "# 초기화: ./exam-start.sh"
  [ "$HINTS" = "1" ] || echo "# 막히면: ./exam-start.sh --hints  ·  정답: solutions/"
  echo "# ============================================================"
}

echo "==> 1. 클러스터를 문제 초기 상태로 초기화"
kubectl delete deploy client -n rbac-ex3 --ignore-not-found >/dev/null 2>&1
kubectl wait --for=delete pod -l app=client -n rbac-ex3 --timeout=60s >/dev/null 2>&1
# 학생이 만들었을 수 있는 리소스 정리 (q2, q5)
kubectl delete role pod-viewer -n rbac-ex2 --ignore-not-found >/dev/null 2>&1
kubectl delete rolebinding reader-rb -n rbac-ex2 --ignore-not-found >/dev/null 2>&1
kubectl delete clusterrole node-reader --ignore-not-found >/dev/null 2>&1
kubectl delete clusterrolebinding inspector-nodes --ignore-not-found >/dev/null 2>&1
# q1 Role 을 와일드카드로, q4/q6 위험한 바인딩을 다시 살려둔다
for n in 1 2 3 4 5 6; do kubectl apply -f "problem-$n.yaml" >/dev/null; done
kubectl wait --for=condition=Ready pod -l app=client -n rbac-ex3 --timeout=90s >/dev/null 2>&1
echo "   rbac-ex1~6 재생성됨 (app-role 와일드카드 / dangerous-admin / ci-bot-admin 복구)"

echo "==> 2. work/ 에 작업용 매니페스트 생성"
mkdir -p work

# ---- q1 [수정] Role 권한 축소
{ header 1 "q1-app-role.yaml" "ns rbac-ex1 / role app-role — pods 를 get·list 만 가능하게 축소하라" "수정"
  hint "# 힌트: rules 만 고친다. RoleBinding 은 건드리지 말 것."
  extract problem-1.yaml Role app-role
} > work/q1-app-role.yaml
echo "   work/q1-app-role.yaml   [수정]"

# ---- q2 [생성] Role + RoleBinding 만들기
{ header 2 "q2-reader-rbac.yaml" "ns rbac-ex2 / sa reader — pods 를 get·list·watch 하도록 Role + RoleBinding 을 만들어라" "생성"
  hint "#"
  hint "# 아래에 직접 작성하세요. 시험에서 가장 빠른 방법은 imperative 명령으로 뼈대를 뽑는 것:"
  hint "#   kubectl create role pod-viewer --verb=get,list,watch --resource=pods \\"
  hint "#     -n rbac-ex2 --dry-run=client -o yaml >> work/q2-reader-rbac.yaml"
  hint "#   echo '---' >> work/q2-reader-rbac.yaml        # ★ 문서 구분자 필수"
  hint "#   kubectl create rolebinding reader-rb --role=pod-viewer \\"
  hint "#     --serviceaccount=rbac-ex2:reader -n rbac-ex2 --dry-run=client -o yaml >> work/q2-reader-rbac.yaml"
  hint "#"
  hint "# ⚠️ 함정: >> 로 이어붙일 때 '---' 를 빼먹으면 두 문서가 하나로 합쳐져서"
  hint "#    'unknown field \"rules\"' 에러가 난다. (bom 으로 SBOM 이어붙일 때와 같은 실수)"
  echo ""
} > work/q2-reader-rbac.yaml
echo "   work/q2-reader-rbac.yaml   [생성 · 빈 파일]"

# ---- q3 [수정] SA 토큰 automount 끄기
{ header 3 "q3-robot-client.yaml" "ns rbac-ex3 / sa robot + deploy client — SA 와 Pod 양쪽 다 토큰 automount 를 꺼라" "수정"
  hint "# 힌트: SA 는 최상위 automountServiceAccountToken, Pod 는 spec.template.spec 아래."
  extract problem-3.yaml ServiceAccount robot
  extract problem-3.yaml Deployment client
} > work/q3-robot-client.yaml
echo "   work/q3-robot-client.yaml   [수정]"

# ---- q5 [생성] ClusterRole + ClusterRoleBinding
{ header 5 "q5-inspector-rbac.yaml" "ns rbac-ex5 / sa inspector — 노드를 list 할 수 있게 하라" "생성"
  hint "#"
  hint "# 아래에 직접 작성하세요. imperative 로 뼈대를 뽑는 방법:"
  hint "#   kubectl create clusterrole node-reader --verb=list --resource=nodes \\"
  hint "#     --dry-run=client -o yaml >> work/q5-inspector-rbac.yaml"
  hint "#   echo '---' >> work/q5-inspector-rbac.yaml     # ★ 문서 구분자 필수"
  hint "#   kubectl create clusterrolebinding inspector-nodes --clusterrole=node-reader \\"
  hint "#     --serviceaccount=rbac-ex5:inspector --dry-run=client -o yaml >> work/q5-inspector-rbac.yaml"
  hint "#"
  hint "# 힌트: 노드는 클러스터 범위라 Role 이 아니라 ClusterRole 이다. 검증 시 -n 을 붙이지 말 것."
  echo ""
} > work/q5-inspector-rbac.yaml
echo "   work/q5-inspector-rbac.yaml   [생성 · 빈 파일]"

echo ""
echo "※ 문제 4·6 은 [삭제] 유형이라 work 파일이 없습니다. 찾아서 지우는 게 문제입니다:"
echo "    kubectl get rolebindings -A | grep -i admin          # q4 (ns 범위)"
echo "    kubectl get clusterrolebindings -o wide | grep cluster-admin   # q6 (클러스터 범위)"
echo ""
echo "준비 완료.  vim work/q1-app-role.yaml && kubectl apply -f work/q1-app-role.yaml"
