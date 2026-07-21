import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/emotion.dart';
import '../services/api_client.dart';
import '../services/hatti_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/hatti_character.dart';

enum _Phase { prompt, analyzing, response, crisis }

class CheckinFlowScreen extends StatefulWidget {
  const CheckinFlowScreen({super.key});

  @override
  State<CheckinFlowScreen> createState() => _CheckinFlowScreenState();
}

class _CheckinFlowScreenState extends State<CheckinFlowScreen> {
  final _api = ApiClient();
  final _textCtrl = TextEditingController();
  _Phase _phase = _Phase.prompt;
  CheckinResult? _result;
  bool _showCard = false;
  late final String _prompt;

  @override
  void initState() {
    super.initState();
    final s = context.read<HattiService>();
    final pool = s.isMorning ? Content.morningPrompts : Content.eveningPrompts;
    _prompt = pool[Random().nextInt(pool.length)];
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _phase = _Phase.analyzing);
    final s = context.read<HattiService>();
    try {
      final res = await _api.checkin(_textCtrl.text,
          period: s.period, intimacy: s.intimacy);
      if (!mounted) return;
      setState(() {
        _result = res;
        _showCard = false;
        _phase = res.crisis ? _Phase.crisis : _Phase.response;
      });
    } catch (e) {
      if (!mounted) return;
      // 분석중 상태 해제 및 입력창으로 복구 (텍스트는 컨트롤러에 유지됨)
      setState(() => _phase = _Phase.prompt);
      
      // 에러 다이얼로그 띄우기
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: HattiColors.paper,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('앗, 오류가 발생했어요',
              style: HattiText.body(size: 17, color: HattiColors.ink, w: FontWeight.bold)),
          content: Text(
            e.toString().replaceAll('Exception:', '').trim(),
            style: HattiText.body(color: HattiColors.cardInk),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('다시 해보기',
                  style: HattiText.body(color: HattiColors.coral, w: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _finish() async {
    // 로딩 인디케이터 표시 (DB 동기화 대기)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: HattiColors.coral),
      ),
    );

    final s = context.read<HattiService>();
    final prevStage = s.stage;
    final prevStreak = s.streak;

    try {
      await s.loadStateAndHistory();

      if (!mounted) return;
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

      String? msg;
      if (s.stage > prevStage) {
        msg = '🌱 하띠가 자랐어! 이제 «${s.stageName}»';
      } else if (s.streak > prevStreak && const [3, 7, 14].contains(s.streak)) {
        msg = '🎉 ${s.streak}일 연속! 하띠가 특별한 인사를 준비했어';
      }

      Navigator.of(context).pop(msg); // flow 화면을 닫고 메인에 마일스톤 토스트 메시지 반환
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      Navigator.of(context).pop(); // 그냥 닫기
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DuskBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          child: switch (_phase) {
            _Phase.prompt => _buildPrompt(),
            _Phase.analyzing => _buildAnalyzing(),
            _Phase.response => _buildResponse(),
            _Phase.crisis => _buildCrisis(),
          },
        ),
      ),
    );
  }

