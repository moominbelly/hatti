import '../models/emotion.dart';
import '../logic/mock_analysis.dart';

/// 체크인 API. 지금은 목업.
///
/// ▶ 백엔드 연결 시 이 파일 한 곳만 바꾸면 된다:
///   checkin() 내부의 MockAnalysis 호출을
///   Supabase Edge Function 호출로 교체.
///
///   final res = await Supabase.instance.client.functions.invoke(
///     'checkin', body: {'text': text, 'period': period});
///   final data = res.data;
///   if (data['crisis'] == true) return const CheckinResult.crisis();
///   return CheckinResult(
///     crisis: false,
///     emotion: EmotionMeta.fromKey(data['emotion']),
///     intensity: data['intensity'],
///     contextKeyword: data['context_keyword'],
///     empathy: data['empathy'],
///     affirmation: data['affirmation'],
///   );
class ApiClient {
  /// [period]: 'morning' | 'evening', [intimacy]: 프롬프트 톤 조절용
  Future<CheckinResult> checkin(String text,
      {required String period, required int intimacy}) async {
    // 목업: 분석하는 척 잠깐 대기 (프로토타입과 동일한 체감)
    await Future.delayed(const Duration(milliseconds: 1500));
    return MockAnalysis.analyze(text.trim());
  }
}
