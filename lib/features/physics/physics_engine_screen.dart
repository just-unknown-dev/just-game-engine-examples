import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  particleStorm,
  gravityWarp,
  bounciness,
  shapeMixer,
  bodyStack;

  String get label => switch (this) {
    particleStorm => 'Particle Storm',
    gravityWarp => 'Gravity Warp',
    bounciness => 'Bounciness',
    shapeMixer => 'Shape Mixer',
    bodyStack => 'Body Stack',
  };

  IconData get icon => switch (this) {
    particleStorm => Icons.bubble_chart,
    gravityWarp => Icons.swap_vert,
    bounciness => Icons.sports_tennis,
    shapeMixer => Icons.category,
    bodyStack => Icons.stacked_bar_chart,
  };

  Color get accentColor => switch (this) {
    particleStorm => const Color(0xFF29B6F6),
    gravityWarp => const Color(0xFF66BB6A),
    bounciness => const Color(0xFFFF7043),
    shapeMixer => const Color(0xFFAB47BC),
    bodyStack => const Color(0xFFFFCA28),
  };

  String get description => switch (this) {
    particleStorm =>
      'High-count circle simulation stress-testing the broad-phase SpatialGrid. '
          'Tune ball count and initial speed to explore performance limits.',
    gravityWarp =>
      'Real-time gravity direction manipulation — every dynamic body responds '
          'immediately with no re-spawn required.',
    bounciness =>
      'Restitution coefficient [0…1] controls energy preserved on impact. '
          'Six columns each drop a ball with a distinct restitution value.',
    shapeMixer =>
      'Circles, rectangles, and convex polygons colliding together. '
          'SAT (Separating Axis Theorem) resolves all cross-shape pairs.',
    bodyStack =>
      'Stacked rigid bodies demonstrating impulse resolution and mass-weighted '
          'positional correction. Drop a heavy ball to topple the tower.',
  };

  String get codeSnippet => switch (this) {
    particleStorm =>
      'final body = PhysicsBody(\n'
          '  position: Vector2(x, y),\n'
          '  velocity: Vector2(vx, vy),\n'
          '  shape: CircleShape(radius),\n'
          '  mass: 1.0,\n'
          '  restitution: 0.94,\n'
          '  friction: 0.01,\n'
          '  drag: 0.01,\n'
          '  useGravity: true,\n'
          ');\n'
          'engine.physics.addBody(body);\n\n'
          '// Broad-phase: SpatialGrid (100 px cells)\n'
          '// Narrow-phase: SAT for all shape pairs',
    gravityWarp =>
      '// Change gravity vector at runtime:\n'
          'engine.physics.gravity.setValues(0,  98);   // ↓ down\n'
          'engine.physics.gravity.setValues(0, -98);   // ↑ up\n'
          'engine.physics.gravity.setValues(-98, 0);   // ← left\n'
          'engine.physics.gravity.setValues(98,  0);   // → right\n'
          'engine.physics.gravity.setValues(0,   0);   // zero-g\n\n'
          '// Per-body opt-in:\n'
          'body.useGravity = true;\n'
          'body.isAwake   = true;  // wake sleeping body',
    bounciness =>
      '// restitution 0 = perfectly inelastic (clay)\n'
          '// restitution 1 = perfectly elastic (ideal)\n\n'
          'PhysicsBody(\n'
          '  shape: CircleShape(14),\n'
          '  mass: 1.0,\n'
          '  restitution: 0.8,   // ← tune this\n'
          '  friction: 0.0,\n'
          '  drag: 0.0,\n'
          ');\n\n'
          '// Resolution uses: min(a.restitution, b.restitution)',
    shapeMixer =>
      '// Circle\n'
          'PhysicsBody(shape: CircleShape(r), mass: 1);\n\n'
          '// Rectangle\n'
          'PhysicsBody(\n'
          '  shape: RectangleShape(w, h),\n'
          '  mass: 1,\n'
          ');\n\n'
          '// Convex polygon (List<Offset> vertices)\n'
          'PhysicsBody(\n'
          '  shape: PolygonShape([\n'
          '    Offset(0, -r), Offset(r, r * 0.6),\n'
          '    Offset(-r, r * 0.6),\n'
          '  ]),\n'
          '  mass: 1,\n'
          ');',
    bodyStack =>
      '// Static body (mass = 0 → infinite mass):\n'
          'PhysicsBody(\n'
          '  shape: RectangleShape(w, h),\n'
          '  mass: 0,\n'
          '  restitution: 0.2,\n'
          ');\n\n'
          '// Dynamic block:\n'
          'PhysicsBody(\n'
          '  shape: RectangleShape(60, 26),\n'
          '  mass: 2.0,\n'
          '  restitution: 0.1,\n'
          '  friction: 0.6,\n'
          ');',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ECS helpers
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class PhysicsEngineScreen extends StatefulWidget {
  const PhysicsEngineScreen({super.key});

  @override
  State<PhysicsEngineScreen> createState() => _PhysicsEngineScreenState();
}

class _PhysicsEngineScreenState extends State<PhysicsEngineScreen>
    with SingleTickerProviderStateMixin {
  // ── Engine ───────────────────────────────────────────────────────────────
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final GlobalKey _canvasKey = GlobalKey();

  // ── State ────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.particleStorm;
  String _statusMessage = '';

  // ── Particle Storm settings ───────────────────────────────────────────────
  int _ballCount = 200;
  double _initialVelocity = 220;
  bool _gravityEnabled = true;

  final math.Random _random = math.Random();
  Size _arenaSize = const Size(800, 500);

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshArenaSize();
      _buildDemo(_demo);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clearAll();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tick
  // ─────────────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1_000_000.0;
    _lastTick = elapsed;
    _engine.physics.update(dt);
    _world.update(dt);
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // World management
  // ─────────────────────────────────────────────────────────────────────────

  void _refreshArenaSize() {
    final ro = _canvasKey.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.hasSize) {
      _arenaSize = ro.size;
    } else {
      _arenaSize = MediaQuery.sizeOf(context);
    }
  }

  void _clearAll() {
    _world.destroyAllEntities();
    _world.clearSystems();
    final bodies = List<PhysicsBody>.from(_engine.physics.bodies);
    for (final b in bodies) {
      _engine.physics.removeBody(b);
    }
  }

  void _buildDemo(_Demo demo) {
    _demo = demo;
    _statusMessage = '';
    _refreshArenaSize();
    _clearAll();
    _engine.rendering.camera.reset();
    _engine.physics.gravity.setValues(0, 98);

    _world.addSystem(_PhysicsSyncSystem());
    _world.addSystem(_CameraAwareRenderSystem(_engine.rendering.camera));

    switch (demo) {
      case _Demo.particleStorm:
        _buildParticleStorm();
      case _Demo.gravityWarp:
        _buildGravityWarp();
      case _Demo.bounciness:
        _buildBounciness();
      case _Demo.shapeMixer:
        _buildShapeMixer();
      case _Demo.bodyStack:
        _buildBodyStack();
    }

    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Arena walls (viewport-relative helper)
  // ─────────────────────────────────────────────────────────────────────────

  double get _halfW => (_arenaSize.width - 50) / 2;
  double get _halfH => (_arenaSize.height - 50) / 2;
  static const _kThick = 24.0;

  void _createWalls({double restitution = 0.96, double friction = 0.02}) {
    final hw = _halfW;
    final hh = _halfH;
    final wallDefs = <({Offset pos, Size size})>[
      (
        pos: Offset(0, hh + _kThick / 2),
        size: Size(hw * 2 + _kThick * 2, _kThick),
      ),
      (
        pos: Offset(0, -hh - _kThick / 2),
        size: Size(hw * 2 + _kThick * 2, _kThick),
      ),
      (
        pos: Offset(-hw - _kThick / 2, 0),
        size: Size(_kThick, hh * 2 + _kThick * 2),
      ),
      (
        pos: Offset(hw + _kThick / 2, 0),
        size: Size(_kThick, hh * 2 + _kThick * 2),
      ),
    ];

    for (final w in wallDefs) {
      final body = PhysicsBody(
        position: Vector2(w.pos.dx, w.pos.dy),
        shape: RectangleShape(w.size.width, w.size.height),
        mass: 0,
        restitution: restitution,
        friction: friction,
        drag: 0,
        useGravity: false,
      );
      _engine.physics.addBody(body);
      _world.createEntityWithComponents([
        _PhysicsComponent(body: body),
        TransformComponent(position: w.pos),
        RenderableComponent(
          renderable: RectangleRenderable(
            size: w.size,
            fillColor: const Color(0xFF1A2E44),
            strokeColor: const Color(0xFF3D6A8A),
            strokeWidth: 1.5,
            layer: 1,
          ),
        ),
      ], name: 'wall');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Particle Storm
  // ─────────────────────────────────────────────────────────────────────────

  void _buildParticleStorm() {
    _engine.physics.gravity.setValues(0, _gravityEnabled ? 98 : 0);
    _createWalls();
    _spawnCircles(_ballCount, _initialVelocity);
    _statusMessage = 'Adjust sliders then tap Respawn';
  }

  void _spawnCircles(int count, double speed) {
    const r = 6.0;
    final hw = _halfW - r - 4;
    final hh = _halfH - r - 4;
    for (int i = 0; i < count; i++) {
      final x = (_random.nextDouble() * 2 - 1) * hw;
      final y = (_random.nextDouble() * 2 - 1) * hh;
      final vx = (_random.nextDouble() * 2 - 1) * speed;
      final vy = (_random.nextDouble() * 2 - 1) * speed;
      final body = PhysicsBody(
        position: Vector2(x, y),
        velocity: Vector2(vx, vy),
        shape: CircleShape(r),
        mass: 1.0,
        restitution: 0.94,
        friction: 0.01,
        drag: 0.01,
        useGravity: _gravityEnabled,
      );
      _engine.physics.addBody(body);
      _world.createEntityWithComponents([
        _PhysicsComponent(body: body),
        TransformComponent(position: Offset(x, y)),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: r,
            fillColor: Color.lerp(
              const Color(0xFF29B6F6),
              const Color(0xFFF4D35E),
              _random.nextDouble(),
            )!,
            strokeColor: Colors.white.withValues(alpha: 0.4),
            strokeWidth: 1,
            layer: 5,
          ),
        ),
      ], name: 'ball');
    }
  }

  void _setParticleGravity(bool enabled) {
    setState(() {
      _gravityEnabled = enabled;
      _engine.physics.gravity.setValues(0, enabled ? 98 : 0);
      for (final b in _engine.physics.bodies) {
        if (b.mass > 0) {
          b.useGravity = enabled;
          b.isAwake = true;
        }
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Gravity Warp
  // ─────────────────────────────────────────────────────────────────────────

  void _buildGravityWarp() {
    _createWalls(restitution: 0.85);
    final hw = _halfW - 10.0;
    final hh = _halfH - 10.0;
    for (int i = 0; i < 80; i++) {
      final x = (_random.nextDouble() * 2 - 1) * hw;
      final y = (_random.nextDouble() * 2 - 1) * hh;
      final body = PhysicsBody(
        position: Vector2(x, y),
        velocity: Vector2(
          (_random.nextDouble() * 2 - 1) * 80,
          (_random.nextDouble() * 2 - 1) * 80,
        ),
        shape: CircleShape(9.0),
        mass: 1.0,
        restitution: 0.88,
        friction: 0.01,
        drag: 0.003,
        useGravity: true,
      );
      _engine.physics.addBody(body);
      _world.createEntityWithComponents([
        _PhysicsComponent(body: body),
        TransformComponent(position: Offset(x, y)),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: 9.0,
            fillColor: Color.lerp(
              const Color(0xFF66BB6A),
              const Color(0xFF42A5F5),
              _random.nextDouble(),
            )!,
            strokeColor: Colors.white.withValues(alpha: 0.3),
            strokeWidth: 1,
            layer: 5,
          ),
        ),
      ], name: 'ball');
    }
    _statusMessage = 'Tap a direction to warp gravity';
  }

  void _warpGravity(double gx, double gy, String label) {
    _engine.physics.gravity.setValues(gx, gy);
    for (final b in _engine.physics.bodies) {
      if (b.mass > 0) {
        b.useGravity = gx != 0 || gy != 0;
        b.isAwake = true;
      }
    }
    setState(() => _statusMessage = 'Gravity → $label');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Bounciness
  // ─────────────────────────────────────────────────────────────────────────

  static const _kRestValues = <double>[0.0, 0.2, 0.4, 0.6, 0.8, 1.0];
  static const _kRestColors = <Color>[
    Color(0xFF78909C),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFFFF7043),
    Color(0xFFE040FB),
  ];

  void _buildBounciness() {
    _engine.physics.gravity.setValues(0, 120);
    final hw = _halfW;
    final hh = _halfH;

    // Floor + side walls only (no ceiling — let high-restitution balls fly up)
    for (final w in <({Offset pos, Size size})>[
      (
        pos: Offset(0, hh + _kThick / 2),
        size: Size(hw * 2 + _kThick * 2, _kThick),
      ),
      (
        pos: Offset(-hw - _kThick / 2, 0),
        size: Size(_kThick, hh * 2 + _kThick * 2),
      ),
      (
        pos: Offset(hw + _kThick / 2, 0),
        size: Size(_kThick, hh * 2 + _kThick * 2),
      ),
    ]) {
      final body = PhysicsBody(
        position: Vector2(w.pos.dx, w.pos.dy),
        shape: RectangleShape(w.size.width, w.size.height),
        mass: 0,
        restitution: 1.0, // floor has perfect restitution: ball governs bounce
        friction: 0,
        drag: 0,
        useGravity: false,
      );
      _engine.physics.addBody(body);
      _world.createEntityWithComponents([
        _PhysicsComponent(body: body),
        TransformComponent(position: w.pos),
        RenderableComponent(
          renderable: RectangleRenderable(
            size: w.size,
            fillColor: const Color(0xFF1A2E44),
            strokeColor: const Color(0xFF3D6A8A),
            strokeWidth: 1.5,
            layer: 1,
          ),
        ),
      ], name: 'wall');
    }

    _dropBalls();
    _statusMessage = 'Higher restitution = more energy retained per bounce';
  }

  void _dropBalls() {
    final count = _kRestValues.length;
    final spacing = (_halfW * 2 - 60) / (count - 1);
    final startX = -(_halfW - 30);

    for (int i = 0; i < count; i++) {
      final x = startX + i * spacing;
      final rest = _kRestValues[i];
      final color = _kRestColors[i];

      final body = PhysicsBody(
        position: Vector2(x, -_halfH * 0.75),
        shape: CircleShape(14.0),
        mass: 1.0,
        restitution: rest,
        friction: 0.0,
        drag: 0.0,
        useGravity: true,
      );
      _engine.physics.addBody(body);
      _world.createEntityWithComponents([
        _PhysicsComponent(body: body),
        TransformComponent(position: Offset(x, -_halfH * 0.75)),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 5,
            getBoundsCallback: () =>
                Rect.fromCircle(center: Offset.zero, radius: 28),
            onRender: (canvas, _) {
              canvas.drawCircle(Offset.zero, 14, Paint()..color = color);
              canvas.drawCircle(
                Offset.zero,
                14,
                Paint()
                  ..color = Colors.white.withValues(alpha: 0.5)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5,
              );
              final tp = TextPainter(
                text: TextSpan(
                  text: rest.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout();
              tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
            },
          ),
        ),
      ]);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Shape Mixer
  // ─────────────────────────────────────────────────────────────────────────

  void _buildShapeMixer() {
    _createWalls(restitution: 0.8);
    for (int i = 0; i < 12; i++) {
      _addShape(_random.nextInt(3));
    }
    _statusMessage = 'Add more shapes with the buttons below';
  }

  void _addShape(int type) {
    final hw = _halfW - 20.0;
    final hh = _halfH - 20.0;
    final x = (_random.nextDouble() * 2 - 1) * hw;
    final y = (_random.nextDouble() * 2 - 1) * hh;
    final vx = (_random.nextDouble() * 2 - 1) * 120;
    final vy = (_random.nextDouble() * 2 - 1) * 120;
    final color = Color.lerp(
      const Color(0xFFAB47BC),
      const Color(0xFF29B6F6),
      _random.nextDouble(),
    )!;

    switch (type) {
      case 0: // Circle
        const r = 10.0;
        final body = PhysicsBody(
          position: Vector2(x, y),
          velocity: Vector2(vx, vy),
          shape: CircleShape(r),
          mass: 1.0,
          restitution: 0.75,
          friction: 0.1,
          drag: 0.005,
          useGravity: true,
        );
        _engine.physics.addBody(body);
        _world.createEntityWithComponents([
          _PhysicsComponent(body: body),
          TransformComponent(position: Offset(x, y)),
          RenderableComponent(
            renderable: CircleRenderable(
              radius: r,
              fillColor: color,
              strokeColor: Colors.white.withValues(alpha: 0.4),
              strokeWidth: 1.2,
              layer: 5,
            ),
          ),
        ]);

      case 1: // Rectangle
        const w = 28.0, h = 20.0;
        final body = PhysicsBody(
          position: Vector2(x, y),
          velocity: Vector2(vx, vy),
          shape: RectangleShape(w, h),
          mass: 1.5,
          restitution: 0.6,
          friction: 0.2,
          drag: 0.01,
          useGravity: true,
        );
        _engine.physics.addBody(body);
        _world.createEntityWithComponents([
          _PhysicsComponent(body: body),
          TransformComponent(position: Offset(x, y)),
          RenderableComponent(
            renderable: RectangleRenderable(
              size: const Size(w, h),
              fillColor: color,
              strokeColor: Colors.white.withValues(alpha: 0.4),
              strokeWidth: 1.2,
              layer: 5,
            ),
          ),
        ]);

      case 2: // Triangle polygon
        const r = 14.0;
        final verts = const [
          Offset(0, -r),
          Offset(r, r * 0.7),
          Offset(-r, r * 0.7),
        ];
        final body = PhysicsBody(
          position: Vector2(x, y),
          velocity: Vector2(vx, vy),
          shape: PolygonShape(verts),
          mass: 1.2,
          restitution: 0.7,
          friction: 0.15,
          drag: 0.008,
          useGravity: true,
        );
        _engine.physics.addBody(body);
        _world.createEntityWithComponents([
          _PhysicsComponent(body: body),
          TransformComponent(position: Offset(x, y)),
          RenderableComponent(
            renderable: CustomRenderable(
              layer: 5,
              getBoundsCallback: () =>
                  Rect.fromCircle(center: Offset.zero, radius: r * 2),
              onRender: (canvas, _) {
                final path = Path()
                  ..moveTo(verts[0].dx, verts[0].dy)
                  ..lineTo(verts[1].dx, verts[1].dy)
                  ..lineTo(verts[2].dx, verts[2].dy)
                  ..close();
                canvas.drawPath(path, Paint()..color = color);
                canvas.drawPath(
                  path,
                  Paint()
                    ..color = Colors.white.withValues(alpha: 0.4)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.2,
                );
              },
            ),
          ),
        ]);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Body Stack
  // ─────────────────────────────────────────────────────────────────────────

  void _buildBodyStack() {
    _engine.physics.gravity.setValues(0, 150);
    _createWalls(restitution: 0.2, friction: 0.5);
    _buildTower();
    _statusMessage = 'Tap "Drop Ball" to send a heavy ball into the tower';
  }

  void _buildTower() {
    const blockW = 58.0;
    const blockH = 26.0;
    const rowCount = 6;
    final floorY = _halfH - _kThick / 2 - blockH / 2;

    for (int row = 0; row < rowCount; row++) {
      final y = floorY - row * (blockH + 2);
      final cols = rowCount - row;
      final totalW = cols * (blockW + 4) - 4;
      final startX = -totalW / 2 + blockW / 2;

      for (int col = 0; col < cols; col++) {
        final x = startX + col * (blockW + 4);
        final body = PhysicsBody(
          position: Vector2(x, y),
          shape: RectangleShape(blockW, blockH),
          mass: 2.0,
          restitution: 0.1,
          friction: 0.6,
          drag: 0.02,
          useGravity: true,
        );
        _engine.physics.addBody(body);
        _world.createEntityWithComponents([
          _PhysicsComponent(body: body),
          TransformComponent(position: Offset(x, y)),
          RenderableComponent(
            renderable: RectangleRenderable(
              size: const Size(blockW, blockH),
              fillColor: Color.lerp(
                const Color(0xFF1565C0),
                const Color(0xFFFFCA28),
                row / rowCount,
              )!,
              strokeColor: Colors.white.withValues(alpha: 0.3),
              strokeWidth: 1,
              layer: 5,
            ),
          ),
        ]);
      }
    }
  }

  void _dropHeavyBall() {
    const r = 20.0;
    final spawnY = -_halfH + r + 10;
    final body = PhysicsBody(
      position: Vector2((_random.nextDouble() * 2 - 1) * 20, spawnY),
      shape: CircleShape(r),
      mass: 15.0,
      restitution: 0.3,
      friction: 0.3,
      drag: 0.01,
      useGravity: true,
    );
    _engine.physics.addBody(body);
    _world.createEntityWithComponents([
      _PhysicsComponent(body: body),
      TransformComponent(position: Offset(0, spawnY)),
      RenderableComponent(
        renderable: CircleRenderable(
          radius: r,
          fillColor: const Color(0xFFFF5252),
          strokeColor: Colors.white.withValues(alpha: 0.6),
          strokeWidth: 2,
          layer: 10,
        ),
      ),
    ], name: 'wrecking_ball');
    setState(() => _statusMessage = 'Heavy ball dropped!');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stats line
  // ─────────────────────────────────────────────────────────────────────────

  String get _statsLine {
    final bodies = _engine.physics.bodies;
    final dynamic = bodies.where((b) => b.mass > 0).length;
    final awake = bodies.where((b) => b.mass > 0 && b.isAwake).length;
    final gx = _engine.physics.gravity.x;
    final gy = _engine.physics.gravity.y;
    return 'bodies: ${bodies.length}'
        '  dynamic: $dynamic'
        '  awake: $awake'
        '  gravity (${gx.toStringAsFixed(0)}, ${gy.toStringAsFixed(0)})';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildCanvas()),
        _buildDemoSelector(),
        _buildControlPanel(),
        _buildCodeCard(),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF060D18),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_demo.icon, color: _demo.accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                _demo.label,
                style: TextStyle(
                  color: _demo.accentColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const Text(
                'PhysicsEngine  ·  PhysicsBody  ·  CollisionShape',
                style: TextStyle(color: Color(0xFF29B6F6), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _demo.description,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            _statsLine,
            style: TextStyle(
              color: _demo.accentColor.withValues(alpha: 0.85),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return GameCameraControls(
      camera: _engine.rendering.camera,
      enablePan: true,
      enablePinch: true,
      showZoomLevel: true,
      child: GameWidget(
        key: _canvasKey,
        engine: _engine,
        showFPS: true,
        showDebug: false,
      ),
    );
  }

  Widget _buildDemoSelector() {
    return Container(
      color: const Color(0xFF060D18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFF121E2E)),
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              itemCount: _Demo.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final d = _Demo.values[i];
                final active = d == _demo;
                return FilterChip(
                  avatar: Icon(
                    d.icon,
                    size: 13,
                    color: active ? d.accentColor : Colors.white38,
                  ),
                  label: Text(
                    d.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: active ? Colors.white : Colors.white54,
                    ),
                  ),
                  selected: active,
                  showCheckmark: false,
                  selectedColor: d.accentColor.withValues(alpha: 0.18),
                  backgroundColor: const Color(0xFF0E1A2A),
                  side: BorderSide(
                    color: active
                        ? d.accentColor.withValues(alpha: 0.7)
                        : const Color(0xFF1E2E40),
                  ),
                  onSelected: (_) => _buildDemo(d),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      color: const Color(0xFF060D18),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: _buildDemoControls(),
    );
  }

  Widget _buildDemoControls() {
    switch (_demo) {
      case _Demo.particleStorm:
        return _buildParticleStormControls();
      case _Demo.gravityWarp:
        return _buildGravityWarpControls();
      case _Demo.bounciness:
        return _buildBouncinessControls();
      case _Demo.shapeMixer:
        return _buildShapeMixerControls();
      case _Demo.bodyStack:
        return _buildBodyStackControls();
    }
  }

  Widget _buildParticleStormControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text(
              'Gravity',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(width: 6),
            Switch(
              value: _gravityEnabled,
              onChanged: _setParticleGravity,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Slider(
                value: _ballCount.toDouble(),
                min: 50,
                max: 1200,
                divisions: 23,
                label: '$_ballCount',
                onChanged: (v) => setState(() => _ballCount = v.round()),
                onChangeEnd: (_) => _buildDemo(_demo),
              ),
            ),
            const Text(
              'Count',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        Row(
          children: [
            const Text(
              'Speed ',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            Expanded(
              child: Slider(
                value: _initialVelocity,
                min: 0,
                max: 800,
                divisions: 32,
                label: _initialVelocity.round().toString(),
                onChanged: (v) => setState(() => _initialVelocity = v),
                onChangeEnd: (_) => _buildDemo(_demo),
              ),
            ),
            _actionButton(
              'Respawn',
              const Color(0xFF29B6F6),
              () => _buildDemo(_demo),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGravityWarpControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _actionButton(
          '↓ Down',
          const Color(0xFF66BB6A),
          () => _warpGravity(0, 98, 'Down ↓'),
        ),
        _actionButton(
          '↑ Up',
          const Color(0xFF66BB6A),
          () => _warpGravity(0, -98, 'Up ↑'),
        ),
        _actionButton(
          '← Left',
          const Color(0xFF66BB6A),
          () => _warpGravity(-98, 0, 'Left ←'),
        ),
        _actionButton(
          '→ Right',
          const Color(0xFF66BB6A),
          () => _warpGravity(98, 0, 'Right →'),
        ),
        _actionButton(
          '◉ Zero-G',
          const Color(0xFF66BB6A),
          () => _warpGravity(0, 0, 'Zero-G ◉'),
        ),
      ],
    );
  }

  Widget _buildBouncinessControls() {
    return Row(
      children: [
        _actionButton(
          'Drop Again',
          const Color(0xFFFF7043),
          () => _buildDemo(_demo),
        ),
        const SizedBox(width: 12),
        const Text(
          'restitution:  0.0  0.2  0.4  0.6  0.8  1.0',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildShapeMixerControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _actionButton(
          '+ Circle',
          const Color(0xFFAB47BC),
          () => setState(() => _addShape(0)),
        ),
        _actionButton(
          '+ Rect',
          const Color(0xFFAB47BC),
          () => setState(() => _addShape(1)),
        ),
        _actionButton(
          '+ Polygon',
          const Color(0xFFAB47BC),
          () => setState(() => _addShape(2)),
        ),
        _actionButton(
          'Clear',
          const Color(0xFF78909C),
          () => _buildDemo(_demo),
        ),
      ],
    );
  }

  Widget _buildBodyStackControls() {
    return Row(
      children: [
        _actionButton('Drop Ball', const Color(0xFFFFCA28), _dropHeavyBall),
        const SizedBox(width: 8),
        _actionButton(
          'Rebuild Tower',
          const Color(0xFFFFCA28),
          () => _buildDemo(_demo),
        ),
        const SizedBox(width: 12),
        const Text(
          'ball mass: 15  ·  restitution: 0.3',
          style: TextStyle(
            color: Colors.white30,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: onTap != null
              ? color.withValues(alpha: 0.15)
              : const Color(0xFF111C2A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: onTap != null
                ? color.withValues(alpha: 0.55)
                : const Color(0xFF1A2535),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap != null ? Colors.white : Colors.white30,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCodeCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF090F1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _demo.accentColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(_demo.icon, size: 13, color: _demo.accentColor),
                const SizedBox(width: 6),
                Text(
                  _demo.label,
                  style: TextStyle(
                    color: _demo.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text(
                  'just_game_engine · PhysicsEngine API',
                  style: TextStyle(color: Colors.white24, fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              width: double.infinity,
              child: SingleChildScrollView(
                child: Text(
                  _demo.codeSnippet,
                  style: const TextStyle(
                    color: Color(0xFFB0C8E0),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
