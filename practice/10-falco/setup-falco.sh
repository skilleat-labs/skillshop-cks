#!/usr/bin/env bash
# Falco 설치 (호스트 systemd 서비스) — 10강 실습 전 1회.
# ⚠️ suspicious 파드가 스케줄된 "그 노드"에서 실행해야 탐지됨. (모르면 모든 워커에 설치)
#    노드 확인:  kubectl get pod -n falco-ex -o wide
set -euo pipefail

echo "==> Falco apt 저장소 등록"
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" \
  | sudo tee /etc/apt/sources.list.d/falcosecurity.list >/dev/null
sudo apt-get update

echo "==> 드라이버: Modern eBPF 로 비대화식 선택 (커널 5.8+ 필요, Ubuntu 22.04 OK)"
echo "falco falco/driver_choice select Modern eBPF" | sudo debconf-set-selections || true

echo "==> Falco 설치"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y falco

echo "==> Modern eBPF 서비스 사용"
sudo systemctl disable --now falco-kmod falco-bpf 2>/dev/null || true
sudo systemctl enable --now falco-modern-bpf

echo "==> 상태"
sudo systemctl status falco-modern-bpf --no-pager | head -15 || true
echo
echo "로그 보기:        sudo journalctl -fu falco-modern-bpf"
echo "커스텀 룰 파일:   /etc/falco/falco_rules.local.yaml"
echo "룰 수정 후 적용:  sudo systemctl restart falco-modern-bpf"
