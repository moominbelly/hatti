# 하띠 (Hatti) — 개발 문서

> 감정 다마고치 앱. Flutter + Supabase + Gemini API.
> 기준일: 2026-07-15 / 대상: 해커톤 MVP(2일) → 프로덕션 확장

---

## 0. 문서 범위

기획안(`하띠 해커톤 기획안`)에서 확정된 컨셉을 **실제 구현 가능한 형태로 번역한 문서**. 서버는 Supabase로 확정. 프로토타입(React, 목업 AI)에서 검증된 화면 흐름과 백엔드 로직(FastAPI로 선구현)을 Supabase 구조로 이관한다.

| 레이어 | 확정 |
|--------|------|
| 프론트 | Flutter (Dart) |
| 서버 로직 | **Supabase Edge Functions** (Deno / TypeScript) |
| DB | **Supabase Postgres** (+ RLS) |
| 인증 | **Supabase Auth — 익명 로그인** |
| AI | **Google Gemini API — 무료 티어** (`gemini-2.0-flash` 분석 / `gemini-2.5-flash` 공감·일기) |

---

## 1. 아키텍처

### 1.1 요청 흐름 (체크인 1회)

```
Flutter 앱
   │  supabase.functions.invoke('checkin', { text, period })
   │  (Authorization: 유저 JWT — 익명 로그인으로 발급)
   ▼
Supabase Edge Function  ← GEMINI_API_KEY 는 여기에만 존재
   │
   ├─ 1) 위기 프리필터 (결정적 키워드)
   ├─ 2) Gemini 1차 호출 — 감정 분석 (responseSchema로 JSON 강제)
   ├─ 3) crisis 분기 ──→ 전문 리소스 반환 (게임화 스킵, 여기서 종료)
   ├─ 4) Gemini 2차 호출 — 하띠 공감 대사
   ├─ 5) 확언 매칭 (감정별 큐레이션 풀)
   ├─ 6) Postgres 갱신 — hatti_state / checkin_log (service_role)
   └─ 7) 하띠 일기(3차 호출)는 응답 후 백그라운드
   ▼
Flutter 앱 — 감정 / 공감 / 확언 카드 렌더
```

### 1.2 왜 Edge Function이 필요한가 (건너뛰면 안 되는 이유)

Supabase는 앱이 DB에 **직접** 붙을 수 있는 게 장점이지만, 하띠에는 앱이 직접 하면 안 되는 일이 세 가지 있다.

| 반드시 서버(Edge Function)에 있어야 하는 것 | 이유 |
|---|---|
| **Gemini API 키** | 앱에 넣으면 디컴파일로 유출 → 쿼터 소진·오남용. 무료 티어라도 절대 클라이언트 금지. |
| **친밀도 / 스트릭 계산** | 앱이 DB에 직접 쓰면 유저가 값을 조작 가능. 게임화 무결성이 깨짐. |
| **위기 판정 분기** | 안전 기능은 클라이언트를 신뢰할 수 없음. 서버가 판정하고 서버가 응답 형태를 결정. |

> **원칙:** 앱은 **읽기만** 직접 하고(RLS로 본인 데이터만), **쓰기는 전부 Edge Function**을 통한다.

### 1.3 FastAPI 대비 달라지는 점

| 항목 | FastAPI 안 | **Supabase 안 (확정)** |
|------|-----------|----------------------|
| 서버 코드 | Python | **TypeScript (Deno)** |
| DB | SQLite → Postgres | **Postgres 처음부터** |
| 인증 | 직접 구현 필요 | **Auth 내장 (익명 로그인)** |
| 배포 | 터널/Railway 필요 | **`supabase functions deploy` 한 줄** |
| 권한 | 서버가 전부 통제 | **RLS 설계가 필수 과제로 추가** |
| 백그라운드 작업 | `BackgroundTasks` | **`EdgeRuntime.waitUntil()`** |

즉, 배포·인증이 쉬워지는 대신 **RLS 설계**라는 숙제가 생긴다. 아래 3장이 그 부분.

---

## 2. DB 스키마 (Postgres)

기획서 3테이블 유지. Supabase Auth의 `auth.users`를 유저 테이블로 그대로 쓰므로 별도 `user` 테이블은 만들지 않는다.

