"""
product-svc — 강의 목록 서비스
스킬샵에서 판매하는 강의 카탈로그를 제공한다. (민감 데이터 없음)
"""
import os
from flask import Flask, jsonify

app = Flask(__name__)

# 강의 카탈로그 (데모용 정적 데이터)
COURSES = [
    {"id": 1, "title": "CKA 마스터클래스", "instructor": "김쿠버", "price": 99000},
    {"id": 2, "title": "CKAD 실전 패키지", "instructor": "박파드", "price": 89000},
    {"id": 3, "title": "CKS 시크릿 가이드", "instructor": "이시큐", "price": 129000},
    {"id": 4, "title": "Helm & GitOps 입문", "instructor": "최헬름", "price": 79000},
]


@app.get("/health")
def health():
    return jsonify(status="ok", service="product-svc")


@app.get("/products")
def products():
    return jsonify(COURSES)


@app.get("/products/<int:course_id>")
def product(course_id):
    for c in COURSES:
        if c["id"] == course_id:
            return jsonify(c)
    return jsonify(error="not found"), 404


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    # (취약) Flask 개발 서버 + 모든 인터페이스 바인딩
    app.run(host="0.0.0.0", port=port)
