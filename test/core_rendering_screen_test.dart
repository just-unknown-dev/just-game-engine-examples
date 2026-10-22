import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine_examples/core/di/app_config.dart';
import 'package:just_game_engine_examples/core/engine/demo_engine.dart';
import 'package:just_game_engine_examples/features/core_rendering/core_rendering_screen.dart';

/// Every chip of the merged Core Engine & Rendering screen builds its demo
/// on the shared engine without throwing, and leaves something to draw.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Engine engine;

  setUpAll(() async {
    engine = await DemoEngine.boot();
    setupDependencies(engine);
  });

  tearDownAll(() async {
    await engine.dispose();
  });

  const chips = [
    // Core
    'Lifecycle',
    'Time Scale',
    'ECS',
    'Subsystems',
    'Game Loop',
    // Rendering
    'Primitives',
    'Layers & Z-Order',
    'Particles',
    'Hierarchy',
    'Custom Draw',
    'Culling & Stats',
  ];

  testWidgets('every demo chip builds', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CoreRenderingScreen())),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final failures = <String>[];
    for (final label in chips) {
      final chip = find.widgetWithText(FilterChip, label);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final error = tester.takeException();
      if (error != null) failures.add('$label: $error');
      if (engine.world.entities.isEmpty) failures.add('$label: empty world');
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    final error = tester.takeException();
    if (error != null) failures.add('closing: $error');
    // The screen leaves the shared engine clean and running.
    expect(engine.world.entities, isEmpty);
    expect(engine.isRunning, isTrue);

    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
