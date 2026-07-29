import 'package:flutter/material.dart';
import '../models/emotion.dart';

/// 감정 9종의 얼굴 디자인을 CustomPainter로 렌더링하는 위젯.
class EmotionFace extends StatelessWidget {
  final Emotion emotion;
  final double size;

  const EmotionFace(this.emotion, {super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EmotionFacePainter(emotion: emotion),
      ),
    );
  }
}

class _EmotionFacePainter extends CustomPainter {
  final Emotion emotion;

  _EmotionFacePainter({required this.emotion});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    Offset p(double x, double y) => Offset(x * s, y * s);

    final paint = Paint()..isAntiAlias = true;

    // 1. 감정 고유 색상의 원형 얼굴 배경
    paint.color = emotion.tone;
    canvas.drawCircle(p(50, 50), 50 * s, paint);

    final linePaint = Paint()
      ..color = const Color(0xFF4A3A2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * s
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF4A3A2E)
      ..style = PaintingStyle.fill;

    // 2. 감정별 이목구비 및 액센트 그리기
    switch (emotion) {
      case Emotion.joy:
        // 볼터치
        paint.color = const Color(0xFFFF8B94).withValues(alpha: 0.5);
        canvas.drawCircle(p(25, 60), 12 * s, paint);
        canvas.drawCircle(p(75, 60), 12 * s, paint);

        // 눈: 활짝 웃는 아치 눈
        final leftEye = Path()
          ..moveTo(20 * s, 48 * s)
          ..quadraticBezierTo(28 * s, 36 * s, 36 * s, 48 * s);
        final rightEye = Path()
          ..moveTo(64 * s, 48 * s)
          ..quadraticBezierTo(72 * s, 36 * s, 80 * s, 48 * s);
        canvas.drawPath(leftEye, linePaint);
        canvas.drawPath(rightEye, linePaint);

        // 입: 큰 미소
        final mouthPath = Path()
          ..moveTo(38 * s, 64 * s)
          ..quadraticBezierTo(50 * s, 80 * s, 62 * s, 64 * s)
          ..quadraticBezierTo(50 * s, 68 * s, 38 * s, 64 * s);
        canvas.drawPath(mouthPath, fillPaint);
        break;

      case Emotion.calm:
        // 볼터치
        paint.color = const Color(0xFFFF8B94).withValues(alpha: 0.35);
        canvas.drawCircle(p(25, 60), 10 * s, paint);
        canvas.drawCircle(p(75, 60), 10 * s, paint);

        // 눈: 부드럽게 감은 눈 (아래로 휜 아치)
        final leftEye = Path()
          ..moveTo(20 * s, 44 * s)
          ..quadraticBezierTo(28 * s, 52 * s, 36 * s, 44 * s);
        final rightEye = Path()
          ..moveTo(64 * s, 44 * s)
          ..quadraticBezierTo(72 * s, 52 * s, 80 * s, 44 * s);
        canvas.drawPath(leftEye, linePaint);
        canvas.drawPath(rightEye, linePaint);

        // 입: 작은 미소
        final mouth = Path()
          ..moveTo(43 * s, 68 * s)
          ..quadraticBezierTo(50 * s, 74 * s, 57 * s, 68 * s);
        canvas.drawPath(mouth, linePaint);
        break;

      case Emotion.pride:
        // 눈: 웃는 눈 (위로 휜 아치)
        final leftEye = Path()
          ..moveTo(22 * s, 46 * s)
          ..quadraticBezierTo(29 * s, 38 * s, 36 * s, 46 * s);
        final rightEye = Path()
          ..moveTo(64 * s, 46 * s)
          ..quadraticBezierTo(71 * s, 38 * s, 78 * s, 46 * s);
        canvas.drawPath(leftEye, linePaint);
        canvas.drawPath(rightEye, linePaint);

        // 입: 자신감 있는 미소
        final mouth = Path()
          ..moveTo(40 * s, 66 * s)
          ..quadraticBezierTo(52 * s, 74 * s, 60 * s, 64 * s);
        canvas.drawPath(mouth, linePaint);

        // 반짝임 이펙트 (✦)
        final sparklePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        final sparkle = Path()
          ..moveTo(82 * s, 25 * s)
          ..quadraticBezierTo(86 * s, 25 * s, 86 * s, 21 * s)
          ..quadraticBezierTo(86 * s, 25 * s, 90 * s, 25 * s)
          ..quadraticBezierTo(86 * s, 25 * s, 86 * s, 29 * s)
          ..quadraticBezierTo(86 * s, 25 * s, 82 * s, 25 * s);
        canvas.drawPath(sparkle, sparklePaint);
        break;

      case Emotion.fatigue:
        // 눈: 반쯤 감긴 처진 눈
        final leftEyeUpper = Path()
          ..moveTo(20 * s, 42 * s)
          ..lineTo(36 * s, 46 * s);
        final rightEyeUpper = Path()
          ..moveTo(64 * s, 46 * s)
          ..lineTo(80 * s, 42 * s);
        canvas.drawPath(leftEyeUpper, linePaint);
        canvas.drawPath(rightEyeUpper, linePaint);

        // 눈동자 (반원 아래로)
        fillPaint.color = const Color(0xFF4A3A2E);
        canvas.drawOval(Rect.fromLTWH(24 * s, 44 * s, 8 * s, 6 * s), fillPaint);
        canvas.drawOval(Rect.fromLTWH(68 * s, 44 * s, 8 * s, 6 * s), fillPaint);

        // 입: 한숨 입 (둥근 타원형)
        canvas.drawOval(
          Rect.fromCenter(center: p(50, 70), width: 10 * s, height: 14 * s),
          linePaint,
        );
        break;

      case Emotion.anxiety:
        // 눈썹: 걱정스러운 시옷자 눈썹
        final browPaint = Paint()
          ..color = const Color(0xFF4A3A2E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * s
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p(20, 36), p(32, 40), browPaint);
        canvas.drawLine(p(80, 36), p(68, 40), browPaint);

        // 눈: 불안한 작은 동그라미
        canvas.drawCircle(p(27, 48), 4 * s, fillPaint);
        canvas.drawCircle(p(73, 48), 4 * s, fillPaint);

        // 입: 물결 입
        final mouth = Path()
          ..moveTo(40 * s, 70 * s)
          ..quadraticBezierTo(45 * s, 66 * s, 50 * s, 70 * s)
          ..quadraticBezierTo(55 * s, 74 * s, 60 * s, 70 * s);
        canvas.drawPath(mouth, linePaint);

        // 땀방울
        final sweatPaint = Paint()
          ..color = const Color(0xFF8CD8F5)
          ..style = PaintingStyle.fill;
        final sweat = Path()
          ..moveTo(82 * s, 40 * s)
          ..quadraticBezierTo(85 * s, 44 * s, 85 * s, 47 * s)
          ..arcToPoint(Offset(79 * s, 47 * s), radius: Radius.circular(3 * s))
          ..quadraticBezierTo(79 * s, 44 * s, 82 * s, 40 * s);
        canvas.drawPath(sweat, sweatPaint);
        break;

      case Emotion.anger:
        // 눈썹: 찌푸린 화난 눈썹
        final browPaint = Paint()
          ..color = const Color(0xFF4A3A2E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * s
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p(20, 38), p(34, 46), browPaint);
        canvas.drawLine(p(80, 38), p(66, 46), browPaint);

        // 눈: 작은 노려보는 점눈
        canvas.drawCircle(p(27, 50), 4.5 * s, fillPaint);
        canvas.drawCircle(p(73, 50), 4.5 * s, fillPaint);

        // 입: 굳은 일자 입
        canvas.drawLine(p(40, 70), p(60, 70), linePaint);
        break;

      case Emotion.sadness:
        // 눈: 처진 슬픈 눈
        final leftEye = Path()
          ..moveTo(22 * s, 44 * s)
          ..quadraticBezierTo(30 * s, 48 * s, 34 * s, 42 * s);
        final rightEye = Path()
          ..moveTo(66 * s, 42 * s)
          ..quadraticBezierTo(70 * s, 48 * s, 78 * s, 44 * s);
        canvas.drawPath(leftEye, linePaint);
        canvas.drawPath(rightEye, linePaint);

        // 입: 아래로 굽은 슬픈 입
        final mouth = Path()
          ..moveTo(42 * s, 72 * s)
          ..quadraticBezierTo(50 * s, 64 * s, 58 * s, 72 * s);
        canvas.drawPath(mouth, linePaint);

        // 눈물
        final tearPaint = Paint()
          ..color = const Color(0xFF5CA3FF)
          ..style = PaintingStyle.fill;
        final tear = Path()
          ..moveTo(31 * s, 52 * s)
          ..quadraticBezierTo(34 * s, 58 * s, 34 * s, 61 * s)
          ..arcToPoint(Offset(28 * s, 61 * s), radius: Radius.circular(3 * s))
          ..quadraticBezierTo(28 * s, 58 * s, 31 * s, 52 * s);
        canvas.drawPath(tear, tearPaint);
        break;

      case Emotion.guilt:
        // 눈: 아래를 보는 시선 (아래로 쳐진 선 및 하단 눈동자)
        canvas.drawLine(p(20, 45), p(34, 47), linePaint);
        canvas.drawLine(p(80, 45), p(66, 47), linePaint);
        canvas.drawCircle(p(27, 51), 3.5 * s, fillPaint);
        canvas.drawCircle(p(73, 51), 3.5 * s, fillPaint);

        // 입: 다문 입 (약간 비뚤어진 짧은 선)
        canvas.drawLine(p(43, 70), p(55, 68), linePaint);
        break;

      case Emotion.neutral:
        // 눈: 동그란 점 눈
        canvas.drawCircle(p(28, 46), 4.5 * s, fillPaint);
        canvas.drawCircle(p(72, 46), 4.5 * s, fillPaint);

        // 입: 짧은 일자 입
        canvas.drawLine(p(42, 68), p(58, 68), linePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(_EmotionFacePainter oldDelegate) =>
      oldDelegate.emotion != emotion;
}
