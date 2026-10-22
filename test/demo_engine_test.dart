import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine_examples/core/engine/demo_engine.dart';

class _MarkerComponent extends Component {}

class _MarkerSystem extends System {
  @override
  List<Type> get requiredComponents => [_MarkerComponent];

  @override
  void update(double dt) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Engine engine;

  setUpAll(() async {
    engine = await DemoEngine.boot();
  });

  tearDownAll(() async {
    await engine.dispose();
  });

  test('boot leaves the shared engine initialized and running', () {
    expect(engine.isRunning, isTrue);
    expect(engine.world.entities, isEmpty);
  });

  test('reset clears entities, demo systems and stray bodies', () {
    final world = engine.world;
    world.addSystem(_MarkerSystem());
    world.createEntityWithComponents([TransformComponent(), _MarkerComponent()]);
    engine.physics.setGravity(0, 50);
    engine.time.timeScale = 0.25;
    engine.cameraSystem.mainCamera.zoom = 3;

    DemoEngine.reset(engine);

    expect(world.entities, isEmpty);
    expect(world.hasSystem<_MarkerSystem>(), isFalse);
    expect(engine.physics.bodyCount, 0);
    expect(engine.physics.gravity.y, 981);
    expect(engine.time.timeScale, 1.0);
    expect(engine.cameraSystem.mainCamera.zoom, 1.0);
  });

  test('reset adds the requested default systems, once', () {
    DemoEngine.reset(
      engine,
      include: {DefaultSystem.rendering, DefaultSystem.physics},
    );
    final world = engine.world;
    expect(world.hasSystem<RenderSystem>(), isTrue);
    expect(world.hasSystem<PhysicsSystem>(), isTrue);
    expect(world.hasSystem<LevelMapSystem>(), isFalse);

    DemoEngine.reset(engine, include: {DefaultSystem.rendering});
    expect(world.hasSystem<PhysicsSystem>(), isFalse);
    expect(world.systems.whereType<RenderSystem>().length, 1);
  });

  test('reset runs a paused or stopped engine again', () {
    engine.pause();
    DemoEngine.reset(engine);
    expect(engine.isRunning, isTrue);

    engine.stop();
    DemoEngine.reset(engine);
    expect(engine.isRunning, isTrue);
  });
}
