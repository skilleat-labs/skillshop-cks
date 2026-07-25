#!/usr/bin/env bash
# ============================================================
# kube-bench 를 "클러스터 Job" 으로 실행한다.
#   노드에 SSH 로 못 들어가도, kubectl 만 있으면 CIS 벤치마크를 돌릴 수 있다.
#   kube-bench 컨테이너가 노드의 /etc, /var, 프로세스를 hostPath/hostPID 로 보고 검사한다.
#
#   - control-plane(마스터) 검사: master 노드에서 role=master 로
#   - worker 검사: 워커 노드에서 role=node 로
#
#   사용법:
#     bash run-kube-bench.sh                # 마스터+워커 둘 다
#     bash run-kube-bench.sh master         # 마스터만
#     bash run-kube-bench.sh node           # 워커만
#     bash run-kube-bench.sh --fails        # 결과에서 [FAIL] 만 뽑아본다
#
#   결과는 out/ 폴더에 저장된다 (out/master.txt, out/node.txt).
# ============================================================
set -u
cd "$(dirname "$0")"
mkdir -p out

IMAGE="docker.io/aquasec/kube-bench:latest"   # 시험장 버전과 다를 수 있음. 필요시 태그 고정.
NS="kube-bench"

WHICH="both"; FAILS=0
for a in "$@"; do
  case "$a" in
    master|node) WHICH="$a" ;;
    both) WHICH="both" ;;
    --fails) FAILS=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" >/dev/null

# 마스터 노드 이름(들) 알아내기 — nodeName 으로 Job 을 고정 배치
# 역할 라벨은 "값이 빈 문자열"이라 값으로 판별하면 안 된다 → 라벨 "존재/부재"로 고른다.
MASTER_NODE="$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
WORKER_NODE="$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

run_job() { # $1=role(master|node)  $2=nodeName
  local role="$1" node="$2" job="kube-bench-$1"
  [ -z "$node" ] && { echo "!! $role 용 노드를 못 찾음 — 건너뜀"; return 1; }
  echo "==> kube-bench [$role] on node: $node"
  kubectl -n "$NS" delete job "$job" --ignore-not-found >/dev/null 2>&1
  kubectl -n "$NS" wait --for=delete pod -l job-name="$job" --timeout=30s >/dev/null 2>&1

  cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: $job
  namespace: $NS
spec:
  backoffLimit: 1
  template:
    metadata:
      labels: { job-name: $job }
    spec:
      nodeName: $node
      hostPID: true
      restartPolicy: Never
      tolerations:
      - operator: Exists            # 마스터 taint 무시하고 스케줄
      containers:
      - name: kube-bench
        image: $IMAGE
        command: ["kube-bench", "run", "--targets", "$( [ "$role" = master ] && echo master,controlplane,etcd,policies || echo node,policies )"]
        volumeMounts:
        - { name: var-lib-etcd,        mountPath: /var/lib/etcd,        readOnly: true }
        - { name: var-lib-kubelet,     mountPath: /var/lib/kubelet,     readOnly: true }
        - { name: var-lib-ksched,      mountPath: /var/lib/kube-scheduler, readOnly: true }
        - { name: var-lib-kcm,         mountPath: /var/lib/kube-controller-manager, readOnly: true }
        - { name: etc-systemd,         mountPath: /etc/systemd,         readOnly: true }
        - { name: lib-systemd,         mountPath: /lib/systemd,         readOnly: true }
        - { name: srv-kubernetes,      mountPath: /srv/kubernetes,      readOnly: true }
        - { name: etc-kubernetes,      mountPath: /etc/kubernetes,      readOnly: true }
        - { name: usr-bin,             mountPath: /usr/local/mount-from-host/bin, readOnly: true }
        - { name: etc-cni-netd,        mountPath: /etc/cni/net.d,       readOnly: true }
        - { name: opt-cni-bin,         mountPath: /opt/cni/bin,         readOnly: true }
      volumes:
      - { name: var-lib-etcd,    hostPath: { path: /var/lib/etcd } }
      - { name: var-lib-kubelet, hostPath: { path: /var/lib/kubelet } }
      - { name: var-lib-ksched,  hostPath: { path: /var/lib/kube-scheduler } }
      - { name: var-lib-kcm,     hostPath: { path: /var/lib/kube-controller-manager } }
      - { name: etc-systemd,     hostPath: { path: /etc/systemd } }
      - { name: lib-systemd,     hostPath: { path: /lib/systemd } }
      - { name: srv-kubernetes,  hostPath: { path: /srv/kubernetes } }
      - { name: etc-kubernetes,  hostPath: { path: /etc/kubernetes } }
      - { name: usr-bin,         hostPath: { path: /usr/bin } }
      - { name: etc-cni-netd,    hostPath: { path: /etc/cni/net.d } }
      - { name: opt-cni-bin,     hostPath: { path: /opt/cni/bin } }
YAML

  echo "   Job 실행 중... (완료 대기)"
  kubectl -n "$NS" wait --for=condition=complete job/"$job" --timeout=180s >/dev/null 2>&1 \
    || kubectl -n "$NS" wait --for=condition=failed job/"$job" --timeout=5s >/dev/null 2>&1
  local pod; pod="$(kubectl -n "$NS" get pod -l job-name="$job" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
  kubectl -n "$NS" logs "$pod" > "out/$role.txt" 2>&1
  local pass fail warn
  pass="$(grep -c '^\[PASS\]' "out/$role.txt")"; fail="$(grep -c '^\[FAIL\]' "out/$role.txt")"; warn="$(grep -c '^\[WARN\]' "out/$role.txt")"
  echo "   → out/$role.txt  (PASS=$pass FAIL=$fail WARN=$warn)"
}

[ "$WHICH" = both -o "$WHICH" = master ] && run_job master "$MASTER_NODE"
[ "$WHICH" = both -o "$WHICH" = node   ] && run_job node   "$WORKER_NODE"

echo ""
if [ "$FAILS" = 1 ]; then
  echo "==================== [FAIL] 목록 ===================="
  for f in out/master.txt out/node.txt; do
    [ -f "$f" ] && { echo "### $f"; grep -E '^\[FAIL\]|== Remediations' "$f" | head -60; echo; }
  done
else
  echo "결과 파일: out/master.txt, out/node.txt"
  echo "  [FAIL] 만 보기:   grep '^\[FAIL\]' out/master.txt"
  echo "  개선안 보기:      sed -n '/== Remediations/,/^$/p' out/master.txt"
  echo "정리:  kubectl delete ns $NS"
fi
