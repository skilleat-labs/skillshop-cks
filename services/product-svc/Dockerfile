# (취약) 1강 "털린 스킬샵" 상태
#  - full python 베이스 이미지 (불필요한 도구 다수, 큰 공격 표면)
#  - root 사용자로 실행
#  - Flask 개발 서버로 구동
# -> 9강 Supply Chain에서 Dockerfile.hardened 로 교체한다.
FROM python:3.12

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .

EXPOSE 8080
CMD ["python", "app.py"]
