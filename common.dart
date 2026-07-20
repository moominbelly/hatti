import 'package:flutter/material.dart';

import '../theme.dart';

/// 하띠 말풍선 — 손글씨체, 반투명.
class SpeechBubble extends StatelessWidget {
  final String text;
  final double fontSize;
  const SpeechBubble(this.text, {super.key, this.fontSize = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: HattiText.hand(size: fontSize),
      ),
    );
  }
}

/// 주요 액션 버튼 — 코랄 그라디언트.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const PrimaryButton(this.label, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEB9F6F), Color(0xFFE0784F)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: HattiText.body(
                  size: 16, color: Colors.white, w: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

/// 보조 버튼 — 테두리만.
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const GhostButton(this.label, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: const Size(double.infinity, 0),
        side: BorderSide(color: HattiColors.cream.withValues(alpha: 0.28)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label,
          style: HattiText.body(size: 14, color: HattiColors.creamDim)),
    );
  }
}

/// 배경 황혼 그라디언트 래퍼.
class DuskBackground extends StatelessWidget {
  final Widget child;
  const DuskBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: HattiColors.duskGradient),
      child: SafeArea(child: child),
    );
  }
}
