"""하띠 백엔드 — FastAPI.

핵심은 POST /checkin 오케스트레이션:
  위기 프리필터 → 감정 분석(1차) → 위기 분기 → 공감(2차) → 상태 갱신·기록 → 일기(3차, 백그라운드)
"""
import datetime as dt

from fastapi import FastAPI, Depends, BackgroundTasks, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

import models
import logic
import claude_client as ai
from content import (EMOTION_LABEL_KO, AFFIRMATIONS, CRISIS_RESPONSE,
                     MAX_INPUT_LENGTH)
from models import SessionLocal, User, HattiState, CheckinLog

app = FastAPI(title="Hatti API")

# 데모용: 전체 허용. 운영에선 앱 도메인만 허용.
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"],
)


@app.on_event("startup")
def _startup():
    models.init_db()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ── 스키마 ────────────────────────────────────────────────
class CheckinIn(BaseModel):
    user_id: int
    text: str = Field(..., max_length=MAX_INPUT_LENGTH)
    period: str = "evening"  # morning | evening


import random  # 확언 랜덤 선택용


def _get_or_create_state(db: Session, user_id: int) -> HattiState:
    user = db.get(User, user_id)
    if user is None:
        user = User(id=user_id)
        db.add(user)
        db.flush()
    state = db.get(HattiState, user_id)
    if state is None:
        state = HattiState(user_id=user_id, intimacy=0, streak=0, stage=1)
        db.add(state)
        db.flush()
    return state


def _generate_diary_bg(log_id: int, emotion_ko: str, context: str, raw_text: str):
    """백그라운드에서 하띠 일기 생성 후 해당 로그에 채워 넣음."""
    db = SessionLocal()
    try:
        diary = ai.generate_diary(emotion_ko, context, raw_text)
        log = db.get(CheckinLog, log_id)
        if log:
            log.diary = diary
            db.commit()
    finally:
        db.close()


# ── 체크인 (핵심 오케스트레이션) ──────────────────────────
@app.post("/checkin")
def checkin(body: CheckinIn, bg: BackgroundTasks, db: Session = Depends(get_db)):
    text = body.text.strip()
    if not text:
        raise HTTPException(400, "빈 입력입니다.")
    # 클라이언트 제한은 우회될 수 있으므로 서버에서도 검증한다.
    if len(text) > MAX_INPUT_LENGTH:
        raise HTTPException(
            400, f"입력이 너무 깁니다. (최대 {MAX_INPUT_LENGTH}자)")

    state = _get_or_create_state(db, body.user_id)

    # 1) 결정적 위기 프리필터 (LLM 호출 전 빠른 차단)
    crisis = logic.is_crisis_prefilter(text)

    # 2) 감정 분석 (1차). 프리필터가 이미 걸렸어도 LLM crisis_flag로 이중 확인
    analysis = ai.analyze_emotion(text)
    crisis = crisis or analysis["crisis_flag"]

    # 3) 위기 분기 — 공감이 아니라 전문 리소스로. 게임화(친밀도/스트릭) 없음.
    if crisis:
        db.add(CheckinLog(
            user_id=body.user_id, period=body.period, raw_text=text,
            emotion=analysis["emotion"], intensity=analysis["intensity"],
            context_keyword=analysis["context_keyword"], crisis_flag=True,
        ))
        db.commit()
        return {"crisis": True, **CRISIS_RESPONSE}

    emotion = analysis["emotion"]
    emotion_ko = EMOTION_LABEL_KO[emotion]

    # 4) 공감 대사 (2차)
    empathy = ai.generate_empathy(
        emotion_ko, analysis["intensity"], analysis["context_keyword"],
        text, state.intimacy, body.period,
    )

    # 5) 확언 매칭 (감정별 풀에서 선택 — 결정적)
    affirmation = random.choice(AFFIRMATIONS[emotion])

    # 6) 상태 갱신 (친밀도+1, 스트릭, 단계) + 로그 기록
    logic.apply_checkin(state, dt.date.today())
    log = CheckinLog(
        user_id=body.user_id, period=body.period, raw_text=text,
        emotion=emotion, intensity=analysis["intensity"],
        context_keyword=analysis["context_keyword"],
        empathy=empathy, affirmation=affirmation, crisis_flag=False,
    )
    db.add(log)
    db.commit()
    db.refresh(log)

    # 7) 일기(3차)는 응답 후 백그라운드 생성 → 사용자 체감 지연 감소
    bg.add_task(_generate_diary_bg, log.id, emotion_ko,
                analysis["context_keyword"], text)

    return {
        "crisis": False,
        "checkin_id": log.id,
        "emotion": emotion,
        "emotion_ko": emotion_ko,
        "intensity": analysis["intensity"],
        "context_keyword": analysis["context_keyword"],
        "empathy": empathy,
        "affirmation": affirmation,
        "hatti": {
            "intimacy": state.intimacy,
            "streak": state.streak,
            "stage": state.stage,
            "stage_name": logic.STAGE_NAME[state.stage],
        },
    }


# ── 홈 화면 상태 ──────────────────────────────────────────
@app.get("/state")
def get_state(user_id: int, db: Session = Depends(get_db)):
    state = _get_or_create_state(db, user_id)
    db.commit()
    recent = (
        db.query(CheckinLog)
        .filter(CheckinLog.user_id == user_id, CheckinLog.crisis_flag == False)  # noqa: E712
        .order_by(CheckinLog.created_at.desc())
        .limit(4)
        .all()
    )
    return {
        "intimacy": state.intimacy,
        "streak": state.streak,
        "stage": state.stage,
        "stage_name": logic.STAGE_NAME[state.stage],
        "recent": [
            {"emotion": r.emotion, "emotion_ko": EMOTION_LABEL_KO.get(r.emotion, r.emotion)}
            for r in recent
        ],
    }


# ── 일기 지연 로드 (백그라운드 완료 후 폴링) ──────────────
@app.get("/checkin/{checkin_id}/diary")
def get_diary(checkin_id: int, db: Session = Depends(get_db)):
    log = db.get(CheckinLog, checkin_id)
    if log is None:
        raise HTTPException(404, "체크인을 찾을 수 없습니다.")
    return {"diary": log.diary, "ready": log.diary is not None}
