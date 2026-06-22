# 9강 정답 — 멀티스테이지 + non-root
FROM python:3.12-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim
RUN useradd -u 10001 -m appuser
WORKDIR /app
COPY --from=build /install /usr/local
COPY . .
USER 10001                              # RUN 모두 끝난 뒤 맨 마지막
CMD ["python", "app.py"]
