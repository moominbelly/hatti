import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/emotion.dart';
import '../models/extras.dart';
import '../services/auth_service.dart';
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1F35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '로그아웃',
          style: HattiText.body(size: 18, w: FontWeight.bold),
        ),
        content: Text(
          '정말 로그아웃 하시겠습니까?',
          style: HattiText.body(size: 15, color: HattiColors.creamDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              '아니요',
              style: HattiText.body(size: 14, color: HattiColors.creamDim),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthService>().logout();
            },
            child: Text(
              '네',
              style: HattiText.body(size: 14, color: HattiColors.coral, w: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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

    // 초기 상태 로딩 중에는 로딩 스피너 표시 (온보딩 화면 번쩍임 방지)
    if (s.isLoading && s.history.isEmpty && s.intimacy == 0) {
      return const Scaffold(
        body: DuskBackground(
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(HattiColors.cream),
            ),
          ),
        ),
      );
    }

    // 새로 가입한 회원이고 웰컴 페이지를 보지 않은 경우 시작 페이지 노출
    if (s.isFirstTime && !s.hasSeenWelcome) {
      return _WelcomeOnboarding(service: s);
    }

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
                    _PeriodChip('${s.periodIcon} ${s.periodLabel}'),
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
                              if (s.history.isEmpty)
                                Text(
                                  '아직 기록이 없어요',
                                  style: HattiText.body(
                                      size: 12,
                                      color: HattiColors.creamFaint),
                                )
                              else
                                for (final r in s.history.take(4))
                                  _HistoryChip(r),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PrimaryButton('체크인 시작하기',
                  onPressed: () => _startCheckin(context)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _showLogoutDialog(context),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '로그아웃',
                  style: HattiText.body(size: 13, color: HattiColors.creamFaint).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: HattiColors.creamFaint,
                  ),
                ),
              ),
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

class _WelcomeOnboarding extends StatefulWidget {
  final HattiService service;
  const _WelcomeOnboarding({required this.service});

  @override
  State<_WelcomeOnboarding> createState() => _WelcomeOnboardingState();
}

class _WelcomeOnboardingState extends State<_WelcomeOnboarding> {
  int _step = 0; // 0: welcome speech bubbles, 1: naming character
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DuskBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // 캐릭터 상단 배치 (새싹하띠 stage 1)
              const HattiCharacter(stage: 1, scale: 1.3),
              const SizedBox(height: 32),
              if (_step == 0) ...[
                // 첫 번째 투명 대화 상자 (줄바꿈 반영)
                const SpeechBubble(
                  '안녕! 나는 네 마음을\n함께 들여다볼 하띠야.',
                  fontSize: 18,
                ),
                const SizedBox(height: 16),
                
                // 두 번째 투명 대화 상자 (줄바꿈 반영)
                const SpeechBubble(
                  '매일 마음을 들려주면,\n내가 곁에서 들을게. 그거면 돼.',
                  fontSize: 18,
                ),
                const Spacer(flex: 3),
                
                // 좋아 시작할래 버튼
                PrimaryButton(
                  '좋아, 시작할래',
                  onPressed: () {
                    setState(() => _step = 1);
                  },
                ),
              ] else ...[
                // 캐릭터 바로 아래 문구
                Text(
                  '이 아이에게\n이름을 지어줄래?',
                  textAlign: TextAlign.center,
                  style: HattiText.body(size: 22, w: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                
                // 닉네임 입력 칸
                TextField(
                  controller: _nameCtrl,
                  style: HattiText.body(color: HattiColors.ink),
                  textAlign: TextAlign.center,
                  maxLength: 12,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  decoration: InputDecoration(
                    hintText: '이름을 입력해줘',
                    hintStyle: HattiText.body(color: HattiColors.ink.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: HattiColors.paper,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // "나중에 바꿀 수도 있어" 글귀
                Text(
                  '나중에 바꿀 수도 있어',
                  style: HattiText.body(size: 13, color: HattiColors.creamDim),
                ),
                const Spacer(flex: 3),
                
                // 시작하기 버튼
                PrimaryButton(
                  '시작하기',
                  onPressed: () async {
                    final name = _nameCtrl.text.trim();
                    if (name.isNotEmpty) {
                      await widget.service.updateCharacterName(name);
                    }
                    await widget.service.completeWelcome();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
