import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/emotion.dart';
import '../models/extras.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/emotion_face.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  String? _error;
  final List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요한 서비스입니다.');
      }

      final response = await Supabase.instance.client
          .from('checkin_log')
          .select()
          .eq('user_id', user.id)
          .eq('crisis_flag', false)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _logs.clear();
          _logs.addAll(List<Map<String, dynamic>>.from(response));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _formatHeaderDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(dt.year, dt.month, dt.day);

    if (itemDate == today) return '오늘';
    if (itemDate == yesterday) return '어제';
    return '${dt.month}월 ${dt.day}일';
  }

  Map<String, List<Map<String, dynamic>>> _groupLogs() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final log in _logs) {
      if (log['created_at'] == null) continue;
      final dt = DateTime.parse(log['created_at']).toLocal();
      final header = _formatHeaderDate(dt);
      grouped.putIfAbsent(header, () => []).add(log);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedLogs = _groupLogs();

    return Scaffold(
      body: DuskBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 뒤로가기 상단 바
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text('← 돌아가기',
                    style: HattiText.body(size: 14, color: HattiColors.creamDim)),
              ),
              const SizedBox(height: 8),
              Text('마음 기록 히스토리', style: HattiText.body(size: 24, w: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: _buildContent(groupedLogs),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, List<Map<String, dynamic>>> groupedLogs) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(HattiColors.cream),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('앗, 기록을 불러오는 데 실패했어요.',
                style: HattiText.body(size: 15, color: HattiColors.creamDim)),
            const SizedBox(height: 12),
            GhostButton('다시 불러오기', onPressed: _fetchHistory),
          ],
        ),
      );
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 14),
            Text('첫 마음을 들려주면\n여기에 차곡차곡 쌓일 거야.',
                textAlign: TextAlign.center,
                style: HattiText.body(size: 16, color: HattiColors.creamDim)),
          ],
        ),
      );
    }

    final headers = groupedLogs.keys.toList();

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: HattiColors.coral,
      backgroundColor: const Color(0xFF2D1F35),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: headers.length,
        itemBuilder: (context, index) {
          final header = headers[index];
          final logs = groupedLogs[header]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 날짜 헤더
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  header,
                  style: HattiText.body(
                    size: 14,
                    color: HattiColors.creamDim,
                    w: FontWeight.bold,
                  ),
                ),
              ),
              ...logs.map((log) => _buildLogCard(log)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final emotionKey = log['emotion'] as String? ?? 'neutral';
    final emotion = EmotionMeta.fromKey(emotionKey);
    final intensity = log['intensity'] as int? ?? 3;
    final contextKeyword = log['context_keyword'] as String? ?? '오늘의 마음';
    final empathy = log['empathy'] as String? ?? '';
    final affirmation = log['affirmation'] as String? ?? '';
    final diary = log['diary'] as String?;
    final weatherKey = log['weather'] as String?;
    final weather = weatherKey != null ? WeatherMeta.fromKey(weatherKey) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카드 헤더 (감정 얼굴, 라벨, 강도 도트, 맥락 태그, 날씨 아이콘)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EmotionFace(emotion, size: 24),
              const SizedBox(width: 8),
              Text(
                emotion.labelKo,
                style: HattiText.body(
                  size: 14.5,
                  color: emotion.tone,
                  w: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // 강도 도트
              ...List.generate(5, (i) {
                return Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < intensity
                          ? emotion.tone
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                );
              }),
              const Spacer(),
              // 날씨 아이콘
              if (weather != null) ...[
                Text(weather.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
              ],
              // 맥락 키워드 태그
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#$contextKeyword',
                  style: HattiText.body(size: 11, color: HattiColors.creamDim),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 하띠의 공감 대사
          Text(
            empathy,
            style: HattiText.body(size: 14, color: HattiColors.cream),
          ),
          // 확언 메시지
          if (affirmation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HattiColors.paper.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '💌 $affirmation',
                style: HattiText.body(
                  size: 13,
                  color: const Color(0xFFFCD9A8),
                  w: FontWeight.w500,
                ),
              ),
            ),
          ],
          // 하띠의 비동기 일기
          if (diary != null && diary.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📝', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    diary,
                    style: HattiText.hand(size: 15.5, color: HattiColors.creamDim),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
