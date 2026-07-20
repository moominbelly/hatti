import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/emotion.dart';

/// 체크인 API. Supabase Edge Function 호출 연동.
class ApiClient {
  /// [period]: 'morning' | 'evening', [intimacy]: 프롬프트 톤 조절용
  Future<CheckinResult> checkin(String text,
      {required String period, required int intimacy}) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'checkin',
        body: {
          'text': text.trim(),
          'period': period,
        },
      );

      if (response.status != 200) {
        throw Exception('서버 응답 오류 (Code: ${response.status})');
      }

      final resBody = response.data;
      if (resBody == null) {
        throw Exception('응답 데이터가 없습니다.');
      }

      final status = resBody['status'];

      if (status == 'crisis') {
        return const CheckinResult.crisis();
      } else if (status == 'error') {
        throw Exception(resBody['message'] ?? '생각을 정리하는 중 문제가 발생했어요.');
      } else if (status == 'success') {
        final data = resBody['data'];
        if (data == null) {
          throw Exception('정상 데이터 영역이 누락되었습니다.');
        }
        return CheckinResult(
          crisis: false,
          emotion: EmotionMeta.fromKey(data['emotion']),
          intensity: data['intensity'] ?? 3,
          contextKeyword: data['context_keyword'] ?? '오늘의 마음',
          empathy: data['empathy'] ?? '',
          affirmation: data['affirmation'] ?? '',
        );
      } else {
        throw Exception('알 수 없는 서버 응답 형식입니다.');
      }
    } catch (e) {
      // 에러를 그대로 위로 던져 checkin_flow.dart에서 에러 상태로 처리되도록 함
      rethrow;
    }
  }
}

