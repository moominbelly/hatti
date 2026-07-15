"""데이터 모델 — user / hatti_state / checkin_log (기획서 3테이블).

MVP는 SQLite. 나중에 Postgres 전환은 DATABASE_URL만 바꾸면 됨(SQLAlchemy).
"""
import os
import datetime as dt

from sqlalchemy import (
    create_engine, Column, Integer, String, Text, Boolean, Date, DateTime, ForeignKey,
)
from sqlalchemy.orm import declarative_base, sessionmaker, relationship

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./hatti.db")

# SQLite는 스레드 체크 옵션 필요, 그 외 DB는 불필요
_connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, connect_args=_connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class User(Base):
    __tablename__ = "user"
    id = Column(Integer, primary_key=True)
    created_at = Column(DateTime, default=dt.datetime.utcnow)

    state = relationship("HattiState", back_populates="user", uselist=False)
    logs = relationship("CheckinLog", back_populates="user")


class HattiState(Base):
    __tablename__ = "hatti_state"
    user_id = Column(Integer, ForeignKey("user.id"), primary_key=True)
    intimacy = Column(Integer, default=0)          # 친밀도: 누적, 감소 없음
    streak = Column(Integer, default=0)            # 연속 체크인 일수
    last_checkin_date = Column(Date, nullable=True)
    stage = Column(Integer, default=1)             # 성장 단계 1~3

    user = relationship("User", back_populates="state")


class CheckinLog(Base):
    __tablename__ = "checkin_log"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("user.id"))
    created_at = Column(DateTime, default=dt.datetime.utcnow)
    period = Column(String(10))                    # morning | evening
    raw_text = Column(Text)                         # 민감정보 — 보존/삭제 정책 필요(포스트-MVP)
    emotion = Column(String(20))
    intensity = Column(Integer)
    context_keyword = Column(String(60))
    empathy = Column(Text)
    affirmation = Column(Text)
    crisis_flag = Column(Boolean, default=False)
    diary = Column(Text, nullable=True)            # 3차 호출 결과(백그라운드로 나중에 채움)

    user = relationship("User", back_populates="logs")


def init_db():
    Base.metadata.create_all(bind=engine)
