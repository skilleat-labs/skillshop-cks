// 모의고사 PPT 공용 빌더 — ppt-template/deck_lib 디자인 재사용
// 각 build-mock-N.js 에서 require 해서 사용한다.
const L = require("../../ppt-template/deck_lib");

// tag: "C"(클러스터·라이브) / "N"(노드) / "I"(Istio·검증생략)
const TAG = {
  C: { t: "클러스터 리소스 · 라이브 채점", c: L.BLUE },
  N: { t: "노드 작업 · verify.sh 수동점검", c: L.RED },
  I: { t: "Istio · 검증 생략(설치 필요)", c: L.RED },
};

async function buildExam({ num, count, minutes, subtitle, questions, outFile }) {
  const P = L.newDeck(`CKS 모의고사 ${num}회차`);

  // 표지
  L.titleSlide(P, {
    kicker: `CKS 모의고사 · MOCK EXAM 0${num}`,
    title: `모의고사 ${num}회차`,
    sub: `${count}문제 · 목표 ${minutes}분 · 합격선 감각 67%+\n${subtitle}`,
    footer: "SkillShop · CKS 온라인 교육 (환경: k8s 1.32 / containerd / Cilium)",
  });

  // 문제 슬라이드
  questions.forEach((q, i) => {
    const s = P.addSlide(); L.base(s);
    L.header(s, `문제 ${i + 1} · 배점 ${q.points}`, q.title);

    // 유형 태그 + 컨텍스트
    const tag = TAG[q.tag];
    s.addText([
      { text: tag.t, options: { color: tag.c, bold: true } },
      { text: q.ctx ? `    ·    ${q.ctx}` : "", options: { color: L.MUTED } },
    ], { x: L.ML, y: 1.72, w: 11.9, h: 0.35, margin: 0, fontFace: L.FONT, fontSize: 12.5, align: "left" });

    // 과제 불릿
    const bullets = q.tasks.map((t, k) => ({
      text: t,
      options: { bullet: { indent: 16 }, breakLine: true, ...(k === q.tasks.length - 1 ? {} : {}) },
    }));
    s.addText(bullets, {
      x: L.ML, y: 2.2, w: 11.9, h: 2.0, margin: 0,
      fontFace: L.FONT, fontSize: 15.5, color: L.INK, valign: "top", lineSpacingMultiple: 1.22,
    });

    // 검증/힌트 코드박스
    if (q.verify && q.verify.length) {
      const h = Math.min(2.5, 0.75 + q.verify.length * 0.32);
      L.codeBox(P, s, {
        x: L.ML, y: 6.35 - h, w: 11.83, h,
        label: q.verifyLabel || "검증 / 힌트",
        lines: q.verify,
      });
    }
  });

  // 마무리 슬라이드
  const s = P.addSlide(); L.base(s);
  L.header(s, "마무리", "채점 · 정리 · 점수 누수 방지");
  s.addText([
    { text: "채점: bash verify.sh  (C=라이브 PASS/FAIL, N=수동 점검 안내)", options: { bullet: { indent: 16 }, breakLine: true } },
    { text: "정리: ../reset.sh", options: { bullet: { indent: 16 }, breakLine: true } },
    { text: "막히면: solutions/qN-*.md 정답 확인", options: { bullet: { indent: 16 }, breakLine: true } },
  ], { x: L.ML, y: 2.0, w: 11.9, h: 1.5, margin: 0, fontFace: L.FONT, fontSize: 16, valign: "top", lineSpacingMultiple: 1.25 });
  L.codeBox(P, s, {
    x: L.ML, y: 3.9, w: 11.83, h: 2.3, label: "점수 누수 방지 (매 문제 습관)",
    lines: [
      { t: "□ 컨텍스트/네임스페이스 확인  (config current-context, -n)", c: L.INK },
      { t: "□ 작업 후 검증 명령 실행  ← 최대 누수 지점", c: L.RED },
      { t: "□ 문제 동사 정확히: delete / replace / scale", c: L.INK },
      { t: "□ 서비스명 함정: falco → falco-modern-bpf", c: L.INK },
      { t: "□ getent group <name>  (grep 부분매칭 회피)", c: L.INK },
    ],
  });

  await P.writeFile({ fileName: outFile });
  console.log("WROTE " + outFile);
}

module.exports = { buildExam };
