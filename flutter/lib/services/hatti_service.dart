import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/emotion.dart';
import '../models/extras.dart';
import '../data/content.dart';

/// 하띠 캐릭터 상태 및 데이터베이스 연동 서비스.
class HattiService extends ChangeNotifier {
  int intimacy = 0;
  int streak = 0;
  DateTime? lastCheckinDate;
  final List<Emotion> history = [];
  bool isLoading = false;

  // ── 선택적 상호작용 관련 로컬 상태 ─────────────────────────
  Weather? _weather;
  int _petCount = 0;
  String? _pettingLine;
  Timer? _petTimer;
  LuckyCard? _todayCard;
  bool _hasSeenWelcome = false;
  String _characterName = '하띠';

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

  // Getters
  Weather? get weather => _weather;
  String? get pettingLine => _pettingLine;
  LuckyCard? get todayCard => _todayCard;
  int get petCount => _petCount;
  bool get hasSeenWelcome => _hasSeenWelcome;
  String get characterName => _characterName;

  void completeWelcome() {
    _hasSeenWelcome = true;
    notifyListeners();

    // 백그라운드 DB 저장 (실패해도 무방)
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      Supabase.instance.client
          .from('hatti_state')
          .update({'has_seen_welcome': true})
          .eq('user_id', user.id)
          .then((_) => null)
          .catchError((e) {
            debugPrint('웰컴 상태 DB 갱신 에러: $e');
            return null;
          });
    }
  }

  void updateCharacterName(String name) {
    _characterName = name.trim();
    notifyListeners();

    // 백그라운드 DB 저장 (실패해도 무방)
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      Supabase.instance.client
          .from('hatti_state')
          .update({'character_name': _characterName})
          .eq('user_id', user.id)
          .then((_) => null)
          .catchError((e) {
            debugPrint('캐릭터 이름 DB 갱신 에러: $e');
            return null;
          });
    }
  }

  bool get canDrawCard {
    if (lastCheckinDate == null) return false;
    final now = DateTime.now();
    final isTodayChecked = lastCheckinDate!.year == now.year &&
        lastCheckinDate!.month == now.month &&
        lastCheckinDate!.day == now.day;
    return isTodayChecked && _todayCard == null;
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

        // 날씨 및 카드 정보 복원
        if (stateData['today_weather'] != null) {
          _weather = WeatherMeta.fromKey(stateData['today_weather']);
        }
        if (stateData['last_card_id'] != null) {
          final cardId = stateData['last_card_id'] as String;
          _todayCard = luckyCards.firstWhere(
            (c) => c.id == cardId,
            orElse: () => luckyCards.first,
          );
        }
        _petCount = stateData['pet_count'] ?? 0;
        _characterName = stateData['character_name'] ?? '하띠';
        _hasSeenWelcome = stateData['has_seen_welcome'] ?? false;
      } else {
        // 기록이 없는 신규 사용자는 0 상태로 초기화
        intimacy = 0;
        streak = 0;
        lastCheckinDate = null;
        _weather = null;
        _todayCard = null;
        _petCount = 0;
        _characterName = '하띠';
        _hasSeenWelcome = false;
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
    _weather = null;
    _todayCard = null;
    _petCount = 0;
    _pettingLine = null;
    _petTimer?.cancel();
    _hasSeenWelcome = false;
    _characterName = '하띠';
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

  String get periodLabel {
    final h = DateTime.now().hour;
    if (h >= 0 && h < 6) return '새벽';
    if (h >= 6 && h < 11) return '아침';
    if (h >= 11 && h < 14) return '점심';
    if (h >= 14 && h < 18) return '오후';
    if (h >= 18 && h < 21) return '저녁';
    return '밤';
  }

  String get periodIcon {
    final h = DateTime.now().hour;
    if (h >= 0 && h < 6) return '🌌';
    if (h >= 6 && h < 11) return '☀️';
    if (h >= 11 && h < 14) return '🌤️';
    if (h >= 14 && h < 18) return '☕';
    if (h >= 18 && h < 21) return '🌅';
    return '🌙';
  }

  String get clock {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // ── 상호작용 관련 메소드 ──────────────────────────────────
  void setWeather(Weather w) {
    _weather = w;
    notifyListeners();

    // 백그라운드 데이터베이스 반영 (실패해도 앱 작동에는 무방하도록 에러 처리)
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      Supabase.instance.client
          .from('hatti_state')
          .update({
            'today_weather': w.key,
            'weather_date': DateTime.now().toUtc().toIso8601String().split('T')[0],
          })
          .eq('user_id', user.id)
          .then((_) => null)
          .catchError((e) {
            debugPrint('날씨 DB 갱신 에러: $e');
            return null;
          });
    }
  }

  void pet() {
    _petCount++;
    _pettingLine = Content.pettingReactions[Random().nextInt(Content.pettingReactions.length)];
    notifyListeners();

    _petTimer?.cancel();
    _petTimer = Timer(const Duration(milliseconds: 2500), () {
      _pettingLine = null;
      notifyListeners();
    });

    // 백그라운드 데이터베이스 반영 (실패해도 무방)
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      Supabase.instance.client
          .from('hatti_state')
          .update({'pet_count': _petCount})
          .eq('user_id', user.id)
          .then((_) => null)
          .catchError((e) {
            debugPrint('쓰다듬기 DB 갱신 에러: $e');
            return null;
          });
    }
  }

  LuckyCard drawCard() {
    final card = luckyCards[Random().nextInt(luckyCards.length)];
    _todayCard = card;
    notifyListeners();

    // 백그라운드 데이터베이스 반영 (실패해도 무방)
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      Supabase.instance.client
          .from('hatti_state')
          .update({
            'last_card_id': card.id,
            'last_card_date': DateTime.now().toUtc().toIso8601String().split('T')[0],
          })
          .eq('user_id', user.id)
          .then((_) => null)
          .catchError((e) {
            debugPrint('카드 뽑기 DB 갱신 에러: $e');
            return null;
          });
    }

    return card;
  }

  /// 체크인 완료 결과를 클라이언트 상태에 동기적으로 반영하고, 필요 시 마일스톤 토스트 메시지를 반환합니다.
  String? applyCheckin(CheckinResult result) {
    if (result.crisis) return null;

    final oldStage = stage;
    final oldStreak = streak;

    // 1) 친밀도 증가
    intimacy++;
    
    // 2) 스트릭 계산
    final now = DateTime.now();
    if (lastCheckinDate == null) {
      streak = 1;
    } else {
      final difference = now.difference(lastCheckinDate!).inDays;
      if (difference == 0) {
        // 같은 날 중복 체크인: 스트릭 유지
      } else if (difference == 1) {
        streak++;
      } else {
        streak = 1;
      }
    }
    lastCheckinDate = now;

    // 3) 최근 감정 히스토리 선두에 추가 (최대 4개 유지)
    history.insert(0, result.emotion);
    if (history.length > 4) {
      history.removeRange(4, history.length);
    }

    notifyListeners();

    // 4) 비동기로 서버의 최신 상태 풀링해 최종 동기화
    loadStateAndHistory();

    // 5) 마일스톤 메시지 판정
    final newStage = stage;
    if (newStage > oldStage) {
      return '🌱 하띠가 자랐어! 이제 «$stageName»';
    }

    if ([3, 7, 14].contains(streak) && streak > oldStreak) {
      return '🎉 $streak일 연속! 하띠가 특별한 인사를 준비했어';
    }

    return null;
  }
}

