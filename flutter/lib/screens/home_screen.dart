import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/emotion.dart';
import '../models/extras.dart';
import '../services/hatti_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/emotion_face.dart';
import '../widgets/hatti_character.dart';
import 'checkin_flow.dart';
import 'history_screen.dart';

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
    // 쓰다듬으면 그 반응이 인사말 자리를 잠시 차지한다
    if (s.pettingLine != null) return s.pettingLine!;
    if (s.isFirstTime) return Content.firstGreeting;
    return s.isMorning ? Content.morningGreeting : Content.eveningGreeting;
  }

  Future<void> _pickWeather(BuildContext context) async {
    final s = context.read<HattiService>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF41304A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('오늘 날씨는 어때?', style: HattiText.hand(size: 22)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final w in Weather.values)
                GestureDetector(
                  onTap: () {
                    s.setWeather(w);
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: Text('${w.icon} ${w.labelKo}',
                        style: HattiText.body(size: 14)),
                  ),
                ),
            ],
          ),
        ]),
      ),
    );
  }

  Future<void> _openCard(BuildContext context) async {
    final s = context.read<HattiService>();
    final card = s.todayCard ?? s.drawCard();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: _CardFace(card),
      ),
    );
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
                  Row(children: [
                    GestureDetector(
                      onTap: () => _pickWeather(context),
                      child: _PeriodChip(s.weather == null
                          ? '날씨?'
                          : '${s.weather!.icon} ${s.weather!.labelKo}'),
                    ),
                    const SizedBox(width: 6),
                    _PeriodChip('${s.periodIcon} ${s.periodLabel} · ${s.clock}'),
                  ]),
                ],
              ),
              // 캐릭터 영역
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PettableHatti(
                      stage: s.stage,
                      onPet: () => s.pet(),
                    ),
                    const SizedBox(height: 6),
                    Text('Lv.${s.stage} · ${s.stageName}',
                        style: HattiText.body(
                            size: 12.5, color: HattiColors.creamDim)),
                    const SizedBox(height: 12),
                    SpeechBubble(_greeting(s)),
                    if (s.canDrawCard || s.todayCard != null) ...[
                      const SizedBox(height: 16),
                      _CardSlot(
                        drawn: s.todayCard,
                        onTap: () => _openCard(context),
                      ),
                    ],
                    if (s.history.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const HistoryScreen()),
                        ),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          children: [
                            Text('최근 마음 기록  ›',
                                style: HattiText.body(
                                    size: 13, color: HattiColors.creamDim)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final r in s.history.take(4))
                                  _HistoryChip(r.emotion),
                              ],
                            ),
                          ],
                        ),
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
        padding: const EdgeInsets.fromLTRB(6, 4, 11, 4),
        decoration: BoxDecoration(
          color: emotion.tone.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          EmotionFace(emotion, size: 20),
          const SizedBox(width: 6),
          Text(emotion.labelKo,
              style: HattiText.body(size: 12, color: Colors.white)),
        ]),
      );
}

/// 오늘의 카드 슬롯 — 체크인을 마쳐야 등장한다("보상 only").
class _CardSlot extends StatelessWidget {
  final LuckyCard? drawn;
  final VoidCallback onTap;
  const _CardSlot({required this.drawn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final undrawn = drawn == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: undrawn ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: undrawn
                ? const Color(0xFFEBB25A).withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(undrawn ? '🎴' : '✨', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            undrawn ? Content.cardSlotTeaser : '오늘의 카드 · ${drawn!.name}',
            style: HattiText.body(
                size: 13.5,
                color: undrawn ? HattiColors.cream : HattiColors.creamDim),
          ),
        ]),
      ),
    );
  }
}

/// 카드 공개 다이얼로그.
class _CardFace extends StatelessWidget {
  final LuckyCard card;
  const _CardFace(this.card);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HattiColors.paper, HattiColors.paperDeep],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, 18)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('오늘의 카드',
              style: HattiText.body(
                  size: 12, color: const Color(0xFFB08A5E), w: FontWeight.w600)),
          const SizedBox(height: 14),
          Text(card.name,
              style: HattiText.hand(
                  size: 34, color: HattiColors.cardInk, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('— ${card.keyword} —',
              style: HattiText.body(
                  size: 13, color: const Color(0xFFA98A63))),
          const SizedBox(height: 18),
          Text(card.message,
              textAlign: TextAlign.center,
              style: HattiText.hand(size: 22, color: HattiColors.cardInk)),
          const SizedBox(height: 22),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('닫기',
                style: HattiText.body(
                    size: 14, color: const Color(0xFFA98A63))),
          ),
        ]),
      ),
    );
  }
}

/// 쓰다듬을 수 있는 하띠 — 탭하면 몸으로 반응한다.
/// 대사만 바뀌고 캐릭터가 가만히 있으면 애착이 생기지 않는다.
/// 살짝 커졌다 돌아오며 좌우로 갸웃하는, 통통 튀는 반응.
class _PettableHatti extends StatefulWidget {
  final int stage;
  final VoidCallback onPet;

  const _PettableHatti({required this.stage, required this.onPet});

  @override
  State<_PettableHatti> createState() => _PettableHattiState();
}

class _PettableHattiState extends State<_PettableHatti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    widget.onPet();
    _c.forward(from: 0); // 연타해도 매번 처음부터 반응
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          final pop = sin(t * pi); // 0 → 1 → 0
          return Transform.rotate(
            angle: 0.07 * sin(t * pi * 2), // 좌우로 갸웃
            child: Transform.scale(scale: 1 + 0.09 * pop, child: child),
          );
        },
        child: HattiCharacter(stage: widget.stage),
      ),
    );
  }
}
