# 01. 하띠(Hatti) 데이터베이스 스키마 & RLS 설계 문서

본 문서는 하띠(Hatti) 애플리케이션의 Supabase Postgres 스키마, RLS 정책, 그리고 스트릭 갱신을 위한 로직(KST 타임존 고려)을 정의한 설계 문서입니다.

## 1. 테이블 DDL (Data Definition Language)

### 1.1. `hatti_state` 테이블
유저의 게임화 상태(친밀도, 스트릭, 현재 단계)를 추적합니다.

```sql
CREATE TABLE public.hatti_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    intimacy INTEGER NOT NULL DEFAULT 0,
    streak INTEGER NOT NULL DEFAULT 0,
    stage INTEGER NOT NULL DEFAULT 0,
    last_checked_in_at TIMESTAMPTZ, -- 마지막 체크인 시간 (UTC)
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id)
);

-- updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION public.update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_hatti_state_modtime
BEFORE UPDATE ON public.hatti_state
FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();
```

### 1.2. `checkin_log` 테이블
유저의 각 체크인 기록을 저장합니다. 민감한 데이터(원문 등)를 포함하므로 보안이 중요합니다.

```sql
CREATE TABLE public.checkin_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    raw_text TEXT NOT NULL, -- 입력 텍스트 원문 (민감 정보)
    emotion VARCHAR(50), -- 감정 라벨
    intensity INTEGER, -- 강도 (예: 1~5)
    context_keyword VARCHAR(100), -- 맥락 태그
    empathy TEXT, -- 공감 대사
    affirmation TEXT, -- 확언
    diary TEXT, -- 비동기 일기
    crisis_flag BOOLEAN NOT NULL DEFAULT false, -- 위기 여부
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 2. 인덱스 설계
주요 조회 패턴인 "유저별 최근 체크인 내역(페이징/정렬 포함)"과 "위기 플래그 확인"을 최적화합니다.

```sql
-- 유저의 최근 체크인을 빠르게 조회하기 위한 인덱스
CREATE INDEX idx_checkin_log_user_created 
ON public.checkin_log (user_id, created_at DESC);

-- 유저 상태 빠른 조회용 인덱스
CREATE INDEX idx_hatti_state_user 
ON public.hatti_state (user_id);
```

## 3. RLS (Row Level Security) 정책
클라이언트는 본인 데이터를 읽고 지울 수만 있으며, 생성 및 수정은 오직 Edge Function(`service_role` 키 사용)에서만 수행 가능하도록 강제합니다.

```sql
-- 1. hatti_state 테이블 정책
ALTER TABLE public.hatti_state ENABLE ROW LEVEL SECURITY;

-- Select: 본인 행만 조회 가능
CREATE POLICY select_hatti_state ON public.hatti_state
FOR SELECT USING (auth.uid() = user_id);

-- Delete: 본인 행만 삭제 가능 (데이터 삭제 요청권)
CREATE POLICY delete_hatti_state ON public.hatti_state
FOR DELETE USING (auth.uid() = user_id);

-- Insert/Update: 클라이언트 권한 없음 (Service Role만 가능하도록 별도 정책 미생성)


-- 2. checkin_log 테이블 정책
ALTER TABLE public.checkin_log ENABLE ROW LEVEL SECURITY;

-- Select: 본인 행만 조회 가능
CREATE POLICY select_checkin_log ON public.checkin_log
FOR SELECT USING (auth.uid() = user_id);

-- Delete: 본인 행만 삭제 가능
CREATE POLICY delete_checkin_log ON public.checkin_log
FOR DELETE USING (auth.uid() = user_id);

-- Insert/Update: 클라이언트 권한 없음
```

> **참고**: `Insert`와 `Update`에 대한 RLS 정책을 추가하지 않음으로써, `anon` 또는 `authenticated` 롤을 가진 클라이언트는 직접 쓰기 작업을 할 수 없습니다. 오직 `service_role` 키를 사용하는 백엔드(Edge Function 등)에서만 테이블 수정이 가능합니다.

## 4. 스트릭 / 친밀도 / 단계 계산 로직 (Edge Function)

Edge Function에서 체크인을 처리할 때 사용할 상태 갱신 의사코드 및 SQL 로직입니다. 

### 4.1. KST 타임존 기반 날짜 계산 규칙
- UTC 시간으로 저장된 `last_checked_in_at` 및 현재 체크인 시간을 `Asia/Seoul` (KST) 기준으로 변환한 후 날짜(`DATE`)를 비교합니다.

### 4.2. 갱신 로직 (Pseudo Code & SQL)

```sql
-- 체크인 발생 시 Edge Function 내부 로직 (트랜잭션으로 처리)
WITH timezone_calc AS (
    SELECT 
        (now() AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Seoul')::DATE AS today_kst,
        (last_checked_in_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Seoul')::DATE AS last_checkin_kst
    FROM hatti_state
    WHERE user_id = :user_id
)
UPDATE hatti_state
SET 
    -- 1. 스트릭 계산
    streak = CASE
        -- 오늘 이미 체크인한 경우 유지
        WHEN today_kst = last_checkin_kst THEN streak
        -- 어제 체크인한 경우 + 1
        WHEN today_kst = last_checkin_kst + INTERVAL '1 day' THEN streak + 1
        -- 그 외 (결석) 초기화
        ELSE 1
    END,

    -- 2. 친밀도 갱신 (위기 상황이 아닌 일반 체크인 시 무조건 +1 증가 가정)
    intimacy = intimacy + 1,
    
    -- 3. 단계 계산 (친밀도 구간 함수: 0-2/3-6/7+)
    stage = CASE
        WHEN intimacy + 1 >= 7 THEN 3
        WHEN intimacy + 1 >= 3 THEN 2
        ELSE 1
    END,

    last_checked_in_at = now(),
    updated_at = now()
FROM timezone_calc
WHERE hatti_state.user_id = :user_id
AND :crisis_flag = false; -- 위기 발생 시에는 친밀도/스트릭 불변 원칙 반영
```
