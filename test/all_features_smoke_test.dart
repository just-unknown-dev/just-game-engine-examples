import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine_examples/core/di/app_config.dart';
import 'package:just_game_engine_examples/core/engine/demo_engine.dart';
import 'package:just_game_engine_examples/core/screens/home_screen.dart';
import 'package:just_game_engine_examples/features/features_list.dart';

/// Opens every demo from the home screen's list, desktop layout, on the real
/// shared engine: each must build and run a few frames without throwing, and
/// a 2-D demo must still have its world once the demo before it is gone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Engine engine;

  setUpAll(() async {
    // Tests have no platform plugins: the Input demo listens for gamepads
    // through just_gamepads' event channel, so stand in a silent one.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          const EventChannel('just_gamepads/events'),
          MockStreamHandler.inline(onListen: (arguments, events) {}),
        );
    engine = await DemoEngine.boot();
    setupDependencies(engine);
  });

  tearDownAll(() async {
    await engine.dispose();
  });

  // Demos that draw nothing into the shared engine's world (Audio opens on
  // its music player; its entities come with the spatial and ECS tabs).
  const noSharedWorld = {
    'Audio Engine',
    'Storage & Signals',
    'Database & Signals',
    'Narrative & Dialogue',
    '3D Graphics',
    '3D Physics',
  };

  testWidgets('every feature opens from the list', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final failures = <String>[];
    for (final feature in appFeatures) {
      final tile = find.widgetWithText(ListTile, feature.title);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      // The previous demo goes, then this one mounts and runs.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        // Demos that load images and files first need real I/O to finish.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
      }
      final error = tester.takeException();
      if (error != null) failures.add('${feature.title}: $error');
      if (!noSharedWorld.contains(feature.title) &&
          engine.world.entities.isEmpty) {
        failures.add('${feature.title}: the shared world is empty');
      }
      expect(engine.isRunning || engine.isPaused, isTrue);
    }

    // Leave the last demo, so its dispose runs inside the test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    final error = tester.takeException();
    if (error != null) failures.add('closing: $error');

    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
