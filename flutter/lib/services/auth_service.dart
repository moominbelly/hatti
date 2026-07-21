import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 하띠 사용자 인증 서비스.
/// Supabase Auth 연동 완료.
class AuthService extends ChangeNotifier {
  String? _currentUser;

  AuthService() {
    // 앱이 실행될 때 기존 로그인 세션이 유지되어 있으면 불러옴
    final sessionUser = Supabase.instance.client.auth.currentUser;
    if (sessionUser != null) {
      _currentUser = sessionUser.email;
    }
  }

  String? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  /// 로그인 처리 (이메일 전용)
  Future<void> login(String email, String password) async {
    if (!email.contains('@')) {
      throw Exception('올바른 이메일 형식을 입력해 주세요.');
    }

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user != null) {
        _currentUser = user.email;
        notifyListeners();
      } else {
        throw Exception('사용자 정보를 가져올 수 없습니다.');
      }
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        throw Exception('이메일 또는 비밀번호가 올바르지 않아요.');
      } else {
        throw Exception(e.message);
      }
    } catch (e) {
      throw Exception('로그인 중 문제가 발생했습니다: $e');
    }
  }

  /// 회원가입 처리 (자동 로그인 방지)
  Future<String> signUp(String email, String password, String nickname) async {
    if (!email.contains('@')) {
      throw Exception('올바른 이메일 형식을 입력해 주세요.');
    }

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'nickname': nickname,
        },
      );

      final user = response.user;
      final session = response.session;

      if (user != null) {
        if (session != null) {
          // 자동 로그인이 일어났을 경우 로그아웃 처리하여 가입 완료 후 직접 로그인하도록 유도
          await Supabase.instance.client.auth.signOut();
          _currentUser = null;
          notifyListeners();
          return '회원가입이 완료되었습니다!\n방금 가입한 이메일로 로그인해 주세요.';
        } else {
          // 이메일 인증 메일 발송 옵션이 켜져 있는 경우
          return '가입 인증 메일이 발송되었습니다!\n메일함의 확인 링크를 눌러 주세요.';
        }
      } else {
        throw Exception('회원가입에 실패했습니다.');
      }
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('회원가입 중 문제가 발생했습니다: $e');
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}

