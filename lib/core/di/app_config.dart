import 'package:just_di/just_di.dart';
import 'package:just_game_engine/just_game_engine.dart';

T getIt<T extends Object>() => JustDi.get<T>();

class AppConfig {
  bool isMobile;

  AppConfig({this.isMobile = false});
}

/// Registers the app's services. [engine] is the shared 2-D engine
/// (`demoEngine`), already initialized and running.
void setupDependencies(Engine engine) {
  if (!JustDi.isRegistered<AppConfig>()) {
    JustDi.registerLazySingleton<AppConfig>(() => AppConfig());
  }
  if (JustDi.isRegistered<Engine>()) JustDi.unregister<Engine>();
  JustDi.registerSingleton<Engine>(engine);
}
