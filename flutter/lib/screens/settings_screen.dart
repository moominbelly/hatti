import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/hatti_service.dart';
import 'login_screen.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    final service = context.read<HattiService>();
    _nameCtrl = TextEditingController(text: service.characterName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _saveCharacterName() {
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) {
      context.read<HattiService>().updateCharacterName(name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이름이 "$name"(으)로 변경되었습니다.', style: HattiText.body(size: 13.5)),
          backgroundColor: const Color(0xFF1E1423),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
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
          '로그아웃 하시겠습니까?\n로그아웃 후에도 게스트 모드로 계속 이용할 수 있습니다.',
          style: HattiText.body(size: 14, color: HattiColors.creamDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              '취소',
              style: HattiText.body(size: 14, color: HattiColors.creamDim),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthService>().logout();
              Navigator.of(context).pop(); // Close settings screen
            },
            child: Text(
              '로그아웃',
              style: HattiText.body(size: 14, color: HattiColors.coral, w: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final hatti = context.watch<HattiService>();

    return Scaffold(
      backgroundColor: const Color(0xFF19121D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: HattiColors.cream, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '설정 및 계정',
          style: HattiText.body(size: 18, w: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // ── 계정 상태 카드 ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '계정 및 백업',
                          style: HattiText.body(size: 16, w: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: auth.isAuthenticated
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            auth.isAuthenticated ? '☁️ 서버 동기화 중' : '📱 기기 전용 (게스트)',
                            style: HattiText.body(
                              size: 11.5,
                              color: auth.isAuthenticated ? Colors.greenAccent : Colors.amberAccent,
                              w: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (auth.isAuthenticated) ...[
                      Text(
                        '로그인 계정: ${auth.currentUser ?? "사용자"}',
                        style: HattiText.body(size: 14, color: HattiColors.creamDim),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '모든 마음 기록과 캐릭터 상태가 서버에 안전하게 보관되고 있어요.',
                        style: HattiText.body(size: 12.5, color: HattiColors.creamFaint),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => _showLogoutDialog(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HattiColors.creamDim,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        child: Text('로그아웃', style: HattiText.body(size: 14)),
                      ),
                    ] else ...[
                      Text(
                        '현재 로그인 없이 기기에 기록이 저장되고 있습니다.',
                        style: HattiText.body(size: 13.5, color: HattiColors.creamDim),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '계정으로 로그인하시면 기기를 바꿔도 기록을 유지할 수 있어요.',
                        style: HattiText.body(size: 12.5, color: HattiColors.creamFaint),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HattiColors.coral,
                          foregroundColor: HattiColors.cream,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          minimumSize: const Size(double.infinity, 44),
                          elevation: 0,
                        ),
                        child: Text(
                          '로그인 / 회원가입 하러 가기 🔑',
                          style: HattiText.body(size: 14, w: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 캐릭터 이름 변경 카드 ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '캐릭터 설정',
                      style: HattiText.body(size: 16, w: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '캐릭터 이름',
                      style: HattiText.body(size: 13, color: HattiColors.creamDim),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            style: HattiText.body(color: HattiColors.ink),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: HattiColors.paper,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _saveCharacterName,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HattiColors.coral,
                            foregroundColor: HattiColors.cream,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            elevation: 0,
                          ),
                          child: Text('저장', style: HattiText.body(size: 13.5, w: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 서비스 정보 ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '하띠 정보',
                      style: HattiText.body(size: 16, w: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('버전', style: HattiText.body(size: 13.5, color: HattiColors.creamDim)),
                        Text('v0.1.0', style: HattiText.body(size: 13.5, color: HattiColors.creamFaint)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '매일, 마음을 들여다보는 작은 친구 하띠와 함께합니다.',
                      style: HattiText.body(size: 12.5, color: HattiColors.creamFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
