# (취약) full 베이스 · root · Flask 개발 서버
FROM python:3.12

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .

EXPOSE 8080
CMD ["python", "app.py"]
