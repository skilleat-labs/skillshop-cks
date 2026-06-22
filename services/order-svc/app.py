"""
order-svc — 수강 신청 서비스
수강 신청을 받아 결제(payment-svc)를 호출하고, 성공 시 수강생 정보를 user-db에 저장한다.

통신 경로: order-svc -> product-svc (가격 조회)
            order-svc -> payment-svc (결제)
            order-svc -> user-db    (수강생 저장)
  -> 5강 NetworkPolicy에서 이 경로만 허용하고 나머지는 차단한다.
"""
import os
import datetime as dt

import requests
from flask import Flask, request, jsonify
from sqlalchemy import (
    create_engine, MetaData, Table, Column, Integer, String, DateTime,
    insert, select,
)

app = Flask(__name__)

PRODUCT_SVC_URL = os.environ.get("PRODUCT_SVC_URL", "http://product-svc:8080")
PAYMENT_SVC_URL = os.environ.get("PAYMENT_SVC_URL", "http://payment-svc:8080")
DB_URL = os.environ.get("DATABASE_URL", "sqlite:////tmp/skillshop.db")

engine = create_engine(DB_URL, future=True, pool_pre_ping=True)
metadata = MetaData()

students = Table(
    "students", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("name", String(120), nullable=False),
    Column("email", String(255), nullable=False),
    Column("course_id", Integer, nullable=False),
    Column("course_title", String(255)),
    Column("enrolled_at", DateTime, default=dt.datetime.utcnow),
)


def init_db():
    metadata.create_all(engine, checkfirst=True)


@app.get("/health")
def health():
    return jsonify(status="ok", service="order-svc")


@app.post("/orders")
def create_order():
    data = request.get_json(force=True, silent=True) or {}
    name = str(data.get("name", "")).strip()
    email = str(data.get("email", "")).strip()
    card = str(data.get("card_number", "")).strip()
    course_id = data.get("course_id")

    if not (name and email and card and course_id):
        return jsonify(error="name, email, card_number, course_id required"), 400

    # 1) 강의 정보 조회
    try:
        pr = requests.get(f"{PRODUCT_SVC_URL}/products/{course_id}", timeout=5)
        if pr.status_code != 200:
            return jsonify(error="course not found"), 404
        course = pr.json()
    except requests.RequestException as e:
        return jsonify(error=f"product-svc unreachable: {e}"), 502

    # 2) 결제 요청
    try:
        pay = requests.post(
            f"{PAYMENT_SVC_URL}/pay",
            json={"card_number": card, "email": email, "amount": course["price"]},
            timeout=5,
        )
        pay_body = pay.json()
    except requests.RequestException as e:
        return jsonify(error=f"payment-svc unreachable: {e}"), 502

    if pay_body.get("status") != "approved":
        return jsonify(status="declined", detail=pay_body), 402

    # 3) 수강생 저장
    with engine.begin() as conn:
        conn.execute(insert(students).values(
            name=name, email=email,
            course_id=course["id"], course_title=course["title"],
        ))

    return jsonify(
        status="enrolled",
        txn_id=pay_body.get("txn_id"),
        course_title=course["title"],
        amount=course["price"],
    )


@app.get("/orders")
def list_orders():
    with engine.begin() as conn:
        rows = conn.execute(
            select(students).order_by(students.c.id.desc())
        ).mappings().all()
    return jsonify([
        {"name": r["name"], "email": r["email"], "course_title": r["course_title"]}
        for r in rows
    ])


init_db()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
