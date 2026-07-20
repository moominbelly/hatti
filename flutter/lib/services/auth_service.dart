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

  /// 로그인 처리
  /// 입력된 username에 @가 없을 경우 자동으로 @example.com을 결합하여 이메일 로그인을 지원합니다.
  Future<void> login(String username, String password) async {
    final email = username.contains('@') ? username : '$username@example.com';

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
        throw Exception('아이디 또는 비밀번호가 올바르지 않아요.');
      } else {
        throw Exception(e.message);
      }
    } catch (e) {
      throw Exception('로그인 중 문제가 발생했습니다: $e');
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}

