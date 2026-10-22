import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart';

import 'core/di/app_config.dart';
import 'core/engine/demo_engine.dart';
import 'core/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The shared 2-D engine every demo screen draws into. In 2.x `Engine()`
  // makes a new engine each call, so it is made once here and handed out
  // through DI (`demoEngine`). 3-D demos make engines of their own.
  final Engine engine;
  try {
    engine = await DemoEngine.boot();
  } on EngineInitException catch (e) {
    runApp(_EngineFailedApp(error: e));
    return;
  }

  setupDependencies(engine);
  runApp(const JustEngineDemo());
}

class JustEngineDemo extends StatelessWidget {
  const JustEngineDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Just Game Engine Demo',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      home: const HomeScreen(),
    );
  }
}

final ThemeData _theme = ThemeData.dark().copyWith(
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
);

/// Shown when the shared engine fails to initialize: which stage, and why.
class _EngineFailedApp extends StatelessWidget {
  const _EngineFailedApp({required this.error});

  final EngineInitException error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Color(0xFFF5746F),
                ),
                const SizedBox(height: 16),
                Text(
                  'The engine failed to start (${error.stage}).',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  '${error.cause}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
