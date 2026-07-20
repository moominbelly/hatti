# 하띠 (Hatti) — Flutter 스캐폴드

프로토타입(`hatti_prototype.jsx`)의 화면·흐름을 Flutter로 옮긴 **실행 가능한 뼈대**.
AI 응답은 목업(키워드 간이분석), 캐릭터는 코드로 그림, 상태는 메모리 저장.

## 실행

이 폴더에는 `lib/`와 `pubspec.yaml`만 있습니다. 플랫폼 폴더(android/ios 등)는
`flutter create`로 생성해야 합니다.

```bash
# 1. 이 폴더에서 플랫폼 코드 생성 (기존 lib/·pubspec은 유지됨)
flutter create .

# 2. 의존성 설치
flutter pub get

# 3. 실행 (에뮬레이터 또는 기기 연결 후)
flutter run
```

> 요구: **Flutter 3.27+** (`Color.withValues` 사용). `flutter --version`으로 확인.
> 첫 실행 시 google_fonts가 폰트를 내려받으므로 **네트워크 연결**이 필요합니다.

## 동작

프로토타입과 동일한 루프:
홈 → 입력 → 분석중 → 응답(감정·공감·확언) → 홈. 위기어 입력 시 위기 화면으로 분기.

테스트 입력:
- 감정별: `너무 피곤하고 지쳤어` / `내일 발표가 너무 불안해` / `오늘 진짜 짜증났어` / `요즘 너무 외롭고 우울해` / `오늘 뿌듯하고 행복했어`
- 위기 분기: `요즘 다 사라지고 싶어`
- 성장/스트릭: 체크인을 반복하면 친밀도 3·7에서 단계 상승, 3/7/14일에 토스트

## 구조

```
lib/
├── main.dart                 앱 진입점 (Provider 주입, 테마)
├── theme.dart                디자인 토큰 (황혼의 둥지 팔레트, 폰트)
├── models/
│   └── emotion.dart          감정 enum + 라벨/색상, CheckinResult 모델
├── data/
│   └── content.dart          질문·인사말·공감·확언·위기리소스 카피
├── logic/
│   └── mock_analysis.dart    목업 감정 분석 (백엔드 연결 시 폐기)
├── services/
│   ├── hatti_service.dart    상태관리(친밀도/스트릭/단계) + 시간대 판정
│   └── api_client.dart       체크인 API (지금은 목업, 교체 지점 표시)
├── widgets/
│   ├── hatti_character.dart   캐릭터 (CustomPainter, 숨쉬기/눈깜빡임)
│   └── common.dart            말풍선·버튼·배경
└── screens/
    ├── home_screen.dart       홈
    └── checkin_flow.dart      입력/분석중/응답/위기 4단계
```

## 백엔드(Supabase + Gemini) 연결 시 바꿀 곳

스캐폴드는 **교체 지점을 한 곳에 모아**뒀습니다.

| 목업 | 실제 연결 |
|------|-----------|
| `services/api_client.dart` 의 `MockAnalysis` 호출 | Supabase Edge Function `checkin` 호출 (파일 상단 주석에 예시 코드) |
| `logic/mock_analysis.dart` | 폐기 — 분석은 서버(Gemini)가 담당 |
| `hatti_service.dart` 메모리 상태 | Supabase `hatti_state` 조회 + (선택) shared_preferences 캐시 |
| `pubspec.yaml` 의 `supabase_flutter` 주석 | 해제 후 `main.dart`에서 `Supabase.initialize` |

`CheckinResult` 모델은 목업/실제가 동일하므로, **UI 코드는 건드릴 필요가 없습니다.**

## 스캐폴드의 한계 (의도적)

- 상태가 메모리 저장이라 앱을 끄면 초기화 (친밀도 2·스트릭 2로 시작).
- 하띠 "일기"(3차 호출)와 "기억"(SQL 주입)은 백엔드 연결 후 추가.
- 플랫폼 폴더 미포함 — `flutter create .` 필요.
- 이 환경(SDK 없음)에서 컴파일 검증을 하지 못했으므로, 첫 빌드 시
  자잘한 오류가 있을 수 있습니다. `flutter run` 출력과 함께 알려주면 바로 잡습니다.
