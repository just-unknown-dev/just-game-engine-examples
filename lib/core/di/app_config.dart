import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

class AppConfig {
  bool isMobile;

  AppConfig({this.isMobile = false});
}

void setupDependencies() {
  getIt.registerLazySingleton<AppConfig>(() => AppConfig());
}
