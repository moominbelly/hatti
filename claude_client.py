"""Claude 호출 래퍼.

- 감정 분석: 빠른 모델(Haiku), 낮은 temperature, JSON 안전 파싱.
- 공감/일기: 메인 모델(Sonnet), 높은 temperature.
API 키는 환경변수 ANTHROPIC_API_KEY 로 주입(서버측에서만 보관).
"""
import os
import json
import re

from anthropic import Anthropic

import prompts
from content import EMOTION_KEYS

# 현재 모델 ID. 기획서의 "Sonnet 4.6" → 현재는 claude-sonnet-5.
MODEL_ANALYZE = os.getenv("HATTI_MODEL_ANALYZE", "claude-haiku-4-5")
MODEL_MAIN = os.getenv("HATTI_MODEL_MAIN", "claude-sonnet-5")

client = Anthropic()  # ANTHROPIC_API_KEY 자동 사용


def _text(resp) -> str:
    """응답 content 블록에서 텍스트만 합쳐 반환."""
    return "".join(b.text for b in resp.content if getattr(b, "type", None) == "text").strip()


def _safe_json(raw: str) -> dict:
    """코드펜스/잡텍스트가 섞여도 첫 JSON 객체를 안전하게 파싱."""
    cleaned = raw.replace("```json", "").replace("```", "").strip()
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        m = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if m:
            try:
                return json.loads(m.group(0))
            except json.JSONDecodeError:
                pass
    return {}


def analyze_emotion(text: str) -> dict:
    """1차 호출. 실패해도 크래시 없이 neutral 기본값으로 폴백."""
    resp = client.messages.create(
        model=MODEL_ANALYZE,
        max_tokens=300,
        temperature=0.2,
        system=prompts.ANALYZE_SYSTEM,
        messages=[{"role": "user", "content": text}],
    )
    data = _safe_json(_text(resp))

    emotion = data.get("emotion")
    if emotion not in EMOTION_KEYS:
        emotion = "neutral"
    try:
        intensity = int(data.get("intensity", 3))
    except (TypeError, ValueError):
        intensity = 3
    intensity = max(1, min(5, intensity))

    return {
        "emotion": emotion,
        "intensity": intensity,
        "context_keyword": (data.get("context_keyword") or "오늘의 마음")[:60],
        "crisis_flag": bool(data.get("crisis_flag", False)),
    }


def generate_empathy(emotion_ko: str, intensity: int, context: str,
                     raw_text: str, intimacy: int, period: str) -> str:
    resp = client.messages.create(
        model=MODEL_MAIN,
        max_tokens=200,
        temperature=0.85,
        system=prompts.EMPATHY_SYSTEM,
        messages=[{"role": "user", "content": prompts.empathy_user_prompt(
            emotion_ko, intensity, context, raw_text, intimacy, period)}],
    )
    return _text(resp)


def generate_diary(emotion_ko: str, context: str, raw_text: str) -> str:
    resp = client.messages.create(
        model=MODEL_MAIN,
        max_tokens=250,
        temperature=0.9,
        system=prompts.DIARY_SYSTEM,
        messages=[{"role": "user", "content": prompts.diary_user_prompt(
            emotion_ko, context, raw_text)}],
    )
    return _text(resp)
