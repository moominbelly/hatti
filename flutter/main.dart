import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/hatti_service.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(const HattiApp());
}

class HattiApp extends StatelessWidget {
  const HattiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HattiService(),
      child: MaterialApp(
        title: '하띠',
        debugShowCheckedModeBanner: false,
        theme: buildHattiTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
