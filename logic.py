"""순수 비즈니스 로직 (DB·LLM 의존 없음 → 단위 테스트 쉬움)."""
import datetime as dt

from content import CRISIS_KEYWORDS


def is_crisis_prefilter(text: str) -> bool:
    """결정적 위기어 프리필터. LLM crisis_flag와 OR로 결합해 이중 방어."""
    return any(k in text for k in CRISIS_KEYWORDS)


def stage_of(intimacy: int) -> int:
    """친밀도 → 성장 단계. 프로토타입과 동일한 임계값."""
    if intimacy >= 7:
        return 3
    if intimacy >= 3:
        return 2
    return 1


STAGE_NAME = {1: "새싹 하띠", 2: "아기 하띠", 3: "하띠"}


def next_streak(prev_streak: int, last_date: dt.date | None, today: dt.date) -> int:
    """연속 체크인 계산.
    - 첫 체크인 또는 하루 이상 공백 → 1로 시작/리셋
    - 어제 체크인함 → +1
    - 오늘 이미 체크인함 → 유지(중복 증가 방지)
    """
    if last_date is None:
        return 1
    delta = (today - last_date).days
    if delta == 0:
        return prev_streak
    if delta == 1:
        return prev_streak + 1
    return 1  # 공백 발생 → 리셋


def apply_checkin(state, today: dt.date) -> None:
    """HattiState 객체를 체크인 1회 기준으로 갱신(위기가 아닌 정상 경로에서만 호출).
    친밀도는 누적·감소 없음(기획 원칙).
    """
    state.streak = next_streak(state.streak, state.last_checkin_date, today)
    state.intimacy = (state.intimacy or 0) + 1
    state.last_checkin_date = today
    state.stage = stage_of(state.intimacy)
