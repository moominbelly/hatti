# 하띠(Hatti) API 계약 및 상태 흐름 설계서

본 문서는 하띠(Hatti) 앱의 프론트엔드(Flutter)와 백엔드(Supabase Edge Function) 간의 연동 규격, 상태 관리 흐름, 그리고 에러/위기 처리 로직을 정의합니다.

## 1. API 요청/응답 스키마

**엔드포인트:** `POST /functions/v1/checkin`
**인증:** Supabase Auth JWT (`Authorization: Bearer <token>`)

앱은 데이터 읽기는 Supabase 클라이언트를 통해 직접 수행하고, **쓰기(체크인)는 반드시 이 Edge Function을 통해서만 수행**합니다.

### 1.1. Request Schema
```json
{
  "text": "오늘 회의가 너무 많아서 힘들었어...",
  "period": "evening" // "morning" 또는 "evening"
}
```

### 1.2. Response Schema

Edge Function은 `status` 필드를 통해 3가지 응답 형태(정상, 위기, 에러)를 반환합니다.

**① 정상 응답 (status: "success")**
```json
{
  "status": "success",
  "data": {
    "emotion": "fatigue",
    "context_keyword": "회의 과부하",
    "empathy": "오늘 하루가 너를 참 무겁게 눌렀구나. 푹 쉬었으면 좋겠어.",
    "affirmation": "나는 충분히 최선을 다하고 있다.",
    "milestones": ["stage_up_2", "streak_3"] // 마일스톤 달성 시에만 배열에 포함
  }
}
```

**② 위기 분기 응답 (status: "crisis")**
2차 호출(공감/일기)을 생략하고 즉시 반환하는 short-circuit 응답입니다.
```json
{
  "status": "crisis",
  "data": {
    "message": "지금 많이 힘들고 지쳐 보이네요. 혼자 견디지 않아도 괜찮아요. 아래 연락처에서 도움을 받을 수 있어요.",
    "hotlines": [
      { "name": "자살예방상담전화", "number": "109" },
      { "name": "정신건강상담전화", "number": "1577-0199" },
      { "name": "청소년전화", "number": "1388" }
    ]
  }
}
```

**③ 에러/타임아웃 응답 (status: "error")**
사용자에게는 기술 용어를 노출하지 않고 일관된 메시지를 제공하되, 서버 로그 및 클라이언트의 재시도 처리를 위해 `error_code`를 구분합니다.
```json
{
  "status": "error",
  "error_code": "TIMEOUT", // TIMEOUT, QUOTA_EXCEEDED, NETWORK_ERROR, INTERNAL_ERROR 등
  "message": "앗, 하띠가 생각을 정리하다가 길을 잃었어요. 다시 들려줄래요?"
}
```

---

## 2. 5-State 화면 흐름 및 클라이언트 상태 관리

| 상태 | 화면명 | 동작 및 API 연동 | 상태 전환 조건 |
|---|---|---|---|
| **S1** | **Home (홈)** | 사용자의 현재 캐릭터 단계(Stage)와 친밀도, 스트릭 표시. | 체크인 시작 버튼 탭 → **S2** |
| **S2** | **Input (입력)** | 오늘의 마음을 텍스트로 입력. 로컬 상태에 텍스트 저장. | 전송 버튼 탭 → API 호출 시작, **S3** |
| **S3** | **Analyzing (분석중)** | 로딩 애니메이션 노출. <br/> **중복 호출 방지:** 화면 이탈 및 뒤로가기 차단. Edge Function은 클라이언트가 재생성한 `idempotency_key`를 헤더로 받아 중복을 방어할 수도 있습니다. | API 응답 `success` → **S4**<br/>API 응답 `crisis` → **S5**<br/>API 응답 `error` → 에러 스낵바 노출 후 **S3 유지** |
| **S4** | **Response (응답)** | 반환된 `empathy`와 `affirmation` 노출. <br/> `milestones` 배열이 존재하면 성장 토스트/팝업 트리거. | 마치기 버튼 탭 → **S1** |
| **S5** | **Crisis (위기)** | 위기 응답 텍스트와 상담 전화번호(hotlines) 노출. 게임화(친밀도 등) 요소 노출 차단. | 홈으로 버튼 탭 → **S1** |

> **[중요] 입력 텍스트 보존 원칙 (에러 핸들링)**
> 타임아웃(10초)이나 429(Rate Limit) 발생 시, 입력된 `text`는 **클라이언트 로컬 상태(S2/S3)**에 그대로 유지되어야 합니다. 서버에 임시 저장하지 않으며, 클라이언트가 재시도 버튼을 누르면 기존 텍스트로 다시 API를 호출합니다.

---

## 3. 내부 오케스트레이션 7단계 매핑 (Edge Function 내부)

1. **위기 프리필터**: 사용자 `text`를 정규식/금지어 리스트로 검사. 트리거 시 즉시 3단계로 점프.
2. **1차 AI 호출 (Gemini 2.0)**: `text` 입력 → `emotion`, `intensity`, `context_keyword`, `crisis_flag` 추출.
3. **위기 분기 판단**: 1단계 프리필터 통과 실패, 또는 1차 AI 결과 `crisis_flag == true`, 또는 AI 세이프티 필터 트리거 시 → **2차/3차 호출 전면 생략 (Short-circuit)**. 클라이언트에 `status: "crisis"` 응답.
4. **2차 AI 호출 (Gemini 2.5)**: 1차 분석 결과와 DB의 과거 기록(기억)을 프롬프트에 주입하여 `empathy` 생성.
5. **확언 매칭**: `emotion` 라벨을 기반으로 내부 정적 리스트에서 적절한 `affirmation` 선택.
6. **DB 갱신**: KST(UTC+9) 기준으로 날짜를 변환하여 `hatti_state`의 친밀도(+1) 및 스트릭 갱신, `checkin_log` 레코드 삽입. 마일스톤 달성 여부 체크.
7. **응답 및 비동기 일기 생성**: 클라이언트에 `status: "success"` 응답 후, Edge Function은 종료 전(또는 백그라운드 워커를 통해) 3차 AI를 호출하여 `diary`를 생성하고 `checkin_log` 레코드를 업데이트합니다.

---

## 4. 성장 및 마일스톤 토스트 트리거 조건

마일스톤 달성 여부는 API의 정상 응답 내 `milestones` 배열에 담겨 전달되며, 클라이언트(S4 응답 화면)에서 이를 읽어 축하 애니메이션이나 토스트를 띄웁니다.

- **단계 전환 (친밀도 경계)**:
  - 친밀도 누적 3 도달 시: `"stage_up_2"` (1단계 -> 2단계)
  - 친밀도 누적 7 도달 시: `"stage_up_3"` (2단계 -> 3단계)
- **스트릭 달성**:
  - 연속 3일 체크인: `"streak_3"`
  - 연속 7일 체크인: `"streak_7"`
  - 연속 14일 체크인: `"streak_14"`

*참고: 위기 상황(S5)으로 분기된 경우, 친밀도와 스트릭은 갱신되지 않으므로 마일스톤 이벤트도 발생하지 않습니다.*
