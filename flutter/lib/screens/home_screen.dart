import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/content.dart';
import '../models/emotion.dart';
import '../services/hatti_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/hatti_character.dart';
import 'checkin_flow.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _startCheckin(BuildContext context) async {
    final msg = await Navigator.of(context).push<String?>(
      MaterialPageRoute(builder: (_) => const CheckinFlowScreen()),
    );
    if (msg != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(msg, style: HattiText.body(size: 13.5)),
          backgroundColor: const Color(0xFF1E1423),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ));
    }
  }

  String _greeting(HattiService s) {
    if (s.isFirstTime) return Content.firstGreeting;
    return s.isMorning ? Content.morningGreeting : Content.eveningGreeting;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<HattiService>();

    return Scaffold(
      body: DuskBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            children: [
              // 상단 바
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    _Stat('💛 ${s.intimacy}'),
                    const SizedBox(width: 14),
                    _Stat('🔥 ${s.streak}일'),
                  ]),
                  Row(
                    children: [
                      _PeriodChip('${s.periodIcon} ${s.periodLabel} · ${s.clock}'),
                      const SizedBox(width: 4),
                      const _MenuButton(),
                    ],
                  ),
                ],
              ),
              // 캐릭터 영역
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HattiCharacter(stage: s.stage),
                    const SizedBox(height: 6),
                    Text('Lv.${s.stage} · ${s.stageName}',
                        style: HattiText.body(
                            size: 12.5, color: HattiColors.creamDim)),
                    const SizedBox(height: 12),
                    SpeechBubble(_greeting(s)),
                    if (s.history.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text('최근 마음 기록',
                          style: HattiText.body(
                              size: 13, color: HattiColors.creamDim)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final e in s.history) _HistoryChip(e),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PrimaryButton('체크인 시작하기',
                  onPressed: () => _startCheckin(context)),
              const SizedBox(height: 14),
              Text('프로토타입 · 응답은 예시입니다',
                  style:
                      HattiText.body(size: 11, color: HattiColors.creamFaint)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: HattiColors.cream),
      color: HattiColors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 'history') {
          _showHistory(context);
        } else if (value == 'version') {
          _showVersion(context);
        } else if (value == 'logout') {
          _handleLogout(context);
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'history',
          child: Row(
            children: [
              const Icon(Icons.history, color: HattiColors.ink, size: 18),
              const SizedBox(width: 8),
              Text('지난 기록', style: HattiText.body(color: HattiColors.ink)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'version',
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: HattiColors.ink, size: 18),
              const SizedBox(width: 8),
              Text('버전 정보', style: HattiText.body(color: HattiColors.ink)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, color: Colors.redAccent, size: 18),
              const SizedBox(width: 8),
              Text('로그아웃', style: HattiText.body(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _HistoryBottomSheet(),
    );
  }

  void _showVersion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HattiColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('버전 정보', style: HattiText.body(size: 18, color: HattiColors.ink, w: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('하띠 (Hatti) 앱', style: HattiText.body(size: 16, color: HattiColors.ink)),
            const SizedBox(height: 6),
            Text('버전: v0.1.0 (Scaffold)', style: HattiText.body(size: 14, color: HattiColors.cardInk)),
            const SizedBox(height: 12),
            Text('© 2026 Hatti Dev Team', style: HattiText.body(size: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('확인', style: HattiText.body(color: HattiColors.coral, w: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HattiColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('로그아웃', style: HattiText.body(size: 18, color: HattiColors.ink, w: FontWeight.bold)),
        content: Text('정말 하띠와 잠시 작별할까요?', style: HattiText.body(color: HattiColors.ink)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('취소', style: HattiText.body(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthService>().logout();
            },
            child: Text('로그아웃', style: HattiText.body(color: Colors.redAccent, w: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _HistoryBottomSheet extends StatelessWidget {
  const _HistoryBottomSheet();

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final Future<List<Map<String, dynamic>>> logsFuture = user == null 
        ? Future.value([]) 
        : Supabase.instance.client
            .from('checkin_log')
            .select('created_at, emotion, intensity, context_keyword, empathy, diary, raw_text, crisis_flag')
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(10)
            .then((data) => List<Map<String, dynamic>>.from(data));

    return Container(
      decoration: const BoxDecoration(
        color: HattiColors.paper,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '하띠가 기억하는 너의 마음들',
            style: HattiText.hand(size: 24, color: HattiColors.ink, w: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: logsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: HattiColors.coral),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      '마음 기록을 불러오지 못했어요.',
                      style: HattiText.body(color: Colors.redAccent),
                    ),
                  );
                }
                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return Center(
                    child: Text(
                      '아직 기록된 마음이 없어요.\n첫 마음을 하띠에게 들려주세요.',
                      style: HattiText.body(color: HattiColors.cardInk),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final date = DateTime.parse(log['created_at']).toLocal();
                    final formattedDate = '${date.month}월 ${date.day}일 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                    final emotionKey = log['emotion'] as String;
                    final emotion = EmotionMeta.fromKey(emotionKey);
                    final isCrisis = log['crisis_flag'] as bool? ?? false;

                    return Card(
                      color: HattiColors.paperDeep.withValues(alpha: 0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isCrisis ? Colors.redAccent.withValues(alpha: 0.3) : Colors.transparent,
                          width: 1
                        )
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isCrisis ? Colors.redAccent : emotion.tone,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isCrisis ? '위기' : emotion.labelKo,
                                  style: HattiText.body(size: 12, color: Colors.white, w: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  log['context_keyword'] ?? '오늘의 마음',
                                  style: HattiText.body(
                                    size: 15, 
                                    color: HattiColors.ink,
                                    w: FontWeight.bold
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              formattedDate,
                              style: HattiText.body(size: 12, color: Colors.grey),
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Divider(height: 12, color: Colors.grey),
                                  Text(
                                    '너의 한마디',
                                    style: HattiText.body(size: 12, color: HattiColors.cardInk, w: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    log['raw_text'] ?? '',
                                    style: HattiText.body(color: HattiColors.ink),
                                  ),
                                  if (log['empathy'] != null && (log['empathy'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      '하띠의 한마디',
                                      style: HattiText.body(size: 12, color: HattiColors.cardInk, w: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      log['empathy'],
                                      style: HattiText.hand(size: 16, color: HattiColors.coral),
                                    ),
                                  ],
                                  if (log['diary'] != null && (log['diary'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      '하띠의 일기장',
                                      style: HattiText.body(size: 12, color: HattiColors.cardInk, w: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: HattiColors.paperDeep.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        log['diary'],
                                        style: HattiText.body(size: 13, color: HattiColors.ink),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String text;
  const _Stat(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: HattiText.body(size: 13, color: HattiColors.creamDim));
}

class _PeriodChip extends StatelessWidget {
  final String text;
  const _PeriodChip(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: HattiText.body(size: 12.5, color: HattiColors.creamDim)),
      );
}

class _HistoryChip extends StatelessWidget {
  final Emotion emotion;
  const _HistoryChip(this.emotion);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: emotion.tone.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(emotion.labelKo,
            style:
                HattiText.body(size: 12, color: Colors.white)),
      );
}

