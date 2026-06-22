"""
payment-svc — 결제 서비스 (민감)
카드 결제를 처리하고 결제 내역을 user-db에 저장한다.

[의도된 취약점 — 교육용]
  * 카드번호(PAN)를 마스킹/암호화 없이 평문 그대로 저장한다.
  * GET /cards 가 저장된 모든 카드번호를 평문으로 반환한다. (카드정보 유출 데모)
  * 서비스 간 통신이 평문 HTTP 다. (6강 TLS에서 다룸)
  -> 5강 NetworkPolicy / 6강 TLS / 8강 Audit 으로 단계적으로 방어한다.
"""
import os
import uuid
import datetime as dt

from flask import Flask, request, jsonify
from sqlalchemy import (
    create_engine, MetaData, Table, Column, Integer, String, Numeric,
    DateTime, insert, select,
)

app = Flask(__name__)

# 로컬 테스트는 SQLite, compose/K8s는 Postgres (DATABASE_URL로 주입)
DB_URL = os.environ.get("DATABASE_URL", "sqlite:////tmp/skillshop.db")
engine = create_engine(DB_URL, future=True, pool_pre_ping=True)
metadata = MetaData()

payments = Table(
    "payments", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("txn_id", String(40), nullable=False),
    Column("student_email", String(255), nullable=False),
    Column("card_number", String(32), nullable=False),  # (취약) 평문 저장
    Column("amount", Numeric(10, 2), nullable=False),
    Column("status", String(16), nullable=False),
    Column("created_at", DateTime, default=dt.datetime.utcnow),
)


def init_db():
    metadata.create_all(engine, checkfirst=True)


@app.get("/health")
def health():
    return jsonify(status="ok", service="payment-svc")


@app.post("/pay")
def pay():
    data = request.get_json(force=True, silent=True) or {}
    card = str(data.get("card_number", "")).strip()
    email = str(data.get("email", "")).strip()
    amount = data.get("amount", 0)

    if not card or not email:
        return jsonify(error="card_number, email required"), 400

    # 데모용 승인 로직: 카드번호가 13~19자리 숫자면 승인
    digits = card.replace(" ", "").replace("-", "")
    approved = digits.isdigit() and 13 <= len(digits) <= 19
    status = "approved" if approved else "declined"
    txn_id = "txn_" + uuid.uuid4().hex[:12]

    with engine.begin() as conn:
        conn.execute(insert(payments).values(
            txn_id=txn_id,
            student_email=email,
            card_number=card,          # (취약) 평문 그대로 저장
            amount=amount,
            status=status,
        ))

    # (취약) 응답에도 카드번호가 그대로 노출됨
    return jsonify(txn_id=txn_id, status=status, card_number=card, amount=amount), \
        (200 if approved else 402)


@app.get("/cards")
def cards():
    """(취약) 저장된 모든 결제·카드 정보를 평문으로 반환 — 해커의 최종 전리품."""
    with engine.begin() as conn:
        rows = conn.execute(
            select(payments).order_by(payments.c.id.desc())
        ).mappings().all()
    return jsonify([
        {
            "txn_id": r["txn_id"],
            "email": r["student_email"],
            "card_number": r["card_number"],
            "amount": float(r["amount"]),
            "status": r["status"],
        }
        for r in rows
    ])


init_db()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
