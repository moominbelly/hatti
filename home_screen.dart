import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/emotion.dart';
import '../services/hatti_service.dart';
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
                  _PeriodChip('${s.periodIcon} ${s.periodLabel} · ${s.clock}'),
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
