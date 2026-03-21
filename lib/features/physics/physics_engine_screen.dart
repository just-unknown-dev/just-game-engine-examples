import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/widgets/camera_zoom_controls.dart';

class PhysicsEngineScreen extends StatefulWidget {
  const PhysicsEngineScreen({super.key});

  @override
  State<PhysicsEngineScreen> createState() => _PhysicsEngineScreenState();
}

class _PhysicsEngineScreenState extends State<PhysicsEngineScreen>
    with SingleTickerProviderStateMixin {
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  Duration _lastTickTime = Duration.zero;
  final GlobalKey _gameWidgetKey = GlobalKey();
  final math.Random _random = math.Random();

  Size _viewportSize = Size.zero;
  bool _gravityEnabled = true;
  int _ballCount = 200;
  double _initialVelocity = 220;

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;

    _ticker = createTicker(_onTick)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildPhysicsShowcase();
    });
  }

  void _onTick(Duration elapsed) {
    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      return;
    }
    final dt = (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;
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

  void _rebuildPhysicsShowcase() {
    _viewportSize = _readViewportSize();
    if (_viewportSize == Size.zero) return;

    _engine.rendering.camera.viewportSize = _viewportSize;
    _engine.rendering.camera.position = Offset.zero;
    _engine.rendering.camera.rotation = 0;
    _engine.rendering.camera.zoom = 1;

    _clearWorldAndPhysics();

    _engine.physics.gravity.setValues(0, _gravityEnabled ? 98 : 0);

    _world.addSystem(_PhysicsSyncSystem());
    _world.addSystem(_CameraAwareRenderSystem(_engine.rendering.camera));

    _createViewportWalls();
    _spawnBalls(_ballCount);

    setState(() {});
  }

  void _createViewportWalls() {
    const thickness = 24.0;
    final viewportWidth = _viewportSize.width - 50;
    final viewportHeight = _viewportSize.height - 50;
    final halfW = viewportWidth / 2;
    final halfH = viewportHeight / 2;

    final walls = <({Offset position, Size size})>[
      (
        position: Offset(0, halfH + (thickness / 2)),
        size: Size(viewportWidth + thickness * 2, thickness),
      ),
      (
        position: Offset(0, -halfH - (thickness / 2)),
        size: Size(viewportWidth + thickness * 2, thickness),
      ),
      (
        position: Offset(-halfW - (thickness / 2), 0),
        size: Size(thickness, viewportHeight + thickness * 2),
      ),
      (
        position: Offset(halfW + (thickness / 2), 0),
        size: Size(thickness, viewportHeight + thickness * 2),
      ),
    ];

    for (final wall in walls) {
      final body = PhysicsBody(
        position: Vector2(wall.position.dx, wall.position.dy),
        shape: RectangleShape(wall.size.width, wall.size.height),
        mass: 0,
        restitution: 0.96,
        friction: 0.02,
        drag: 0,
        useGravity: false,
      );
      _engine.physics.addBody(body);

      _world.createEntityWithComponents([
        _PhysicsComponent(body: body),
        TransformComponent(position: body.position.toOffset()),
        RenderableComponent(
          renderable: RectangleRenderable(
            size: wall.size,
            fillColor: const Color(0xFF223349),
            strokeColor: const Color(0xFF6AA6D8),
            strokeWidth: 1.5,
            layer: 1,
          ),
        ),
      ], name: 'wall');
    }
  }

  void _spawnBalls(int count) {
    const radius = 6.0;
    final halfW = _viewportSize.width / 2 - (radius + 28);
    final halfH = _viewportSize.height / 2 - (radius + 28);

    for (int i = 0; i < count; i++) {
      final x = (_random.nextDouble() * 2 - 1) * halfW;
      final y = (_random.nextDouble() * 2 - 1) * halfH;
      final vx = (_random.nextDouble() * 2 - 1) * _initialVelocity;
      final vy = (_random.nextDouble() * 2 - 1) * _initialVelocity;

      final body = PhysicsBody(
        position: Vector2(x, y),
        velocity: Vector2(vx, vy),
        shape: CircleShape(radius),
        mass: 1,
        restitution: 0.94,
        friction: 0.01,
        drag: 0.01,
        useGravity: _gravityEnabled,
      );

      _engine.physics.addBody(body);

      _world.createEntityWithComponents([
        _PhysicsComponent(body: body),
        TransformComponent(position: body.position.toOffset()),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: radius,
            fillColor: Color.lerp(
              const Color(0xFF7FE3FF),
              const Color(0xFFF4D35E),
              _random.nextDouble(),
            )!,
            strokeColor: Colors.white.withValues(alpha: 0.5),
            strokeWidth: 1,
            layer: 5,
          ),
        ),
      ], name: 'ball');
    }
  }

  void _setGravityEnabled(bool enabled) {
    setState(() {
      _gravityEnabled = enabled;
      _engine.physics.gravity.setValues(0, enabled ? 98 : 0);
      for (final body in _engine.physics.bodies) {
        if (body.mass > 0) {
          body.useGravity = enabled;
        }
      }
    });
  }

  int get _dynamicBodyCount =>
      _engine.physics.bodies.where((b) => b.mass > 0).length;

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
                'Physics Performance Showcase',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Balls/particles: $_dynamicBodyCount   |   Gravity: ${_gravityEnabled ? 'On' : 'Off'}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Gravity', style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 8),
                  Switch(value: _gravityEnabled, onChanged: _setGravityEnabled),

                  Expanded(
                    child: Slider(
                      value: _ballCount.toDouble(),
                      min: 50,
                      max: 1200,
                      divisions: 23,
                      label: '$_ballCount',
                      onChanged: (value) {
                        setState(() {
                          _ballCount = value.round();
                        });
                      },
                      onChangeEnd: (_) => _rebuildPhysicsShowcase(),
                    ),
                  ),
                  const Text(
                    'Count',
                    style: TextStyle(color: Color.fromARGB(255, 190, 183, 183)),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Speed', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: _initialVelocity,
                      min: 0,
                      max: 800,
                      divisions: 32,
                      label: _initialVelocity.round().toString(),
                      onChanged: (value) {
                        setState(() {
                          _initialVelocity = value;
                        });
                      },
                      onChangeEnd: (_) => _rebuildPhysicsShowcase(),
                    ),
                  ),
                  FilledButton(
                    onPressed: _rebuildPhysicsShowcase,
                    child: const Text('Respawn'),
                  ),
                ],
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
              showDebug: true,
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
