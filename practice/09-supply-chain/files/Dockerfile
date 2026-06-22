# 9강 실습 — 취약한 Dockerfile (고쳐야 함)
FROM python:3.12                      # full 베이스 (큰 공격 표면)
WORKDIR /app
COPY . .
RUN pip install flask
# USER 지정 없음 → root 로 실행
CMD ["python", "app.py"]
