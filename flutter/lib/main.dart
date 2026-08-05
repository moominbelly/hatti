import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/auth_service.dart';
import 'services/hatti_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/common.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 로드 및 웹 서버 차단 방지 예외 처리
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(".env 로드 예외 (웹 배포 폴백): $e");
  }

  const defaultUrl = 'https://gkwwthordurlujcfyvyj.supabase.co';
  const defaultKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdrd3d0aG9yZHVybHVqY2Z5dnlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ1NDUwNzYsImV4cCI6MjEwMDEyMTA3Nn0.eDxNuPujmablVOMGMAYrvkYv5NavW4eEQGn3Wh9Xs4Q';

  final supabaseUrl = (dotenv.env['SUPABASE_URL'] != null &&
          dotenv.env['SUPABASE_URL']!.isNotEmpty)
      ? dotenv.env['SUPABASE_URL']!
      : defaultUrl;

  final supabaseKey = (dotenv.env['SUPABASE_ANON_KEY'] != null &&
          dotenv.env['SUPABASE_ANON_KEY']!.isNotEmpty)
      ? dotenv.env['SUPABASE_ANON_KEY']!
      : defaultKey;

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const HattiApp());
}

class HattiApp extends StatelessWidget {
  const HattiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => HattiService()),
      ],
      child: MaterialApp(
        title: '하띠',
        debugShowCheckedModeBanner: false,
        theme: buildHattiTheme(),
        home: Consumer<HattiService>(
          builder: (context, hatti, _) {
            if (hatti.isLoading) {
              return const Scaffold(
                body: DuskBackground(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(HattiColors.cream),
                    ),
                  ),
                ),
              );
            }
            return hatti.hasSeenWelcome
                ? const HomeScreen()
                : const OnboardingScreen();
          },
        ),
      ),
    );
  }
}
