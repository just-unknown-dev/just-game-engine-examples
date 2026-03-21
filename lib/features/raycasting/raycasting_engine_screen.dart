import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/widgets/camera_zoom_controls.dart';

class RaycastingEngineScreen extends StatefulWidget {
  const RaycastingEngineScreen({super.key});

  @override
  State<RaycastingEngineScreen> createState() => _RaycastingEngineScreenState();
}

class _RaycastingEngineScreenState extends State<RaycastingEngineScreen>
    with SingleTickerProviderStateMixin {
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  Duration _lastTickTime = Duration.zero;
  final GlobalKey _gameWidgetKey = GlobalKey();

  Size _viewportSize = Size.zero;
  late RaycastSystem _raycastSystem;
  PhysicsBody? _playerBody;
  int _enemiesDestroyed = 0;
  int _totalEnemies = 10;

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;

    _ticker = createTicker(_onTick)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildRaycastingShowcase();
    });
  }

  void _onTick(Duration elapsed) {
    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      return;
    }
    final dt = (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;

    // Drive input through the engine input system and fire once per click.
    _engine.input.update();
    if (_engine.input.mouse.isButtonDown(MouseButton.left)) {
      final clickPosition = _engine.input.mouse.position;
      // Consume this click to prevent a stuck button state from blocking
      // subsequent shots in this showcase.
      _engine.input.mouse.clear();
      _onViewportTap(clickPosition);
    }

    _engine.physics.update(dt);
    _engine.world.update(dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clearWorldAndPhysics();
    super.dispose();
  }

  void _clearWorldAndPhysics() {
    _world.destroyAllEntities();
    final allBodies = List<PhysicsBody>.from(_engine.physics.bodies);
    for (final body in allBodies) {
      _engine.physics.removeBody(body);
    }
  }

  Size _readViewportSize() {
    final renderObject = _gameWidgetKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }
    return MediaQuery.sizeOf(context);
  }

  void _rebuildRaycastingShowcase() {
    _viewportSize = _readViewportSize();
    if (_viewportSize == Size.zero) return;

    _engine.rendering.camera.viewportSize = _viewportSize;
    _engine.rendering.camera.position = Offset.zero;
    _engine.rendering.camera.rotation = 0;
    _engine.rendering.camera.zoom = 1;

    _clearWorldAndPhysics();
    _enemiesDestroyed = 0;

    _world.addSystem(_PhysicsSyncSystem());
    _raycastSystem = RaycastSystem();
    _world.addSystem(_raycastSystem);
    _world.addSystem(_RayVisualSystem());
    _world.addSystem(_CameraAwareRenderSystem(_engine.rendering.camera));

    _createPlayer();
    _createEnemies(_totalEnemies);

    setState(() {});
  }

  void _createPlayer() {
    const radius = 8.0;
    const playerColor = Color(0xFF00FF00); // Green

    _playerBody = PhysicsBody(
      position: Vector2.zero(),
      shape: CircleShape(radius),
      mass: 0, // Static player
      restitution: 0.9,
      friction: 0.05,
      drag: 0.02,
      useGravity: false,
    );

    _engine.physics.addBody(_playerBody!);

    _world.createEntityWithComponents([
      _PhysicsComponent(body: _playerBody!),
      TransformComponent(position: _playerBody!.position.toOffset()),
      RenderableComponent(
        renderable: CircleRenderable(
          radius: radius,
          fillColor: playerColor,
          strokeColor: Colors.white,
          strokeWidth: 2,
          layer: 10,
        ),
      ),
      RaycastColliderComponent(radius: radius, tag: 'player'),
    ], name: 'player');
  }

  void _createEnemies(int count) {
    const radius = 6.0;
    const circleRadius = 80.0; // Radius of the circle around player
    const enemyColor = Color(0xFFFF3333); // Red

    for (int i = 0; i < count; i++) {
      final angle = (2 * math.pi * i) / count;
      final x = circleRadius * math.cos(angle);
      final y = circleRadius * math.sin(angle);

      final body = PhysicsBody(
        position: Vector2(x, y),
        shape: CircleShape(radius),
        mass: 1,
        restitution: 0.8,
        friction: 0.02,
        drag: 0.01,
        useGravity: false,
      );

      _engine.physics.addBody(body);

      _world.createEntityWithComponents([
        _PhysicsComponent(body: body),
        TransformComponent(position: body.position.toOffset()),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: radius,
            fillColor: enemyColor,
            strokeColor: Colors.yellowAccent,
            strokeWidth: 1.5,
            layer: 5,
          ),
        ),
        RaycastColliderComponent(radius: radius, tag: 'enemy'),
      ], name: 'enemy_$i');
    }
  }

  void _onViewportTap(Offset tapPosition) {
    final playerBody = _playerBody;
    if (playerBody == null) return;

    final camera = _engine.rendering.camera;
    camera.viewportSize = _viewportSize;

    // screenToWorld expects raw screen-space coordinates in the game viewport.
    final worldPos = camera.screenToWorld(tapPosition);
    final playerPos = playerBody.position.toOffset();
    final direction = worldPos - playerPos;
    final ray = Ray(
      origin: playerPos,
      direction: direction,
      maxDistance: 1000.0,
    );

    final hits = _raycastSystem.castRayAll(ray, filterTag: 'enemy');

    // Always draw the fired ray so shooting feedback is deterministic.
    final rayEnd = hits.isNotEmpty ? hits.first.point : ray.at(ray.maxDistance);
    _createRayVisual(ray.origin, rayEnd);

    if (hits.isEmpty) return;

    for (final hit in hits) {
      _destroyEnemy(hit.entity);
    }

    setState(() {
      final remaining = _world.entities
          .where((e) => e.name?.startsWith('enemy_') ?? false)
          .length;
      _enemiesDestroyed = _totalEnemies - remaining;
    });
  }

  void _destroyEnemy(Entity entity) {
    // Remove physics body
    final physicsComp = entity.getComponent<_PhysicsComponent>();
    if (physicsComp != null) {
      _engine.physics.removeBody(physicsComp.body);
    }

    // Destroy entity
    _world.destroyEntity(entity);
  }

  void _createRayVisual(Offset from, Offset to) {
    // Create a temporary ray visual that fades out
    _world.createEntityWithComponents([
      TransformComponent(position: from),
      RenderableComponent(
        renderable: LineRenderable(
          endPoint: to - from,
          color: const Color(0xFFFFFF00),
          width: 2,
          layer: 8,
        ),
      ),
      _RayVisualComponent(createdAt: DateTime.now()),
    ], name: 'ray_visual');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: const Color(0xFF101925),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Raycasting Engine Showcase',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enemies destroyed: $_enemiesDestroyed / $_totalEnemies   |   Green = Player, Red = Enemies',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'Click on the viewport to fire a raycast from the green ball. Any red balls hit will be destroyed!',
                style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _rebuildRaycastingShowcase,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: CameraZoomControls(
            camera: _engine.rendering.camera,
            child: GameWidget(
              key: _gameWidgetKey,
              engine: _engine,
              showFPS: true,
              showDebug: false,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhysicsComponent extends Component {
  _PhysicsComponent({required this.body});
  final PhysicsBody body;
}

class _RayVisualComponent extends Component {
  _RayVisualComponent({required this.createdAt});
  final DateTime createdAt;
}

class _PhysicsSyncSystem extends System {
  @override
  List<Type> get requiredComponents => [_PhysicsComponent, TransformComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final physics = entity.getComponent<_PhysicsComponent>()!;
      final transform = entity.getComponent<TransformComponent>()!;
      transform.position = physics.body.position.toOffset();
      transform.rotation = physics.body.angle;
    });
  }
}

class _RayVisualSystem extends System {
  @override
  List<Type> get requiredComponents => [_RayVisualComponent];

  @override
  void update(double dt) {
    final entitiesToRemove = <Entity>[];
    forEach((entity) {
      final rayVisual = entity.getComponent<_RayVisualComponent>()!;
      final age = DateTime.now().difference(rayVisual.createdAt).inMilliseconds;
      if (age > 180) {
        entitiesToRemove.add(entity);
      }
    });

    for (final entity in entitiesToRemove) {
      world.destroyEntity(entity);
    }
  }
}

class _CameraAwareRenderSystem extends System {
  _CameraAwareRenderSystem(this.camera);

  final Camera camera;

  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    RenderableComponent,
  ];

  @override
  void render(Canvas canvas, Size size) {
    camera.viewportSize = size;
    canvas.save();
    camera.applyTransform(canvas, size);

    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final renderComp = entity.getComponent<RenderableComponent>()!;

      if (renderComp.syncTransform) {
        renderComp.renderable.position = transform.position;
        renderComp.renderable.rotation = transform.rotation;
        renderComp.renderable.scale = transform.scale;
      }

      if (renderComp.renderable.visible) {
        renderComp.renderable.render(canvas, size);
      }
    });

    canvas.restore();
  }
}
