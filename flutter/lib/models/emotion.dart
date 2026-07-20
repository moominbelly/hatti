import 'package:flutter/material.dart';

/// 감정 5종 + fallback(neutral). 1차 분석이 반환하는 값과 1:1 대응.
enum Emotion { fatigue, anxiety, anger, sadness, joy, neutral }

extension EmotionMeta on Emotion {
  /// 백엔드/스키마용 키 (enum 이름 그대로)
  String get key => name;

  String get labelKo => switch (this) {
        Emotion.fatigue => '피로',
        Emotion.anxiety => '불안',
        Emotion.anger => '분노',
        Emotion.sadness => '슬픔',
        Emotion.joy => '기쁨',
        Emotion.neutral => '잔잔함',
      };

  Color get tone => switch (this) {
        Emotion.fatigue => const Color(0xFFC98A5B),
        Emotion.anxiety => const Color(0xFF8E86C4),
        Emotion.anger => const Color(0xFFD06B5C),
        Emotion.sadness => const Color(0xFF6B93B0),
        Emotion.joy => const Color(0xFFE0A94E),
        Emotion.neutral => const Color(0xFF9AAE9C),
      };

  static Emotion fromKey(String k) =>
      Emotion.values.firstWhere((e) => e.name == k, orElse: () => Emotion.neutral);
}

/// 체크인 1회 결과. 목업이든 실제 API든 이 형태로 반환된다.
class CheckinResult {
  final bool crisis;
  final Emotion emotion;
  final int intensity; // 1~5
  final String contextKeyword;
  final String empathy;
  final String affirmation;

  const CheckinResult({
    required this.crisis,
    this.emotion = Emotion.neutral,
    this.intensity = 3,
    this.contextKeyword = '',
    this.empathy = '',
    this.affirmation = '',
  });

  /// 위기 분기 — 공감/확언/감정 없이 위기 플래그만.
  const CheckinResult.crisis()
      : crisis = true,
        emotion = Emotion.neutral,
        intensity = 0,
        contextKeyword = '',
        empathy = '',
        affirmation = '';
}
