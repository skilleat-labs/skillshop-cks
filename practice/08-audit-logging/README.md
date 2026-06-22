# 8강 실습 — Audit Logging (컨트롤플레인 노드)

> 노드의 kube-apiserver static pod 에 audit 를 켭니다. 네임스페이스 YAML 아님.

## 과제
1. `files/audit-policy.yaml` 를 노드의 `/etc/kubernetes/audit-policy.yaml` 로 복사
2. `/etc/kubernetes/manifests/kube-apiserver.yaml` 에 플래그 추가:
   - `--audit-policy-file=/etc/kubernetes/audit-policy.yaml`
   - `--audit-log-path=/var/log/kubernetes/audit.log`
3. 그리고 **volumeMounts + volumes(hostPath)** 두 개를 추가 (둘 중 하나라도 빠지면 apiserver 기동 실패)
   - 정책 파일: hostPath `type: File`
   - 로그 디렉토리: hostPath `type: DirectoryOrCreate`

정답 스니펫은 `solutions.md`.

## 검증
```bash
watch crictl ps                       # apiserver 재기동 확인
sudo ls -l /var/log/kubernetes/audit.log
sudo tail -1 /var/log/kubernetes/audit.log   # JSON 요청 기록
```
