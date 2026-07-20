import 'package:flutter/material.dart';

import '../models/emotion.dart';
import '../theme.dart';

/// 하띠 캐릭터. 프로토타입의 SVG를 CustomPainter로 옮김.
/// stage(1~3)로 크기·새싹·꽃이 바뀌고, mood로 입 모양이 바뀐다.
/// 숨쉬기 + 눈깜빡임으로 살아있는 느낌을 준다.
class HattiCharacter extends StatefulWidget {
  final int stage; // 1~3
  final Color tone;
  final Emotion? mood; // 입 모양
  final double scale; // 추가 배율(응답 화면 등에서 축소)

  const HattiCharacter({
    super.key,
    this.stage = 1,
    this.tone = HattiColors.honey,
    this.mood,
    this.scale = 1.0,
  });

  @override
  State<HattiCharacter> createState() => _HattiCharacterState();
}

class _HattiCharacterState extends State<HattiCharacter>
    with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _breath.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stageScale = switch (widget.stage) { 3 => 1.0, 2 => 0.88, _ => 0.76 };
    final side = 150.0 * stageScale * widget.scale;

    return AnimatedBuilder(
      animation: Listenable.merge([_breath, _blink]),
      builder: (context, _) {
        // 숨쉬기: 세로로 살짝 늘었다 줄었다
        final breathe = 1.0 + 0.03 * _breath.value;
        // 눈깜빡임: 주기의 아주 짧은 구간에서만 감음
        final blinking = _blink.value > 0.94;
        return SizedBox(
          width: side,
          height: side,
          child: Transform.scale(
            scaleY: breathe,
            alignment: Alignment.bottomCenter,
            child: CustomPaint(
              painter: _HattiPainter(
                stage: widget.stage,
                tone: widget.tone,
                mood: widget.mood,
                blinking: blinking,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HattiPainter extends CustomPainter {
  final int stage;
  final Color tone;
  final Emotion? mood;
  final bool blinking;

  _HattiPainter({
    required this.stage,
    required this.tone,
    required this.mood,
    required this.blinking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 150x150 기준 좌표를 실제 크기로 스케일
    final s = size.width / 150.0;
    Offset p(double x, double y) => Offset(x * s, y * s);

    final paint = Paint()..isAntiAlias = true;

    // 그림자
    paint.color = Colors.black.withValues(alpha: 0.18);
    canvas.drawOval(
      Rect.fromCenter(center: p(75, 134), width: 68 * s, height: 14 * s),
      paint,
    );

    // 새싹 / 줄기
    paint.color = const Color(0xFF7BA86B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(73.5 * s, 28 * s, 3 * s, 10 * s),
        Radius.circular(1.5 * s),
      ),
      paint,
    );
    paint.color = const Color(0xFF8FBE7E);
    canvas.drawOval(
      Rect.fromCenter(center: p(66, 22), width: 16 * s, height: 24 * s),
      paint,
    );
    if (stage >= 2) {
      paint.color = const Color(0xFFA6D08F);
      canvas.drawOval(
        Rect.fromCenter(center: p(84, 22), width: 16 * s, height: 24 * s),
        paint,
      );
    }
    if (stage >= 3) {
      paint.color = const Color(0xFFE88FA6);
      canvas.drawCircle(p(75, 12), 5 * s, paint);
    }

    // 몸통 (둥근 블롭)
    final bodyRect = Rect.fromLTWH(30 * s, 42 * s, 90 * s, 82 * s);
    paint.color = const Color(0xFFF6D89A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(42 * s)),
      paint,
    );
    // 밝은 하이라이트(윗부분)
    paint.color = const Color(0xFFFCE9C0).withValues(alpha: 0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(34 * s, 46 * s, 82 * s, 46 * s),
        Radius.circular(40 * s),
      ),
      paint,
    );

    // 볼터치
    paint.color = tone.withValues(alpha: 0.32);
    canvas.drawOval(
      Rect.fromCenter(center: p(50, 92), width: 16 * s, height: 10 * s),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: p(100, 92), width: 16 * s, height: 10 * s),
      paint,
    );

    // 눈
    const eyeColor = Color(0xFF4A3A2E);
    paint.color = eyeColor;
    if (blinking) {
      final line = Paint()
        ..color = eyeColor
        ..strokeWidth = 2.4 * s
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p(56, 80), p(64, 80), line);
      canvas.drawLine(p(86, 80), p(94, 80), line);
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: p(60, 80), width: 9 * s, height: 12 * s),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: p(90, 80), width: 9 * s, height: 12 * s),
        paint,
      );
      paint.color = Colors.white;
      canvas.drawCircle(p(61.6, 77.5), 1.6 * s, paint);
      canvas.drawCircle(p(91.6, 77.5), 1.6 * s, paint);
    }

    // 입 (mood별)
    final mouth = Paint()
      ..color = eyeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * s
      ..strokeCap = StrokeCap.round;
    final path = Path();
    switch (mood) {
      case Emotion.joy:
        path.moveTo(67 * s, 96 * s);
        path.quadraticBezierTo(75 * s, 104 * s, 83 * s, 96 * s);
      case Emotion.sadness:
        path.moveTo(68 * s, 100 * s);
        path.quadraticBezierTo(75 * s, 95 * s, 82 * s, 100 * s);
      default:
        path.moveTo(69 * s, 98 * s);
        path.quadraticBezierTo(75 * s, 102 * s, 81 * s, 98 * s);
    }
    canvas.drawPath(path, mouth);
  }

  @override
  bool shouldRepaint(_HattiPainter old) =>
      old.stage != stage ||
      old.tone != tone ||
      old.mood != mood ||
      old.blinking != blinking;
}