  // ── ② 입력 ──────────────────────────────────────────────
  Widget _buildPrompt() {
    final hasText = _textCtrl.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Text('← 돌아가기',
              style: HattiText.body(size: 14, color: HattiColors.creamDim)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Column(children: [
            const HattiCharacter(scale: 0.6),
            SpeechBubble(_prompt),
          ]),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: TextField(
            controller: _textCtrl,
            onChanged: (_) => setState(() {}),
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: HattiText.body(size: 15.5),
            decoration: InputDecoration(
              hintText: Content.inputPlaceholder,
              hintStyle:
                  HattiText.body(size: 15.5, color: HattiColors.creamFaint),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.16)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.16)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                    color: HattiColors.coral.withValues(alpha: 0.6)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton('하띠에게 들려주기', onPressed: hasText ? _submit : null),
      ],
    );
  }

  // ── ③ 분석중 ────────────────────────────────────────────
  Widget _buildAnalyzing() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const HattiCharacter(),
        const SizedBox(height: 18),
        const SpeechBubble('하띠가 네 마음을 읽는 중…'),
        const SizedBox(height: 16),
        const _ThinkingDots(),
      ],
    );
  }

  // ── ④ 응답 ──────────────────────────────────────────────
  Widget _buildResponse() {
    final r = _result!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘의 감정',
              style: HattiText.body(size: 13, color: HattiColors.creamDim)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _EmotionChip(r.emotion, r.intensity),
              _ContextTag(r.contextKeyword),
            ],
          ),
          const SizedBox(height: 22),
          Center(
            child: Column(children: [
              HattiCharacter(
                  tone: r.emotion.tone, mood: r.emotion, scale: 0.66),
              SpeechBubble(r.empathy),
            ]),
          ),
          const SizedBox(height: 20),
          if (!_showCard)
            GhostButton('하띠의 확언 카드 받기 ✉️',
                onPressed: () => setState(() => _showCard = true))
          else ...[
            _AffirmationCard(r.affirmation),
            const SizedBox(height: 20),
            PrimaryButton('체크인 마치기', onPressed: _finish),
          ],
        ],
      ),
    );
  }

  // ── ⑤ 위기 ──────────────────────────────────────────────
  Widget _buildCrisis() {
    return Column(
      children: [
        const SizedBox(height: 12),
        const HattiCharacter(mood: Emotion.sadness, scale: 0.6),
        const SpeechBubble('잠깐, 지금 마음이 많이 힘든 것 같아.'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(Content.crisisMessage,
                style: HattiText.body(size: 15, color: HattiColors.cream)),
            const SizedBox(height: 18),
            for (final (name, contact, hours) in Content.crisisResources)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(children: [
                  Text(name,
                      style: HattiText.body(
                          size: 13, color: HattiColors.creamDim)),
                  Text(contact,
                      style: HattiText.body(
                          size: 24,
                          color: const Color(0xFFFFD9A8),
                          w: FontWeight.w700)),
                  Text('$hours · 언제든 연결돼요',
                      style: HattiText.body(
                          size: 12, color: HattiColors.creamFaint)),
                ]),
              ),
          ]),
        ),
        const Spacer(),
        GhostButton('홈으로 돌아가기',
            onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

// ── 작은 조각들 ────────────────────────────────────────────

class _EmotionChip extends StatelessWidget {
  final Emotion emotion;
  final int intensity;
  const _EmotionChip(this.emotion, this.intensity);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emotion.labelKo,
              style: HattiText.body(
                  size: 16, color: emotion.tone, w: FontWeight.w600)),
          const SizedBox(width: 8),
          for (var i = 1; i <= 5; i++)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= intensity
                      ? emotion.tone
                      : Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ),
        ]),
      );
}

class _ContextTag extends StatelessWidget {
  final String text;
  const _ContextTag(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('# $text',
            style: HattiText.body(size: 12, color: HattiColors.creamDim)),
      );
}

class _AffirmationCard extends StatelessWidget {
  final String text;
  const _AffirmationCard(this.text);
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: Transform.rotate(
        angle: -0.024,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [HattiColors.paper, HattiColors.paperDeep],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 34,
                  offset: const Offset(0, 16)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('오늘의 확언',
                  style: HattiText.body(
                      size: 12, color: const Color(0xFFB08A5E), w: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(text,
                  style: HattiText.hand(size: 27, color: HattiColors.cardInk)),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Text('— 하띠가',
                    style: HattiText.hand(
                        size: 16, color: const Color(0xFFA98A63))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();
  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final phase = (_c.value - i * 0.15) % 1.0;
          final lift = (phase < 0.5) ? (1 - (phase * 2)) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Transform.translate(
              offset: Offset(0, -7 * lift),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HattiColors.cream
                      .withValues(alpha: 0.4 + 0.6 * lift),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