```sql
-- ─────────────────────────────────────────────
-- hatti_state : 유저당 1행. 캐릭터 상태.
-- ─────────────────────────────────────────────
create table public.hatti_state (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  intimacy          int  not null default 0,   -- 누적, 감소 없음
  streak            int  not null default 0,
  last_checkin_date date,
  stage             int  not null default 1,   -- 1~3
  -- 선택 요소 (홈 상시 인터랙션)
  pet_count         int  not null default 0,   -- 쓰다듬기 누적(정서적 지표. 친밀도와 무관)
  today_weather     text,                      -- 오늘 고른 날씨. 날짜 바뀌면 초기화
  weather_date      date,                      -- today_weather가 어느 날짜 것인지
  last_card_date    date,                      -- 마지막으로 카드를 뽑은 날 (하루 1장)
  last_card_id      text,                      -- 그날 뽑은 카드
  updated_at        timestamptz not null default now()
);

-- ─────────────────────────────────────────────
-- checkin_log : 체크인 1회 = 1행.
-- ─────────────────────────────────────────────
create table public.checkin_log (
  id              bigserial primary key,
  user_id         uuid not null references auth.users(id) on delete cascade,
  created_at      timestamptz not null default now(),
  period          text not null check (period in ('morning','evening')),
  raw_text        text not null check (char_length(raw_text) <= 500),  -- 민감정보 (§7 참조)
  emotion         text check (emotion in ('fatigue','anxiety','anger','sadness','joy','neutral')),
  intensity       int  check (intensity between 1 and 5),
  context_keyword text,
  empathy         text,
  affirmation     text,
  crisis_flag     boolean not null default false,
  weather         text,                         -- 유저가 홈에서 고른 날씨(선택). null 가능
  diary           text                          -- 3차 호출 결과, 나중에 채워짐
);

create index checkin_log_user_created_idx
  on public.checkin_log (user_id, created_at desc);
```

### 컬럼 설계 노트
- `stage`는 `intimacy`에서 파생되지만 **저장한다** — 조회 시 계산 부담을 줄이고, 나중에 임계값을 바꿔도 과거 기록이 남는다.
- `diary`는 nullable. 백그라운드로 채워지므로 앱은 "생성 중" 상태를 처리해야 한다.
- `raw_text`는 감정 원문 = 민감정보. 7장의 보존 정책과 세트로 봐야 한다.

---

## 3. RLS (Row Level Security) — Supabase 전환의 핵심

**RLS를 켜지 않으면 anon 키만으로 전 유저의 감정 일기가 조회된다.** 감정 앱에서 이건 치명적이다. 테이블 생성 직후 반드시 활성화한다.

```sql
alter table public.hatti_state enable row level security;
alter table public.checkin_log enable row level security;

-- 읽기: 본인 것만. (앱이 직접 조회하는 경로)
create policy "own state read" on public.hatti_state
  for select using (auth.uid() = user_id);

create policy "own log read" on public.checkin_log
  for select using (auth.uid() = user_id);
```

### 쓰기 정책을 만들지 않는 것이 의도다

`insert` / `update` 정책을 **일부러 만들지 않는다.** 그러면 anon 키(=앱)로는 아무것도 쓸 수 없다.
Edge Function은 `service_role` 키를 쓰는데, 이 키는 **RLS를 우회**하므로 정상 동작한다.

결과적으로:
- 앱 → 읽기만 가능, 그것도 본인 것만
- Edge Function → 쓰기 담당, 친밀도·스트릭 조작 불가능

> **주의:** `service_role` 키는 모든 RLS를 무시하는 마스터 키다. **절대 Flutter 앱에 넣지 않는다.** Edge Function의 환경변수로만 존재해야 한다. 앱에는 `anon` 키만.

---

## 4. Edge Function 로직

### 4.1 파일 구성

```
supabase/functions/checkin/
├── index.ts        # 오케스트레이션 (핵심)
├── gemini.ts       # Gemini 호출 + JSON 파싱 + 안전필터 대응
├── prompts.ts      # 3개 시스템 프롬프트
├── logic.ts        # 순수 로직 (스트릭/단계/위기 프리필터)
└── content.ts      # 감정 라벨 / 확언 풀 / 위기 리소스
```

### 4.2 오케스트레이션 순서 (`index.ts`)

```
1. JWT에서 user_id 추출 (Authorization 헤더)
2. text 검증 (빈 값 차단 / **500자 초과 차단** — 클라이언트 제한은 우회 가능)
3. 위기 프리필터 — 결정적 키워드 매칭
4. Gemini 1차 호출 → { emotion, intensity, context_keyword, crisis_flag }
   ※ 안전필터로 차단되면(finishReason=SAFETY) → 위기로 간주하고 6번으로
5. crisis = 프리필터 OR crisis_flag        ← 이중 방어
6. if (crisis):
     - checkin_log 기록 (crisis_flag=true)
     - 친밀도/스트릭 갱신 안 함            ← 게임화 스킵
     - 위기 리소스 반환하고 종료
7. **기억 조회 (SQL 1회)** — 같은 감정의 최근 기록 1건 (§4.8)
8. Gemini 2차 호출 → 하띠 공감 대사 (+ 기억 주입)
8. 확언 매칭 (감정별 풀에서 랜덤)
9. hatti_state 갱신 (친밀도+1, 스트릭, 단계) + checkin_log 기록
10. EdgeRuntime.waitUntil(일기 3차 호출)   ← 응답 후 백그라운드
11. 응답 반환
```

