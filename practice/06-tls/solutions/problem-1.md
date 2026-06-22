# 문제 1 정답
```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout tls.key -out tls.crt -subj "/CN=shop.example.com"

kubectl create secret tls shop-tls -n tls-ex --cert=tls.crt --key=tls.key
```
