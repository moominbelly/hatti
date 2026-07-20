import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 하띠 디자인 토큰 — "황혼의 둥지(warm dusk nest)" 팔레트.
/// 프로토타입(hatti_prototype.jsx)의 색·톤을 그대로 옮김.
class HattiColors {
  static const night = Color(0xFF35283F); // 배경 상단 (깊은 자두)
  static const dusk = Color(0xFF7A5A66); // 배경 하단 (따뜻한 모브)
  static const paper = Color(0xFFFDF5EC); // 카드/종이 (따뜻한 크림)
  static const paperDeep = Color(0xFFF7E9D3); // 확언 카드 그라디언트 하단
  static const coral = Color(0xFFE38A6F); // 주요 액센트 (따뜻함)
  static const honey = Color(0xFFEBB25A); // 하띠 몸통 / 기쁨
  static const sage = Color(0xFF9FBE9A); // 차분함
  static const ink = Color(0xFF40303A); // 크림 위 텍스트
  static const cardInk = Color(0xFF5A4636); // 확언 카드 텍스트

  static const cream = Color(0xFFFDF5EC); // 어두운 배경 위 텍스트
  static Color creamDim = const Color(0xFFFDF5EC).withValues(alpha: 0.72);
  static Color creamFaint = const Color(0xFFFDF5EC).withValues(alpha: 0.4);

  /// 배경 황혼 그라디언트 (모든 화면 공통)
  static const duskGradient = LinearGradient(
    begin: Alignment(-0.2, -1),
    end: Alignment(0.3, 1),
    colors: [Color(0xFF3A2E46), Color(0xFF584158), Color(0xFF7C5A63)],
    stops: [0.0, 0.46, 1.0],
  );
}

class HattiText {
  /// 손글씨체 — 하띠 대사 / 확언 (Gaegu)
  static TextStyle hand(
          {double size = 20, Color color = HattiColors.cream, FontWeight? w}) =>
      GoogleFonts.gaegu(fontSize: size, color: color, fontWeight: w, height: 1.5);

  /// 본문/UI — 부드러운 고딕 (Gowun Dodum)
  static TextStyle body(
          {double size = 14, Color color = HattiColors.cream, FontWeight? w}) =>
      GoogleFonts.gowunDodum(
          fontSize: size, color: color, fontWeight: w, height: 1.5);
}

ThemeData buildHattiTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: HattiColors.coral,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: HattiColors.night,
  );
  return base.copyWith(
    textTheme: GoogleFonts.gowunDodumTextTheme(base.textTheme)
        .apply(bodyColor: HattiColors.cream, displayColor: HattiColors.cream),
  );
}
