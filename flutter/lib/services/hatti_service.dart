import 'package:flutter/foundation.dart';

import '../models/emotion.dart';

/// 하띠 캐릭터 상태 + 시간대 판정.
/// 지금은 메모리 저장(앱 종료 시 초기화). 로컬 저장이 필요하면
/// applyCheckin 끝에 shared_preferences 쓰기를 추가하면 된다.
class HattiService extends ChangeNotifier {
  // 데모하기 좋게 초기값을 살짝 준다 (0,0이면 성장/기억이 안 보임)
  int intimacy = 2;
  int streak = 2;
  DateTime? lastCheckinDate;
  final List<Emotion> history = [];

  // ── 성장 단계 ──────────────────────────────────────────
  int get stage => intimacy >= 7 ? 3 : (intimacy >= 3 ? 2 : 1);

  String get stageName => switch (stage) {
        3 => '하띠',
        2 => '아기 하띠',
        _ => '새싹 하띠',
      };

  bool get isFirstTime => history.isEmpty && intimacy == 0;

  // ── 시간대 (접속 시각 자동 판정) ────────────────────────
  /// 05:00~11:59 = 아침(의도), 그 외 = 저녁(회고)
  String get period {
    final h = DateTime.now().hour;
    return (h >= 5 && h < 12) ? 'morning' : 'evening';
  }

  bool get isMorning => period == 'morning';

  String get periodLabel => isMorning ? '아침' : '저녁';

  String get periodIcon => isMorning ? '☀️' : '🌙';

  String get clock {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // ── 체크인 반영 ────────────────────────────────────────
  /// 정상 경로에서만 호출(위기 경로는 게임화 없음).
  /// 반환값: 토스트로 띄울 메시지(없으면 null)
  String? applyCheckin(Emotion emotion) {
    final prevStage = stage;
    final today = _dateOnly(DateTime.now());

    streak = _nextStreak(streak, lastCheckinDate, today);
    intimacy += 1; // 누적, 감소 없음
    lastCheckinDate = today;
    history.insert(0, emotion);
    if (history.length > 4) history.removeRange(4, history.length);

    notifyListeners();

    // 성장 우선, 그다음 마일스톤
    if (stage > prevStage) return '🌱 하띠가 자랐어! 이제 «$stageName»';
    if (const [3, 7, 14].contains(streak)) {
      return '🎉 $streak일 연속! 하띠가 특별한 인사를 준비했어';
    }
    return null;
  }

  /// 어제=+1 / 오늘 중복=유지 / 공백=리셋
  static int _nextStreak(int prev, DateTime? last, DateTime today) {
    if (last == null) return 1;
    final days = today.difference(last).inDays;
    if (days == 0) return prev;
    if (days == 1) return prev + 1;
    return 1;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