### 4.3 순수 로직 (`logic.ts`)

FastAPI 버전에서 검증 완료된 규칙. 그대로 TS로 이관.

```ts
// 성장 단계
export const stageOf = (intimacy: number) =>
  intimacy >= 7 ? 3 : intimacy >= 3 ? 2 : 1;

// 스트릭: 어제=+1 / 오늘 중복=유지 / 공백=리셋
export function nextStreak(prev: number, last: string | null, today: string): number {
  if (!last) return 1;
  const days = Math.round(
    (Date.parse(today) - Date.parse(last)) / 86400000
  );
  if (days === 0) return prev;   // 오늘 이미 체크인 → 중복 증가 방지
  if (days === 1) return prev + 1;
  return 1;                       // 하루 이상 공백 → 리셋
}

// 위기 프리필터 (LLM 호출 전 빠른 차단)
const CRISIS_KEYWORDS = ["죽고싶","자살","사라지고싶","살기싫","없어지고싶","끝내고싶","죽어버","목숨"];
export const isCrisisPrefilter = (t: string) => CRISIS_KEYWORDS.some(k => t.includes(k));
```

**타임존 주의:** 스트릭은 유저 체감의 "하루"를 따라야 한다. Edge Function은 UTC로 도는데, 한국 유저가 밤 10시에 체크인하면 UTC로는 다음 날이 되어 스트릭이 잘못 끊긴다. **날짜는 KST(UTC+9) 기준으로 계산**할 것. (앱이 타임존을 넘겨주는 방식도 가능)

### 4.4 Gemini 호출 (`gemini.ts`)

Edge Function은 Deno라 SDK 없이 **`fetch`로 REST 직접 호출**한다. (`@google/generative-ai` SDK도 있지만 의존성 없이 fetch가 단순하다.)

```ts
const GEMINI_KEY = Deno.env.get("GEMINI_API_KEY")!;
const BASE = "https://generativelanguage.googleapis.com/v1beta/models";

async function callGemini(model: string, system: string, user: string, opts: {
  maxTokens: number; temperature: number; schema?: object;
}): Promise<{ text: string | null; blocked: boolean }> {
  const body: any = {
    systemInstruction: { parts: [{ text: system }] },
    contents: [{ role: "user", parts: [{ text: user }] }],
    generationConfig: {
      temperature: opts.temperature,
      maxOutputTokens: opts.maxTokens,
    },
    safetySettings: SAFETY_SETTINGS,   // §4.4.1 필수
  };

  // 구조화 출력 — 1차 호출에서만 사용
  if (opts.schema) {
    body.generationConfig.responseMimeType = "application/json";
    body.generationConfig.responseSchema = opts.schema;
  }

  const res = await fetch(`${BASE}/${model}:generateContent?key=${GEMINI_KEY}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Gemini ${res.status}: ${await res.text()}`);

  const data = await res.json();

  // 안전필터에 걸리면 candidates가 비거나 finishReason=SAFETY
  const cand = data.candidates?.[0];
  if (!cand || cand.finishReason === "SAFETY" || data.promptFeedback?.blockReason) {
    return { text: null, blocked: true };
  }
  const text = (cand.content?.parts ?? [])
    .map((p: any) => p.text ?? "").join("").trim();
  return { text, blocked: false };
}
```

**Claude 대비 달라지는 점**

| | Claude | Gemini |
|---|---|---|
| 시스템 프롬프트 | `system` 파라미터 | `systemInstruction.parts[]` |
| 유저 메시지 | `messages[]` | `contents[].parts[]` |
| 응답 경로 | `data.content[].text` | `data.candidates[0].content.parts[].text` |
| 인증 | `x-api-key` 헤더 | **URL 쿼리 `?key=`** |
| 토큰 제한 | `max_tokens` | `generationConfig.maxOutputTokens` |
| JSON 강제 | 프롬프트로 지시 + 파싱 방어 | **`responseSchema`로 스키마 강제** |
| 안전필터 | 거의 없음 | **있음 — 아래 4.4.1** |

#### 4.4.1 ⚠️ 안전필터 — 하띠에서 가장 중요한 변경점

Gemini는 자해 관련 입력에 **안전필터**가 걸린다. 하띠는 감정 앱이므로 이게 정면으로 문제가 된다.

