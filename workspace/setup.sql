-- ==========================================
-- 하띠 (Hatti) Supabase DB 셋업 스크립트 (테스트 계정 포함)
-- ==========================================
-- 본 스크립트는 Supabase Dashboard의 SQL Editor에 붙여넣어 바로 실행할 수 있도록 통합된 DDL 스크립트입니다.
-- 테이블 생성, 인덱스 최적화, RLS(Row Level Security) 설정 및 상태/스트릭 갱신 트랜잭션 함수를 포함합니다.

-- 1. hatti_state 테이블 생성
CREATE TABLE IF NOT EXISTS public.hatti_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    intimacy INTEGER NOT NULL DEFAULT 0,
    streak INTEGER NOT NULL DEFAULT 0,
    stage INTEGER NOT NULL DEFAULT 1, -- 1: 새싹 하띠, 2: 아기 하띠, 3: 하띠
    last_checked_in_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id)
);

-- 2. checkin_log 테이블 생성
CREATE TABLE IF NOT EXISTS public.checkin_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    raw_text TEXT NOT NULL,                  -- 사용자 입력 원문 (민감 개인정보)
    emotion VARCHAR(50) NOT NULL,            -- 감정 라벨
    intensity INTEGER NOT NULL,              -- 감정 강도 (1~5)
    context_keyword VARCHAR(100) NOT NULL,   -- 맥락 태그 (10자 이내 구)
    empathy TEXT,                            -- 하띠의 공감 대사 (2문장 이내)
    affirmation TEXT,                        -- 감정 맞춤형 확언 카드 문구
    diary TEXT,                              -- 3차 백그라운드 하띠 시점 일기
    crisis_flag BOOLEAN NOT NULL DEFAULT false, -- 위기 판단 여부
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. updated_at 자동 갱신 트리거 생성
CREATE OR REPLACE FUNCTION public.update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER update_hatti_state_modtime
BEFORE UPDATE ON public.hatti_state
FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();

-- 4. 인덱스 (Index) 생성
-- 유저별 최근 체크인 히스토리 조회 속도 최적화
CREATE INDEX IF NOT EXISTS idx_checkin_log_user_created 
ON public.checkin_log (user_id, created_at DESC);

-- 유저 상태의 빈번한 조회를 위한 인덱스
CREATE INDEX IF NOT EXISTS idx_hatti_state_user 
ON public.hatti_state (user_id);

-- 5. RLS (Row Level Security) 설정 및 보안 강화
-- 클라이언트(authenticated 유저)는 본인 데이터의 SELECT(조회) 및 DELETE(전체삭제권)만 직접 수행할 수 있습니다.
-- 데이터 쓰기(INSERT/UPDATE)는 클라이언트에서 직접 불가능하며, 오직 Edge Function(service_role) 또는 RPC를 통해서만 수행 가능합니다.
ALTER TABLE public.hatti_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkin_log ENABLE ROW LEVEL SECURITY;

-- 5.1. hatti_state 정책
DROP POLICY IF EXISTS select_hatti_state ON public.hatti_state;
CREATE POLICY select_hatti_state ON public.hatti_state
FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS delete_hatti_state ON public.hatti_state;
CREATE POLICY delete_hatti_state ON public.hatti_state
FOR DELETE USING (auth.uid() = user_id);

-- 5.2. checkin_log 정책
DROP POLICY IF EXISTS select_checkin_log ON public.checkin_log;
CREATE POLICY select_checkin_log ON public.checkin_log
FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS delete_checkin_log ON public.checkin_log;
CREATE POLICY delete_checkin_log ON public.checkin_log
FOR DELETE USING (auth.uid() = user_id);

-- 6. KST(UTC+9) 날짜 고려 스트릭 및 친밀도 갱신 데이터베이스 함수 (RPC)
CREATE OR REPLACE FUNCTION public.apply_checkin(
    p_user_id UUID,
    p_crisis_flag BOOLEAN
)
RETURNS public.hatti_state AS $$
DECLARE
    v_state public.hatti_state;
    v_today_kst DATE;
    v_last_checkin_kst DATE;
BEGIN
    -- UTC 서버 시간을 KST(Asia/Seoul) 타임존 기준으로 변환하여 현재 날짜 판정
    v_today_kst := (now() AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Seoul')::DATE;

    -- 유저 상태 행이 존재하지 않는 경우 기본값으로 자동 생성
    INSERT INTO public.hatti_state (user_id, intimacy, streak, stage)
    VALUES (p_user_id, 0, 0, 1)
    ON CONFLICT (user_id) DO NOTHING;

    -- 현재 상태 조회
    SELECT * INTO v_state FROM public.hatti_state WHERE user_id = p_user_id;

    -- 위기 상황인 경우 친밀도와 스트릭을 갱신하지 않고 현재 상태를 그대로 반환 (안전 기획 원칙)
    IF p_crisis_flag = true THEN
        RETURN v_state;
    END IF;

    -- 마지막 체크인 시간의 KST 날짜 변환
    IF v_state.last_checked_in_at IS NOT NULL THEN
        v_last_checkin_kst := (v_state.last_checked_in_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Seoul')::DATE;
    ELSE
        v_last_checkin_kst := NULL;
    END IF;

    -- 스트릭 연산 규칙 적용
    IF v_last_checkin_kst IS NULL THEN
        -- 첫 체크인 시 1
        v_state.streak := 1;
    ELSIF v_today_kst = v_last_checkin_kst THEN
        -- 오늘 이미 체크인함 (중복): 스트릭 유지
        NULL;
    ELSIF v_today_kst = v_last_checkin_kst + INTERVAL '1 day' THEN
        -- 어제 체크인함 (연속): 스트릭 +1
        v_state.streak := v_state.streak + 1;
    ELSE
        -- 결석일 존재: 스트릭 1로 초기화
        v_state.streak := 1;
    END IF;

    -- 친밀도 갱신
    v_state.intimacy := v_state.intimacy + 1;

    -- 친밀도 구간에 따른 단계(Stage) 판정 (1: 0~2, 2: 3~6, 3: 7+)
    v_state.stage := CASE
        WHEN v_state.intimacy >= 7 THEN 3
        WHEN v_state.intimacy >= 3 THEN 2
        ELSE 1
    END;

    -- DB 최종 반영
    UPDATE public.hatti_state
    SET 
        intimacy = v_state.intimacy,
        streak = v_state.streak,
        stage = v_state.stage,
        last_checked_in_at = now(),
        updated_at = now()
    WHERE user_id = p_user_id;

    -- 업데이트된 전체 레코드 반환
    SELECT * INTO v_state FROM public.hatti_state WHERE user_id = p_user_id;
    RETURN v_state;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==========================================
-- 7. 테스트 계정 생성 (test@example.com / 비밀번호 1234)
-- ==========================================
-- Supabase Auth의 암호화(bcrypt) 모듈 확장을 활성화하여 테스트 계정을 다이렉트로 삽입합니다.
-- ON CONFLICT 에러 방지를 위해 PL/pgSQL 블록을 사용하여 해당 이메일이 없을 때만 삽입합니다.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'test@example.com') THEN
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_token,
            email_change,
            email_change_token_new,
            recovery_token
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            gen_random_uuid(),
            'authenticated',
            'authenticated',
            'test@example.com',
            crypt('1234', gen_salt('bf', 10)),
            now(),
            '{"provider":"email","providers":["email"]}',
            '{}',
            now(),
            now(),
            '',
            '',
            '',
            ''
        );
    END IF;
END $$;

