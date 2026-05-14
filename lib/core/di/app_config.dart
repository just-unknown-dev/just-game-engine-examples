import 'package:just_di/just_di.dart';

T getIt<T extends Object>() => JustDi.get<T>();

class AppConfig {
  bool isMobile;

  AppConfig({this.isMobile = false});
}

void setupDependencies() {
  if (!JustDi.isRegistered<AppConfig>()) {
    JustDi.registerLazySingleton<AppConfig>(() => AppConfig());
  }
}
