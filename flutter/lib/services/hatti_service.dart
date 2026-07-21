import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/emotion.dart';

/// 하띠 캐릭터 상태 및 데이터베이스 연동 서비스.
class HattiService extends ChangeNotifier {
  int intimacy = 0;
  int streak = 0;
  DateTime? lastCheckinDate;
  final List<Emotion> history = [];
  bool isLoading = false;

  HattiService() {
    // 1. 초기 앱 실행 시 로그인 세션이 있으면 즉시 로드
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      loadStateAndHistory();
    }

    // 2. 로그인/로그아웃 등 세션 상태 변화 실시간 모니터링
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        loadStateAndHistory();
      } else {
        _resetState();
      }
    });
  }

  // ── 데이터베이스 동기화 ─────────────────────────────────────
  /// Supabase DB에서 최신 hatti_state와 checkin_log를 조회하여 동기화합니다.
  Future<void> loadStateAndHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    isLoading = true;
    notifyListeners();

    try {
      // 1) hatti_state 테이블에서 유저 성장 상태 로드
      final stateData = await Supabase.instance.client
          .from('hatti_state')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (stateData != null) {
        intimacy = stateData['intimacy'] ?? 0;
        streak = stateData['streak'] ?? 0;
        if (stateData['last_checked_in_at'] != null) {
          lastCheckinDate = DateTime.parse(stateData['last_checked_in_at']).toLocal();
        } else {
          lastCheckinDate = null;
        }
      } else {
        // 기록이 없는 신규 사용자는 0 상태로 초기화
        intimacy = 0;
        streak = 0;
        lastCheckinDate = null;
      }

      // 2) checkin_log 테이블에서 최근 정상(위기 아님) 감정 기록 4개 로드
      final logData = await Supabase.instance.client
          .from('checkin_log')
          .select('emotion')
          .eq('user_id', user.id)
          .eq('crisis_flag', false)
          .order('created_at', ascending: false)
          .limit(4);

      history.clear();
      for (final row in logData) {
        final emotionKey = row['emotion'] as String?;
        if (emotionKey != null) {
          history.add(EmotionMeta.fromKey(emotionKey));
        }
      }
    } catch (e) {
      debugPrint('Supabase 데이터 동기화 에러: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _resetState() {
    intimacy = 0;
    streak = 0;
    lastCheckinDate = null;
    history.clear();
    isLoading = false;
    notifyListeners();
  }

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

  // (이전 하위 호환성을 위해 빈 함수 유지)
  String? applyCheckin(Emotion emotion) {
    return null;
  }
}

