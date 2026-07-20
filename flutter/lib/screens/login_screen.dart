import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../widgets/hatti_character.dart';
import '../models/emotion.dart';
import '../theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = '아이디와 비밀번호를 모두 입력해 주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      await authService.login(username, password);
      
      if (mounted) {
        // 로그인 성공 시 홈 화면으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: HattiColors.duskGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // 캐릭터 노출 (숨쉬기 + 미소 연출)
                  const HattiCharacter(
                    stage: 2,
                    mood: Emotion.joy,
                    scale: 1.1,
                  ),
                  const SizedBox(height: 16),
                  
                  // 서비스 타이틀
                  Text(
                    '하띠',
                    style: HattiText.hand(size: 36, w: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '매일의 마음을 돌보는 감정 다마고치',
                    style: HattiText.body(size: 14, color: HattiColors.creamDim),
                  ),
                  const SizedBox(height: 32),

                  // 로그인 카드 영역
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: HattiColors.paper,
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '로그인',
                          style: HattiText.body(
                            size: 18, 
                            color: HattiColors.ink, 
                            w: FontWeight.bold
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        
                        // 아이디 입력
                        TextField(
                          controller: _usernameController,
                          style: HattiText.body(color: HattiColors.ink),
                          decoration: InputDecoration(
                            hintText: '아이디 (test)',
                            hintStyle: HattiText.body(
                              color: HattiColors.ink.withValues(alpha: 0.5)
                            ),
                            filled: true,
                            fillColor: HattiColors.paperDeep.withValues(alpha: 0.3),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, 
                              vertical: 14
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: HattiColors.coral, 
                                width: 1.5
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // 비밀번호 입력
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: HattiText.body(color: HattiColors.ink),
                          decoration: InputDecoration(
                            hintText: '비밀번호 (1234)',
                            hintStyle: HattiText.body(
                              color: HattiColors.ink.withValues(alpha: 0.5)
                            ),
                            filled: true,
                            fillColor: HattiColors.paperDeep.withValues(alpha: 0.3),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, 
                              vertical: 14
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: HattiColors.coral, 
                                width: 1.5
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // 에러 메시지
                        if (_errorMessage != null) ...[
                          Text(
                            _errorMessage!,
                            style: HattiText.body(
                              size: 12, 
                              color: Colors.redAccent
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 로그인 버튼
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HattiColors.coral,
                            foregroundColor: HattiColors.cream,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      HattiColors.cream
                                    ),
                                  ),
                                )
                              : Text(
                                  '하띠 만나기',
                                  style: HattiText.body(
                                    size: 16, 
                                    w: FontWeight.bold
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