- 유저가 "죽고싶어"라고 쓰면 → Gemini가 **응답 자체를 거부**할 수 있다 (`finishReason: "SAFETY"`).
- 이때 코드가 `candidates[0]`을 그냥 읽으면 **크래시**한다. 즉 위기 상황에서 앱이 터진다. 최악의 시나리오다.

**대응 원칙: 차단 = 위기 신호로 간주한다.**

```ts
const { text, blocked } = await callGemini(...);
if (blocked) {
  // 감정 분석을 못 했다 ≠ 무시해도 된다
  // 안전필터가 걸릴 정도의 입력 → 위기 분기로 보내는 것이 안전한 기본값
  return crisisResponse();
}
```

즉 하띠의 위기 감지는 **3중 방어**가 된다:
1. 결정적 키워드 프리필터 (LLM 호출 전)
2. Gemini의 `crisis_flag` 판정
3. **Gemini 안전필터 차단 → 위기로 간주** ← Gemini 전환으로 새로 추가

**공감 호출(2차)의 안전 설정**은 완화 쪽으로 잡되, 위기가 아닌 일상적 부정 감정("우울해", "다 싫다")까지 차단되면 앱이 먹통이 되므로 임계값을 낮춘다.

```ts
const SAFETY_SETTINGS = [
  { category: "HARM_CATEGORY_HARASSMENT",        threshold: "BLOCK_ONLY_HIGH" },
  { category: "HARM_CATEGORY_HATE_SPEECH",       threshold: "BLOCK_ONLY_HIGH" },
  { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_ONLY_HIGH" },
  { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_ONLY_HIGH" },
];
```

> **필수 테스트:** "우울해", "다 포기하고 싶다", "너무 힘들어" 같은 **경계선 입력**이 차단되지 않는지 데모 전에 반드시 확인. 차단되면 정상 유저가 위기 화면을 보게 된다.

#### 4.4.2 JSON 파싱 — 오히려 단순해진다

Gemini의 `responseSchema`는 JSON 구조를 **API 레벨에서 강제**하므로, Claude용으로 짰던 `safeJson` 정규식 방어가 사실상 불필요해진다.

```ts
export const EMOTION_SCHEMA = {
  type: "object",
  properties: {
    emotion:         { type: "string", enum: ["fatigue","anxiety","anger","sadness","joy","neutral"] },
    intensity:       { type: "integer" },
    context_keyword: { type: "string" },
    crisis_flag:     { type: "boolean" },
  },
  required: ["emotion", "intensity", "context_keyword", "crisis_flag"],
};
```

`enum`으로 감정 키가 강제되므로 잘못된 라벨이 올 수 없다. 다만 **폴백은 유지**한다 — 안전필터 차단이나 네트워크 오류로 `text`가 null일 수 있기 때문. `intensity`는 여전히 1~5로 clamp할 것.

프롬프트에서 `"JSON만 출력해라"` 지시문은 이제 불필요하므로 제거해도 된다.

### 4.5 모델 선택 (무료 티어)

| 호출 | 모델 | 이유 |
|------|------|------|
| 1차 감정 분석 | `gemini-2.0-flash` | JSON 추출은 단순 작업. 가장 빠르고 쿼터 여유 |
| 2차 공감 대사 | `gemini-2.5-flash` | 하띠 페르소나 품질이 곧 제품 가치. Pro는 무료 쿼터가 빡빡함 |
| 3차 하띠 일기 | `gemini-2.5-flash` | 백그라운드라 지연 무관 |

