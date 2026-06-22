"""
frontend — 화면 · 진입점
강의 목록을 보여주고 수강 신청 폼을 처리한다. (해커의 첫 진입점)

통신: frontend -> product-svc (목록)
       frontend -> order-svc   (수강신청)
"""
import os

import requests
from flask import Flask, render_template, request, redirect, url_for

app = Flask(__name__)

PRODUCT_SVC_URL = os.environ.get("PRODUCT_SVC_URL", "http://product-svc:8080")
ORDER_SVC_URL = os.environ.get("ORDER_SVC_URL", "http://order-svc:8080")


@app.get("/health")
def health():
    return {"status": "ok", "service": "frontend"}


@app.get("/")
def index():
    courses, error = [], None
    try:
        r = requests.get(f"{PRODUCT_SVC_URL}/products", timeout=5)
        courses = r.json()
    except requests.RequestException as e:
        error = f"강의 목록을 불러오지 못했습니다: {e}"
    return render_template("index.html", courses=courses, error=error)


@app.get("/enroll/<int:course_id>")
def enroll_form(course_id):
    try:
        r = requests.get(f"{PRODUCT_SVC_URL}/products/{course_id}", timeout=5)
        if r.status_code != 200:
            return redirect(url_for("index"))
        course = r.json()
    except requests.RequestException:
        return redirect(url_for("index"))
    return render_template("enroll.html", course=course)


@app.post("/enroll")
def enroll_submit():
    payload = {
        "name": request.form.get("name", "").strip(),
        "email": request.form.get("email", "").strip(),
        "card_number": request.form.get("card_number", "").strip(),
        "course_id": int(request.form.get("course_id", "0") or 0),
    }
    result, error = None, None
    try:
        r = requests.post(f"{ORDER_SVC_URL}/orders", json=payload, timeout=8)
        result = r.json()
    except requests.RequestException as e:
        error = f"수강 신청 처리 중 오류: {e}"
    return render_template("result.html", result=result, error=error)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
