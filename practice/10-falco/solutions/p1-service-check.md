# 문제 1 정답 — Falco 동작/서비스 확인 (진단)

Falco 는 클러스터 리소스가 아니라 **노드의 systemd 서비스**다. 드라이버(수집 방식)에 따라
유닛 이름이 달라서, 먼저 "어떤 유닛으로 도는지"를 찾는 게 실전 첫 단추다.

## 1) 어떤 falco 유닛이 있고, 무엇이 켜져 있나
```bash
systemctl list-units 'falco*' --all         # 존재하는 falco 유닛 전부
systemctl list-unit-files 'falco*'           # enabled/disabled 상태
```
가능한 유닛 이름 (드라이버별, 보통 이 중 하나만 active):
- `falco-modern-bpf`  ← Modern eBPF (커널 5.8+, 권장)
- `falco-bpf`         ← 레거시 eBPF
- `falco-kmod`        ← 커널 모듈

## 2) 실제로 돌고 있는지 확인
```bash
systemctl is-active falco-modern-bpf         # active 면 동작 중
systemctl status  falco-modern-bpf --no-pager | head -20
```
> `is-active` 가 한 줄로 active/inactive 를 답한다. 어느 유닛인지 모르면:
> ```bash
> for u in falco-modern-bpf falco-bpf falco-kmod falco; do
>   printf "%-18s %s\n" "$u" "$(systemctl is-active $u 2>/dev/null)"
> done
> ```

## 3) 로그(이벤트)가 나오는지
```bash
sudo journalctl -u falco-modern-bpf -n 20 --no-pager
```
"Falco initialized ... Loading rules ... Starting ..." 가 보이면 정상 기동.

## 제출(채점용)
동작 중인 유닛 이름을 파일로 적어두면 verify 가 확인한다:
```bash
systemctl is-active falco-modern-bpf >/dev/null && echo falco-modern-bpf > /tmp/falco-service.txt
# 또는 자기 환경의 active 유닛명을 직접:  echo <유닛명> > /tmp/falco-service.txt
```

## 핵심
- **유닛명을 추측하지 말고 `systemctl list-units 'falco*'` 로 확인** (함정 2). 이후 restart·journalctl 을 정확한 이름으로 해야 한다.
- Falco 는 **감시 도구**다. 접근을 "막는" 게 아니라 "탐지·알림" 한다. (차단은 별개 — 대응은 문제 3에서)
