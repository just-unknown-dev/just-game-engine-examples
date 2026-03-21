import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'core/di/app_config.dart';
import 'core/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  setupDependencies();

  // Initialize the singleton game engine (all subsystems).
  final engine = Engine();
  await engine.initialize();

  runApp(const JustEngineDemo());
}

class JustEngineDemo extends StatelessWidget {
  const JustEngineDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Just Game Engine Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFFF5746F),
        scaffoldBackgroundColor: const Color(0xFF07070F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5746F),
          brightness: Brightness.dark,
          surface: const Color(0xFF111122),
        ),
        cardColor: const Color(0xFF1a1a2e),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF07070F),
          foregroundColor: Color(0xFFF5746F),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