**무료 티어 쿼터 (RPM/RPD)** 는 모델·시점에 따라 바뀌므로 [AI Studio 요금 페이지](https://ai.google.dev/pricing)에서 확인할 것. 체크인 1회 = **2~3 호출**이므로, 데모 중 반복 테스트하면 분당 제한(RPM)에 걸릴 수 있다.

> **데모 리스크:** 발표 직전 리허설로 쿼터를 태우면 본 발표에서 429가 난다. 리허설용 키와 발표용 키를 분리하거나, 429 시 목업 응답으로 폴백하는 경로를 넣어둘 것.

### 4.6 프롬프트 요지 (`prompts.ts`)

- **ANALYZE**: 감정 분류 기준만 서술. **JSON 형식 지시는 불필요** — `responseSchema`가 강제한다. `temperature: 0.2`
- **EMPATHY**: 하띠 페르소나 + **금지어**("힘내", "파이팅", "괜찮아질 거야", 조언, 지시, 평가, 이모지) + **2문장 제한** + 친밀도별 말투 분기. `temperature: 0.85`
- **DIARY**: 하띠 1인칭 시점, 2~3문장, 조언·응원 금지. `temperature: 0.9`

### 4.7 백그라운드 일기 생성

```ts
// 응답을 먼저 보내고, 일기는 뒤에서 생성 → 사용자 체감 지연 감소
EdgeRuntime.waitUntil(
  generateDiary(logId, emotionKo, context, text)
);
return new Response(JSON.stringify(payload), { headers: corsHeaders });
```

앱은 응답의 `checkin_id`로 나중에 일기를 조회한다. (폴링 또는 Supabase Realtime 구독)

---

### 4.8 하띠의 "기억" — RAG 대신 SQL

**결정: RAG를 쓰지 않는다.** 벡터 검색·임베딩·pgvector 없이, `checkin_log` SQL 1회로 같은 값을 만든다.

**근거**
- 확언 풀은 12개다. 벡터 검색이 필요한 규모가 아니다(수백 개까지는 프롬프트에 통째로 넣는 게 빠르고 정확).
- 심리학 지식 RAG(CBT 기법 등)는 **"공감 only" 원칙과 충돌**한다. 기법을 검색해 답에 섞으면 하띠는 열등한 Wysa가 된다. 이건 기술 판단이 아니라 제품 판단.
- 정작 원하는 값("하띠가 나를 기억함")은 `emotion` / `context_keyword` / `created_at`이 **이미 컬럼으로 존재**하므로 SQL로 정확히 얻어진다. 벡터 유사도는 "왜 이게 검색됐는지" 설명이 안 되는데, 감정 앱에서 엉뚱한 과거를 소환하면 신뢰가 무너진다.
- 추가 LLM/임베딩 호출 0회 → 무료 티어 쿼터·지연에 영향 없음.

> **나중에 RAG가 정당해지는 시점:** `raw_text`가 유저당 수백 건 쌓여, 원문 뉘앙스로 "비슷한 기분이었던 날"을 찾아야 할 때. Supabase는 pgvector를 지원하므로 그때 붙이면 된다. **지금 안 해도 나중에 막히지 않는 구조**라는 점이 미뤄도 되는 근거.

**쿼리** (2차 호출 직전, 정상 경로에서만)

```sql
select context_keyword,
       (current_date at time zone 'Asia/Seoul')::date - created_at::date as days_ago
from checkin_log
where user_id = $1
  and emotion = $2            -- 이번 체크인과 같은 감정
  and crisis_flag = false
  and created_at < current_date at time zone 'Asia/Seoul'   -- 오늘 제외
order by created_at desc
limit 1;
```

**주입 가드** (`prompts.py` / `logic.ts`의 `shouldInjectMemory`)

| 조건 | 이유 |
|---|---|
| 친밀도 ≥ 3 | 만난 지 이틀 된 하띠가 과거를 소환하면 다정함이 아니라 **감시**로 느껴진다 |
| `emotion != neutral` | "잔잔함"을 기억해봐야 의미 없음 |
| 1 ≤ `days_ago` ≤ 30 | 오늘 제외(같은 날 "지난번에도"는 어색), 너무 오래된 기억도 어색 |
| 위기 경로에선 스킵 | 안전 분기에 게임화·서사 요소를 섞지 않는다 |

**⚠️ 가장 큰 리스크: 기억이 "지적"이 되는 것**

`"또 회의 때문에 지쳤구나"` — 이건 기억이 아니라 **평가**이고, EMPATHY_SYSTEM의 금지 규칙(평가·판단 금지)을 위반한다. 부정 감정이 반복될수록 위험이 커지는데 하필 피로·불안이 하띠의 주력 감정이다. 프롬프트에 명시적 예시로 억제한다:

- ❌ "또 회의 때문에 지쳤네" / "너 요즘 계속 불안해하는 것 같아"
- ✅ "지난번에도 회의가 너를 참 많이 데려갔었지"

또한 **"억지로 쓰지 마라, 어색하면 아예 빼라"**를 명시 — 기억은 재료일 뿐 의무가 아니다. 오늘의 마음이 주인공이고 과거는 한 줄을 넘지 않는다.

**우선순위: SHOULD** — 데모 임팩트는 큰데(하띠가 나를 기억하는 순간이 화면에 보임) 비용은 SQL 1회. 다만 데모에서 보이려면 **같은 감정의 과거 기록이 시드로 있어야 한다**(§10 참조).

---

## 5. 인증 — 익명 로그인

해커톤에서 회원가입 화면을 만들면 데모 시간만 잡아먹는다. Supabase 익명 로그인이면 첫 실행에 자동으로 유저가 생기고, `auth.uid()`가 발급되어 RLS가 그대로 작동한다.

```dart
// 앱 첫 실행 시
final session = Supabase.instance.client.auth.currentSession;
if (session == null) {
  await Supabase.instance.client.auth.signInAnonymously();
}
```

**설정:** Supabase 대시보드 → Authentication → Providers → Anonymous sign-ins 활성화.

**한계 (문서화해둘 것):** 앱을 지우면 계정이 사라진다 = 하띠도 사라진다. 프로덕션에서는 나중에 계정 연동(카카오/애플)으로 승격시키는 흐름이 필요.
`[iOS 정책]` 소셜 로그인을 붙이는 순간 **Apple 로그인 필수** (미준수 시 심사 리젝).

---

## 6. Flutter 연동

### 6.1 패키지

```yaml
dependencies:
  supabase_flutter: ^2.5.0    # Auth + DB + Functions 한 번에
  provider: ^6.1.0            # 상태관리 (해커톤 규모엔 이걸로 충분)
```

`dio`는 불필요하다 — `supabase_flutter`가 Edge Function 호출까지 처리한다.

### 6.2 초기화

```dart
await Supabase.initialize(
  url: 'https://xxxx.supabase.co',
  anonKey: '...',   // anon 키만! service_role 절대 금지
);
```

### 6.3 체크인 호출

```dart
final res = await Supabase.instance.client.functions.invoke(
  'checkin',
  body: {'text': text, 'period': period},
);
// JWT는 supabase_flutter가 자동으로 헤더에 실어준다
final data = res.data;

if (data['crisis'] == true) {
  // 위기 화면으로 분기 — 공감/확언/게임화 없음
} else {
  // 감정 → 공감 → 확언 카드
}
```

### 6.4 홈 상태 조회 (DB 직접 읽기 — RLS가 지켜줌)

```dart
final state = await Supabase.instance.client
    .from('hatti_state').select().single();

final recent = await Supabase.instance.client
    .from('checkin_log')
    .select('emotion, created_at')
    .eq('crisis_flag', false)
    .order('created_at', ascending: false)
    .limit(4);
```

### 6.5 상태관리

`ChangeNotifier` 하나(`HattiService`)에 친밀도·스트릭·단계·히스토리를 담고 `provider`로 주입. Riverpod/Bloc은 이 규모에 과하다.

### 6.6 화면 구성 (프로토타입에서 검증 완료)

| 화면 | 내용 |
|------|------|
| 홈 | 하띠 캐릭터, 친밀도/스트릭, 시간대 표시, 체크인 버튼, 최근 감정 칩 |
| 입력 | 하띠 질문 + 자연어 입력 |
| 분석중 | 하띠 애니메이션 + "마음을 읽는 중" |
| 응답 | 감정 라벨+강도 → 하띠 공감 → 확언 손편지 카드 |
| 위기 | 하띠 대신 전문 리소스 연결 (109 등) |

**시간대 자동 판정** (프로토타입 확정 사항): 05:00~11:59 = 아침(의도 설정) / 그 외 = 저녁(회고). 수동 토글 없음, 접속 시각으로 자동 결정.

---

## 7. 보안 & 개인정보

| 항목 | 처리 |
|------|------|
| **Gemini API 키** | Edge Function 환경변수. 앱에 절대 없음. |
| **service_role 키** | Edge Function 환경변수. 앱에 절대 없음. |
| **anon 키** | 앱에 포함(정상). RLS가 있어야만 안전하다. |
| **감정 원문(`raw_text`)** | 민감 개인정보. RLS로 본인만 조회. |
| **제3자 제공** | 없음. |
| **데이터 삭제** | 유저 요청 시 즉시 삭제 (`on delete cascade`로 연쇄 삭제됨) |
| **LLM 학습** | ⚠️ **무료 티어 주의 — 아래 7.1** |

### 7.1 ⚠️ Gemini 무료 티어와 감정 데이터

**Gemini API 무료 티어는 유료 티어와 데이터 취급 정책이 다르다.** 일반적으로 무료 티어의 입출력은 서비스 품질 개선(사람 검토 포함)에 활용될 수 있는 반면, 유료 티어는 그렇지 않다. 정확한 조건은 [Gemini API 이용약관](https://ai.google.dev/gemini-api/terms)에서 최신 내용을 확인할 것.

하띠에서 이게 중요한 이유:

- 하띠가 보내는 건 **유저의 감정 원문**이다. 민감 개인정보에 해당한다.
- 기획안 6장은 "제3자 절대 비공유", "AI API 호출 시 대화 학습 opt-out 적용"을 명시했다. **무료 티어에서는 이 약속을 그대로 지키기 어려울 수 있다.**

**대응 (택1):**

| 안 | 내용 | 적합 |
|---|---|---|
| **A. 해커톤 한정 무료 티어** | 실 유저 데이터가 아닌 데모 데이터만 다룸. 문서·발표에 "MVP는 무료 티어, 실서비스 시 유료 전환" 명시 | ✅ **해커톤 권장** |
| B. 유료 티어 전환 | 실 유저를 받는 순간 필수 | 프로덕션 |
| C. 원문 최소화 | 1차 분석 후 `raw_text` 대신 감정 라벨만 2차 호출에 전달 | 품질 저하 트레이드오프 |

**해커톤에서는 A로 가되, 발표에서 "실서비스 시 유료 티어 전환 + 데이터 보호"를 로드맵으로 언급하는 것이 오히려 심사 강점이 된다.** 감정 데이터의 민감성을 인지하고 있다는 신호이기 때문. 기획안 6장 문구는 "MVP 기준"임을 명시하도록 수정 필요.

**포스트-MVP 과제:** `raw_text` 보존기간 정책, 계정 삭제 UI, 개인정보 처리방침·이용약관 문서(스토어 등록 필수), **유료 티어 전환**.

---

## 8. 배포

```bash
# 1. 로컬 개발
supabase start
supabase functions serve checkin --env-file ./supabase/.env.local

# 2. 시크릿 등록 (한 번만)
supabase secrets set GEMINI_API_KEY=...   # Google AI Studio에서 발급

# 3. 배포
supabase db push                      # 스키마 + RLS
supabase functions deploy checkin
```

`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY`는 Edge Function 런타임에 **자동 주입**되므로 따로 등록할 필요 없다.

**CORS:** Edge Function에 CORS 헤더와 `OPTIONS` 프리플라이트 처리를 넣어둘 것. (Flutter 웹으로 데모할 경우 필수)

---

## 9. MVP 범위 (기획서 유지)

| 우선순위 | 기능 | 상태 |
|---|---|---|
| MUST | 감정 체크인 풀 루프 | 로직 확정, 프로토타입 검증 완료 |
| MUST | 하띠 캐릭터 (친밀도/3단계/말투) | 로직 확정 |
| MUST | 아침/저녁 자동 분리 | **확정 — 접속 시각 기반** |
| MUST | 스트릭 마일스톤 (3/7/14일) | 로직 확정 |
| **MUST** | **위기 분기** | **기획서에 없었으나 추가 — 8.1 참조** |
| SHOULD | **하띠의 "기억"** | **RAG 대신 SQL — §4.8. 데모 임팩트 대비 비용 최저** |
| SHOULD | 하띠 일기 | 백그라운드 생성으로 설계 |
| SHOULD | 감정 히스토리 | DB 직접 조회 |
| CUT | 푸시 / 대시보드 / 소셜 | 로드맵 이관 |

### 9.1 위기 분기를 MUST로 올린 이유

원 기획서에는 `crisis_flag`만 있고 실제 분기 흐름이 정의돼 있지 않았다. 멘탈 웰니스 앱에서 이건 두 가지 이유로 필수다.

1. **안전** — 자해 신호에 하띠가 "공감"으로 답하면 안 된다. 사람의 도움으로 연결해야 한다.
2. **심사 강점** — 안전 설계를 갖춘 것 자체가 데모에서 신뢰를 준다.

**"공감 only" 원칙의 유일한 예외 지점**이므로, 설계 원칙 문서에도 예외로 명시해둘 것.

---

## 10. Day1 / Day2 계획 (Supabase 반영)

**Day 1 — 구조 + 핵심 연동**
- 오전: Supabase 프로젝트 생성, 스키마 + **RLS 적용**, 익명 로그인 활성화
- 오전: 하띠 캐릭터 에셋 (3단계)
- 오후: Gemini API 키 발급(AI Studio) + Edge Function `checkin` — 1차/2차 호출 + `responseSchema` + **위기 분기**
- 오후: Flutter 체크인 UI (입력 + 결과)
- 저녁: 앱 ↔ Edge Function 연결, **안전필터 경계선 테스트** + 톤 일탈 테스트

**Day 2 — 완성 + 테스트 + 발표**
- 오전: 스트릭/친밀도/성장 단계 + 아침/저녁 자동 판정
- 오전: 하띠 일기 (백그라운드) + 일기 뷰
- 오후: 확언 카드 + 성장 전환 + 히스토리
- 오후: 하띠의 "기억" (SQL 주입) + **데모용 과거 기록 시드**
- 오후: **데모 시나리오 3종 + 위기 분기 시연** + 톤 일탈 테스트
- 저녁: 발표 자료 + 리허설

---

## 11. 리스크

| 리스크 | 대응 |
|--------|------|
| **RLS 누락** | 테이블 생성 직후 바로 `enable row level security`. 앱 anon 키로 남의 데이터가 조회되는지 반드시 테스트. |
| **안전필터 오작동** | 경계선 입력("우울해", "힘들어")이 차단되면 정상 유저가 위기 화면을 봄. `BLOCK_ONLY_HIGH` + 데모 전 경계선 입력 테스트 필수. |
| **안전필터 크래시** | 차단 시 `candidates[0]`이 없음 → 위기 상황에서 앱 크래시. `blocked` 체크 후 위기 분기로. |
| **무료 티어 쿼터(429)** | 체크인 1회=2~3콜. 리허설로 쿼터 소진 주의. 리허설/발표 키 분리 또는 429 폴백 경로. |
| **무료 티어 데이터 정책** | 감정 원문이 품질 개선에 활용될 수 있음. §7.1 — 해커톤은 데모 데이터만, 실서비스는 유료 전환. |
| **순차 3-call 지연** | 일기는 백그라운드. 분석은 `gemini-2.0-flash`. 데모 로딩 최소화. |
| **JSON 파싱 실패** | `responseSchema`로 대부분 해소. 단 차단·오류 대비 neutral 폴백 유지. |
| **스트릭 타임존 버그** | KST 기준 날짜 계산. UTC 그대로 쓰면 밤 체크인이 잘못 끊김. |
| **톤 일탈** ("힘내" 등) | 시스템 프롬프트 금지어 + 데모 전 일탈 테스트 필수. |
| **기억이 "지적"이 됨** | "또 지쳤네" = 평가. 프롬프트 예시로 억제 + 친밀도/기간 가드. §4.8 |
| **데모에서 기억 안 보임** | 신규 계정은 과거 기록이 없어 기능이 발동하지 않음. **시드 데이터 필수.** |
| **service_role / Gemini 키 유출** | 앱 코드·git에 절대 금지. Edge Function 환경변수만. 무료 키라도 쿼터 소진·오남용 위험. |
| **익명 계정 소실** | 앱 삭제 = 하띠 소실. MVP 한계로 명시, 로드맵에 계정 연동. |

---

## 12. 확정된 설계 원칙 (변경 시 재검토 필요)

1. **보상 only** — 방치 패널티 없음. 친밀도는 누적, 감소하지 않음. (불안 유발 리텐션은 심리앱에서 모순)
2. **공감 only** — 조언·응원·교정 금지. **유일한 예외: 위기 분기.**
3. **앱은 읽기, 서버는 쓰기** — 게임화 무결성과 키 보안의 근거.
4. **AI 키는 서버에만** — 타협 불가.
5. **시간대는 자동** — 유저가 아침/저녁을 고르지 않는다.

---

## 부록 A. 현재 산출물

| 산출물 | 형태 | 상태 |
|--------|------|------|
| 기획안 | md | 확정 |
| 화면 흐름 프로토타입 | React (목업 AI) | 검증 완료 — Flutter 이관 기준 |
| 백엔드 로직 | Python/FastAPI + Claude | 순수 로직은 검증 완료 — **Edge Function(TS) + Gemini로 이관 대상** |
| 이 문서 | md | 개발 기준 |

FastAPI 구현체는 폐기하지 않고 **로직 레퍼런스**로 유지한다. 단, 재사용 범위를 구분할 것:

| FastAPI 자산 | Gemini + Edge Function 이관 시 |
|---|---|
| `logic.py` (스트릭/단계/위기 프리필터) | ✅ **그대로 이관** — 단위 테스트 검증 완료. TS로 번역만 |
| `content.py` (감정 라벨/확언 풀/위기 리소스) | ✅ **그대로 이관** |
| `prompts.py` | 🔶 **부분 재사용** — 페르소나·금지어는 유지, JSON 지시문은 제거(`responseSchema`가 대체) |
| `claude_client.py` | ❌ **폐기** — API 형태가 다름. `gemini.ts`로 신규 작성 |

스트릭·단계·위기 프리필터는 이미 검증된 상태이므로, TS 이관 후 동일 케이스로 재검증하면 된다.

## 부록 B. 다음 작업 후보

- Edge Function `checkin/index.ts` + `gemini.ts` 실제 구현 (FastAPI 로직 TS 이관)
- 스키마 + RLS 마이그레이션 파일
- Flutter `HattiService` + Supabase 연동
- **안전필터 경계선 입력 테스트 세트** 작성 ("우울해", "다 포기하고 싶다", "너무 힘들어" 등)
- 기획안 6장(보안) 문구를 무료 티어 현실에 맞게 수정 — §7.1
- 확언을 LLM 매칭(AI #3)으로 승격할지 결정 — 현재는 큐레이션 풀(결정적·저지연·쿼터 절약) vs LLM(맥락 정밀·쿼터 소모) 트레이드오프. **무료 티어에서는 풀 유지가 유리**
