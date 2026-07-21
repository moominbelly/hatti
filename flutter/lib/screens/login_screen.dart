import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../widgets/hatti_character.dart';
import '../models/emotion.dart';
import '../theme.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(); // email
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isSignUpMode = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignUpMode = !_isSignUpMode;
      _errorMessage = null;
      _successMessage = null;
      _usernameController.clear();
      _passwordController.clear();
      _nicknameController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _handleLogin() async {
    final email = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = '이메일과 비밀번호를 모두 입력해 주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      await authService.login(email, password);
      
      // Consumer가 로그인 상태 변화(isAuthenticated)를 감지하여 자동으로 홈 화면으로 전환합니다.
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

  Future<void> _handleSignUp() async {
    final email = _usernameController.text.trim();
    final nickname = _nicknameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || nickname.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = '모든 입력 칸을 채워 주세요.';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = '비밀번호와 비밀번호 확인이 일치하지 않습니다.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = '비밀번호는 최소 6글자 이상이어야 합니다.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      final successMsg = await authService.signUp(email, password, nickname);
      
      if (mounted) {
        setState(() {
          _successMessage = successMsg;
          _isSignUpMode = false;
          // 이메일은 편의상 유지하고 비밀번호 입력창만 초기화
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
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
                    'Hatti',
                    style: HattiText.hand(size: 36, w: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '매일의 마음을 돌보는 감정 다마고치',
                    style: HattiText.body(size: 14, color: HattiColors.creamDim),
                  ),
                  const SizedBox(height: 32),

                  // 로그인 / 회원가입 카드 영역
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
                          _isSignUpMode ? '회원가입' : '로그인',
                          style: HattiText.body(
                            size: 18, 
                            color: HattiColors.ink, 
                            w: FontWeight.bold
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        
                        // 닉네임 입력 (회원가입 모드일 때만 표시)
                        if (_isSignUpMode) ...[
                          TextField(
                            controller: _nicknameController,
                            style: HattiText.body(color: HattiColors.ink),
                            decoration: _buildInputDecoration(hint: '닉네임'),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 이메일 입력
                        TextField(
                          controller: _usernameController,
                          keyboardType: TextInputType.emailAddress,
                          style: HattiText.body(color: HattiColors.ink),
                          decoration: _buildInputDecoration(hint: '이메일 (example@email.com)'),
                        ),
                        const SizedBox(height: 12),
                        
                        // 비밀번호 입력
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: HattiText.body(color: HattiColors.ink),
                          decoration: _buildInputDecoration(hint: '비밀번호'),
                        ),
                        const SizedBox(height: 12),

                        // 비밀번호 확인 입력 (회원가입 모드일 때만 표시)
                        if (_isSignUpMode) ...[
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            style: HattiText.body(color: HattiColors.ink),
                            decoration: _buildInputDecoration(hint: '비밀번호 확인'),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          const SizedBox(height: 4),
                        ],
                        
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

                        // 성공/알림 메시지
                        if (_successMessage != null) ...[
                          Text(
                            _successMessage!,
                            style: HattiText.body(
                              size: 12, 
                              color: Colors.green
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 확인/가입 버튼
                        ElevatedButton(
                          onPressed: _isLoading 
                              ? null 
                              : (_isSignUpMode ? _handleSignUp : _handleLogin),
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
                                  _isSignUpMode ? '가입하기' : '하띠 만나기',
                                  style: HattiText.body(
                                    size: 16, 
                                    w: FontWeight.bold
                                  ),
                                ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 로그인 ↔ 회원가입 모드 토글 링크
                        GestureDetector(
                          onTap: _isLoading ? null : _toggleMode,
                          child: Text(
                            _isSignUpMode 
                                ? '이미 계정이 있으신가요? 로그인하기' 
                                : '아직 계정이 없으신가요? 회원가입',
                            style: HattiText.body(
                              size: 13, 
                              color: HattiColors.coral, 
                              w: FontWeight.bold
                            ),
                            textAlign: TextAlign.center,
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

  InputDecoration _buildInputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
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
    );
  }
}
