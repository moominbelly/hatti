import 'dart:math';

import '../models/emotion.dart';
import '../data/content.dart';

/// 목업 감정 분석. 프로토타입의 analyze()를 Dart로 옮긴 것.
/// 백엔드 연결 전까지 UI를 완성된 상태로 돌리기 위한 임시 로직.
/// → 실제 앱에서는 이 파일 대신 Gemini(Edge Function)가 담당한다.
class MockAnalysis {
  static final _rand = Random();

  static const _keywords = <Emotion, List<String>>{
    Emotion.joy: ['좋아', '행복', '기뻐', '신나', '감사', '즐거', '웃', '최고', '재밌'],
    Emotion.calm: ['편안', '안도', '평온', '한숨 돌', '느긋', '여유', '차분', '홀가분', '편해', '괜찮아졌'],
    Emotion.pride: ['뿌듯', '해냈', '성취', '자랑', '대견', '보람', '설레', '기대', '이뤘', '해냄'],
    Emotion.fatigue: ['피곤', '지쳐', '지친', '힘들', '번아웃', '졸려', '쉬고', '방전', '과부하', '야근', '바빠', '벅차'],
    Emotion.anxiety: ['불안', '걱정', '두려', '초조', '긴장', '떨려', '무서', '막막', '조급', '안절부절'],
    Emotion.anger: ['짜증', '화나', '열받', '빡', '억울', '답답', '싫어', '미치', '분해'],
    Emotion.sadness: ['슬퍼', '우울', '외로', '눈물', '공허', '허무', '상처', '쓸쓸', '그리워', '허전'],
    Emotion.guilt: ['자책', '미안', '죄책', '내 탓', '후회', '괜히', '못나', '부끄', '자괴'],
  };

  static const _intensifiers = ['너무', '진짜', '완전', '정말', '엄청', '매우', '개', '많이', '계속', '도저히'];

  static CheckinResult analyze(String text) {
    // 1) 위기 프리필터
    if (Content.crisisKeywords.any(text.contains)) {
      return const CheckinResult.crisis();
    }

    // 2) 감정 매칭 (최다 키워드)
    var best = Emotion.neutral;
    var bestCount = 0;
    _keywords.forEach((emotion, words) {
      final count = words.where(text.contains).length;
      if (count > bestCount) {
        bestCount = count;
        best = emotion;
      }
    });

    // 3) 강도
    var intensity = 2 +
        _intensifiers.where(text.contains).length +
        (text.length > 40 ? 1 : 0);
    intensity = intensity.clamp(1, 5);

    // 4) 맥락 키워드
    final matched = _keywords[best]?.firstWhere(
      text.contains,
      orElse: () => '오늘의 마음',
    );
    final context = (best == Emotion.neutral) ? '오늘의 마음' : (matched ?? '오늘의 마음');

    return CheckinResult(
      crisis: false,
      emotion: best,
      intensity: intensity,
      contextKeyword: context,
      empathy: _pick(Content.empathy[best]!),
      affirmation: _pick(Content.affirmations[best]!),
    );
  }

  static String _pick(List<String> xs) => xs[_rand.nextInt(xs.length)];
}
