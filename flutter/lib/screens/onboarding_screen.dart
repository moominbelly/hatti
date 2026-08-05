import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/hatti_service.dart';
import '../widgets/hatti_character.dart';
import '../widgets/common.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0; // 0: 앱 설명 대화, 1: 캐릭터 이름 짓기
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleFinish(HattiService service) async {
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) {
      await service.updateCharacterName(name);
    } else {
      await service.updateCharacterName('하띠');
    }
    await service.completeWelcome();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<HattiService>();

    return Scaffold(
      body: DuskBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // 캐릭터 상단 배치 (새싹하띠 stage 1)
                  const HattiCharacter(stage: 1, scale: 1.3),
                  const SizedBox(height: 32),
                  if (_step == 0) ...[
                    // 첫 번째 설명 말풍선
                    const SpeechBubble(
                      '안녕! 나는 네 마음을\n함께 들여다볼 하띠야.',
                      fontSize: 18,
                    ),
                    const SizedBox(height: 16),
                    
                    // 두 번째 설명 말풍선
                    const SpeechBubble(
                      '매일 마음을 들려주면,\n내가 곁에서 들을게. 그거면 돼.',
                      fontSize: 18,
                    ),
                    const Spacer(flex: 3),
                    
                    // 시작 버튼
                    PrimaryButton(
                      '좋아, 시작할래',
                      onPressed: () {
                        setState(() => _step = 1);
                      },
                    ),
                  ] else ...[
                    // 캐릭터 이름 짓기 문구
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
                        hintText: '이름을 입력해줘 (기본: 하띠)',
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
                    
                    // 안내 문구
                    Text(
                      '나중에 설정에서 바꿀 수도 있어',
                      style: HattiText.body(size: 13, color: HattiColors.creamDim),
                    ),
                    const Spacer(flex: 3),
                    
                    // 시작하기 버튼
                    PrimaryButton(
                      '하띠와 시작하기',
                      onPressed: () => _handleFinish(service),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
