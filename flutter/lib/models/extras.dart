/// 홈 화면의 선택적 인터랙션에서 사용하는 날씨 및 오늘의 카드 모델 정의.
enum Weather { sunny, cloudy, rain, snow, windy, fog }

extension WeatherMeta on Weather {
  /// Supabase 데이터베이스 및 API용 키
  String get key => name;

  String get labelKo => switch (this) {
        Weather.sunny => '맑음',
        Weather.cloudy => '구름',
        Weather.rain => '비',
        Weather.snow => '눈',
        Weather.windy => '바람',
        Weather.fog => '안개',
      };

  String get icon => switch (this) {
        Weather.sunny => '☀️',
        Weather.cloudy => '☁️',
        Weather.rain => '🌧️',
        Weather.snow => '❄️',
        Weather.windy => '💨',
        Weather.fog => '🌫️',
      };

  static Weather fromKey(String key) =>
      Weather.values.firstWhere((w) => w.name == key, orElse: () => Weather.sunny);
}

class LuckyCard {
  final String id;
  final String name;
  final String keyword;
  final String message;

  const LuckyCard({
    required this.id,
    required this.name,
    required this.keyword,
    required this.message,
  });

  factory LuckyCard.fromJson(Map<String, dynamic> json) => LuckyCard(
        id: json['id'] as String,
        name: json['name'] as String,
        keyword: json['keyword'] as String,
        message: json['message'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'keyword': keyword,
        'message': message,
      };
}

/// 타로풍 럭키 카드 덱 (긍정/중립 구성)
const List<LuckyCard> luckyCards = [
  LuckyCard(id: 'star', name: '별', keyword: '희망', message: '작은 빛 하나가 너를 기다리고 있어.'),
  LuckyCard(id: 'sun', name: '태양', keyword: '생기', message: '오늘 네 안에 따뜻한 기운이 차오를 거야.'),
  LuckyCard(id: 'moon', name: '달', keyword: '직감', message: '마음이 향하는 쪽, 그게 아마 맞을 거야.'),
  LuckyCard(id: 'world', name: '세계', keyword: '완성', message: '네가 지나온 길들이 오늘 하나로 모여.'),
  LuckyCard(id: 'empress', name: '여황제', keyword: '돌봄', message: '누구보다 먼저, 너를 돌봐도 되는 날이야.'),
  LuckyCard(id: 'hermit', name: '은둔자', keyword: '쉼', message: '혼자 있는 시간이 너를 채워줄 거야.'),
  LuckyCard(id: 'strength', name: '힘', keyword: '용기', message: '생각보다 너는 훨씬 단단해.'),
  LuckyCard(id: 'temperance', name: '절제', keyword: '균형', message: '서두르지 않아도 괜찮은 하루야.'),
  LuckyCard(id: 'fool', name: '바보', keyword: '시작', message: '가볍게 첫 발을 떼어봐도 좋아.'),
  LuckyCard(id: 'magician', name: '마법사', keyword: '가능성', message: '네가 가진 것들이 오늘 쓸모를 찾을 거야.'),
  LuckyCard(id: 'wheel', name: '운명의 수레바퀴', keyword: '전환', message: '흐름이 조용히 방향을 바꾸는 중이야.'),
  LuckyCard(id: 'sprout', name: '새싹', keyword: '성장', message: '눈에 안 보여도, 너는 자라고 있어.'),
];
