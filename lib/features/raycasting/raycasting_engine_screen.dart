import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  shoot,
  los,
  reflect,
  tracer,
  scanner;

  String get label => switch (this) {
    shoot => 'Shoot',
    los => 'Line of Sight',
    reflect => 'Reflection',
    tracer => 'Ray Tracer',
    scanner => 'Scanner',
  };

  IconData get icon => switch (this) {
    shoot => Icons.gps_fixed,
    los => Icons.visibility,
    reflect => Icons.flip,
    tracer => Icons.scatter_plot,
    scanner => Icons.radar,
  };

  Color get accentColor => switch (this) {
    shoot => const Color(0xFFFFCA28),
    los => const Color(0xFF66BB6A),
    reflect => const Color(0xFF29B6F6),
    tracer => const Color(0xFFAB47BC),
    scanner => const Color(0xFFFF7043),
  };

  String get description => switch (this) {
    shoot =>
      'Click in the viewport to fire a ray from the player (green). '
          'The nearest enemy (red) on the ray path is destroyed. Yellow line shows the ray path.',
    los =>
      'Green player checks line-of-sight to every orange target. '
          'A white LOS ray appears when the path is clear; cyan walls block it.',
    reflect =>
      'Rays bounce off reflective (cyan) walls using r = d - 2(d·n)n. '
          'Each segment is drawn with decreasing brightness as reflectivity decays.',
    tracer =>
      'RayTracer fires up to 4 bounces per ray. Click to launch a tracer shot; '
          'purple segments show the full multi-bounce path including all hits.',
    scanner =>
      'A 360° radial scanner sweeps from the player each frame. '
          'Rays are cast every N° and the hit ring is rendered as coloured wedges.',
  };

  String get codeSnippet => switch (this) {
    shoot =>
      'final ray = Ray(\n'
          '  origin: playerPos,\n'
          '  direction: targetDir,\n'
          '  maxDistance: 1000.0,\n'
          ');\n'
          'final hit = raycastSystem.castRay(ray, filterTag: \'enemy\');\n'
          'if (hit != null) {\n'
          '  world.destroyEntity(hit.entity);\n'
          '}',
    los =>
      '// Check clear path between two points:\n'
          'final clear = raycastSystem.hasLineOfSight(\n'
          '  playerPos,\n'
          '  targetPos,\n'
          '  ignoreTag: \'player\',\n'
          ');\n\n'
          '// ignoreTag skips the shooter so it cannot\n'
          '// block its own LOS check.',
    reflect =>
      'RaycastColliderComponent(\n'
          '  radius: 12,\n'
          '  isBlocker: true,\n'
          '  isReflective: true,\n'
          '  reflectivity: 0.85,  // energy fraction per bounce\n'
          ');\n\n'
          '// castRayAll returns ALL hits sorted nearest-first:\n'
          'final hits = raycastSystem.castRayAll(ray);\n'
          '// Reflection: r = d - 2(d·n)n',
    tracer =>
      'final tracer = RayTracer(\n'
          '  raycastSystem: raycastSystem,\n'
          '  maxBounces: 4,\n'
          '  minReflectivity: 0.1,\n'
          ');\n\n'
          'final trace = tracer.trace(ray);\n'
          'for (final seg in trace.segments) {\n'
          '  drawLine(seg.from, seg.to);\n'
          '}\n'
          'print(\'Total length: \${trace.totalLength}\');',
    scanner =>
      '// Radial sweep:\n'
          'for (int i = 0; i < 360; i += stepDeg) {\n'
          '  final angle = i * math.pi / 180;\n'
          '  final dir = Offset(math.cos(angle), math.sin(angle));\n'
          '  final ray = Ray(origin: center, direction: dir,\n'
          '                  maxDistance: scanRadius);\n'
          '  final hit = raycastSystem.castRay(ray);\n'
          '  final dist = hit?.distance ?? scanRadius;\n'
          '  // Draw wedge from center to dist\n'
          '}',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ECS Components
// ─────────────────────────────────────────────────────────────────────────────

class _PhysicsComponent extends Component {
  _PhysicsComponent({required this.body});
  final PhysicsBody body;
}

class _RayVisualComponent extends Component {
  _RayVisualComponent({
    required this.createdAt,
    this.color = const Color(0xFFFFFF00),
  });
  final DateTime createdAt;
  final Color color;
}

class _WallTagComponent extends Component {}

class _EnemyTagComponent extends Component {}

class _TargetTagComponent extends Component {}

class _ScanResultComponent extends Component {
  double _hitFraction = 1.0;
  double get hitFraction => _hitFraction;
  set hitFraction(double v) => _hitFraction = v;
}

// ─────────────────────────────────────────────────────────────────────────────
// ECS Systems
// ─────────────────────────────────────────────────────────────────────────────

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
    final toRemove = <Entity>[];
    forEach((entity) {
      final age = DateTime.now()
          .difference(entity.getComponent<_RayVisualComponent>()!.createdAt)
          .inMilliseconds;
      if (age > 220) toRemove.add(entity);
    });
    for (final e in toRemove) {
      world.destroyEntity(e);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class RaycastingEngineScreen extends StatefulWidget {
  const RaycastingEngineScreen({super.key});

  @override
  State<RaycastingEngineScreen> createState() => _RaycastingEngineScreenState();
}

class _RaycastingEngineScreenState extends State<RaycastingEngineScreen>
    with SingleTickerProviderStateMixin {
  // ── Engine ──────────────────────────────────────────────────────────────
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  // ── Demo ─────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.shoot;
  String _statusMessage = '';

  // ── Raycasting ───────────────────────────────────────────────────────────
  late RaycastSystem _raycastSystem;
  RayTracer? _rayTracer;

  // ── Shoot demo ───────────────────────────────────────────────────────────
  PhysicsBody? _playerBody;
  int _enemiesDestroyed = 0;
  int _totalEnemies = 10;

  // ── Scanner demo ─────────────────────────────────────────────────────────
  int _scannerDegrees = 30;

  // ── GameWidget key ───────────────────────────────────────────────────────
  final GlobalKey _gameWidgetKey = GlobalKey();

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildDemo(_demo));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clearWorldAndPhysics();
    super.dispose();
  }

  void _clearWorldAndPhysics() {
    _world.destroyAllEntities();
    _world.clearSystems();
    final allBodies = List<PhysicsBody>.from(_engine.physics.bodies);
    for (final body in allBodies) {
      _engine.physics.removeBody(body);
    }
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

    // Input for shoot demo
    if (_demo == _Demo.shoot) {
      _engine.input.update();
      if (_engine.input.mouse.isButtonDown(MouseButton.left)) {
        final pos = _engine.input.mouse.position;
        _engine.input.mouse.clear();
        _fireShot(pos);
      }
    }

    _engine.physics.update(dt);
    _world.update(dt);

    if (_demo == _Demo.scanner) _tickScanner();
    if (_demo == _Demo.los) _tickLos();

    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo builder
  // ─────────────────────────────────────────────────────────────────────────

  void _buildDemo(_Demo demo) {
    _demo = demo;
    _statusMessage = '';
    _playerBody = null;
    _enemiesDestroyed = 0;
    _rayTracer = null;

    _clearWorldAndPhysics();

    // Base systems for every demo
    _raycastSystem = RaycastSystem();
    _world.addSystem(_PhysicsSyncSystem());
    _world.addSystem(_raycastSystem);
    _world.addSystem(_RayVisualSystem());
    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));

    _engine.rendering.camera.position = Offset.zero;
    _engine.rendering.camera.setZoom(1.0);

    switch (demo) {
      case _Demo.shoot:
        _buildShoot();
      case _Demo.los:
        _buildLos();
      case _Demo.reflect:
        _buildReflect();
      case _Demo.tracer:
        _buildTracer();
      case _Demo.scanner:
        _buildScanner();
    }

    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared helpers
  // ─────────────────────────────────────────────────────────────────────────

  Size get _viewportSize {
    final ro = _gameWidgetKey.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.hasSize) return ro.size;
    return const Size(400, 400);
  }

  void _spawnBackground() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: 0,
          getBoundsCallback: () =>
              const Rect.fromLTWH(-2000, -2000, 4000, 4000),
          onRender: (canvas, _) {
            final paint = Paint()..color = const Color(0xFF080F1A);
            canvas.drawRect(
              const Rect.fromLTWH(-2000, -2000, 4000, 4000),
              paint,
            );
            // Grid
            final gridPaint = Paint()
              ..color = const Color(0xFF0D1825)
              ..strokeWidth = 0.5;
            for (int x = -20; x <= 20; x++) {
              canvas.drawLine(
                Offset(x * 40.0, -800),
                Offset(x * 40.0, 800),
                gridPaint,
              );
            }
            for (int y = -20; y <= 20; y++) {
              canvas.drawLine(
                Offset(-800, y * 40.0),
                Offset(800, y * 40.0),
                gridPaint,
              );
            }
          },
        ),
      ),
    ]);
  }

  Entity _spawnCircleEntity({
    required Offset position,
    required double radius,
    required Color fillColor,
    Color? strokeColor,
    double strokeWidth = 1.5,
    int layer = 5,
    String? tag,
    bool isBlocker = true,
    bool isReflective = false,
    double reflectivity = 0.8,
    List<Component> extra = const [],
  }) {
    // Static entities need no physics body — transform position is set once
    // and never overwritten, which is all RaycastSystem and RenderSystem need.
    return _world.createEntityWithComponents([
      TransformComponent(position: position),
      RenderableComponent(
        renderable: CircleRenderable(
          radius: radius,
          fillColor: fillColor,
          strokeColor: strokeColor ?? fillColor,
          strokeWidth: strokeWidth,
          layer: layer,
        ),
      ),
      RaycastColliderComponent(
        radius: radius,
        tag: tag,
        isBlocker: isBlocker,
        isReflective: isReflective,
        reflectivity: reflectivity,
      ),
      ...extra,
    ]);
  }

  void _spawnWallBox({
    required Offset position,
    required double width,
    required double height,
    Color color = const Color(0xFF1A3A5C),
    Color? strokeColor,
    bool isReflective = false,
    double reflectivity = 0.8,
    String? tag,
  }) {
    _world.createEntityWithComponents([
      TransformComponent(position: position),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 3,
          getBoundsCallback: () => Rect.fromCenter(
            center: Offset.zero,
            width: width,
            height: height,
          ),
          onRender: (canvas, _) {
            final rect = Rect.fromCenter(
              center: Offset.zero,
              width: width,
              height: height,
            );
            canvas.drawRect(rect, Paint()..color = color);
            canvas.drawRect(
              rect,
              Paint()
                ..color = strokeColor ?? color.withValues(alpha: 0.8)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          },
        ),
      ),
      RaycastColliderComponent(
        width: width,
        height: height,
        tag: tag,
        isBlocker: true,
        isReflective: isReflective,
        reflectivity: reflectivity,
      ),
      if (isReflective) _WallTagComponent(),
    ]);
  }

  void _spawnRayLine(
    Offset from,
    Offset to, {
    Color color = const Color(0xFFFFFF00),
    int lifetime = 220,
  }) {
    _world.createEntityWithComponents([
      TransformComponent(position: from),
      RenderableComponent(
        renderable: LineRenderable(
          endPoint: to - from,
          color: color,
          width: 1.5,
          layer: 8,
        ),
      ),
      _RayVisualComponent(createdAt: DateTime.now(), color: color),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shoot demo
  // ─────────────────────────────────────────────────────────────────────────

  void _buildShoot() {
    _totalEnemies = 12;
    _enemiesDestroyed = 0;
    _spawnBackground();

    // Player is static at world origin — no physics body needed.
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        renderable: CircleRenderable(
          radius: 9,
          fillColor: const Color(0xFF00E676),
          strokeColor: Colors.white,
          strokeWidth: 2,
          layer: 10,
        ),
      ),
      RaycastColliderComponent(radius: 9, tag: 'player'),
    ], name: 'player');

    // Enemies around the player in rings
    final rng = math.Random(99);
    for (int i = 0; i < _totalEnemies; i++) {
      final ring = i < 6 ? 90.0 : 160.0;
      final angle =
          (2 * math.pi * i) / (i < 6 ? 6 : (_totalEnemies - 6)) +
          rng.nextDouble() * 0.4;
      final pos = Offset(ring * math.cos(angle), ring * math.sin(angle));
      _spawnCircleEntity(
        position: pos,
        radius: 7,
        fillColor: const Color(0xFFFF3333),
        strokeColor: Colors.yellowAccent,
        strokeWidth: 1.5,
        tag: 'enemy',
        extra: [_EnemyTagComponent()],
      );
    }

    // Blocking walls scattered between player and enemies
    for (final (pos, w, h) in [
      (const Offset(-60, 50), 12.0, 60.0),
      (const Offset(55, -45), 60.0, 12.0),
      (const Offset(-30, -80), 10.0, 50.0),
    ]) {
      _spawnWallBox(position: pos, width: w, height: h);
    }

    _statusMessage = 'Click to fire — nearest enemy on ray path is destroyed';
  }

  void _fireShot(Offset screenPos) {
    const playerPos = Offset.zero;
    final camera = _engine.rendering.camera;
    camera.viewportSize = _viewportSize;
    final worldPos = camera.screenToWorld(screenPos);
    final dir = worldPos - playerPos;

    final ray = Ray(origin: playerPos, direction: dir, maxDistance: 800.0);
    final hit = _raycastSystem.castRay(ray, filterTag: 'enemy');
    final rayEnd = hit?.point ?? ray.at(ray.maxDistance);
    _spawnRayLine(playerPos, rayEnd, color: const Color(0xFFFFFF00));

    if (hit != null) {
      final physComp = hit.entity.getComponent<_PhysicsComponent>();
      if (physComp != null) _engine.physics.removeBody(physComp.body);
      _world.destroyEntity(hit.entity);
      final remaining = _world.entities
          .where((e) => e.hasComponent<_EnemyTagComponent>())
          .length;
      _enemiesDestroyed = _totalEnemies - remaining;
      _statusMessage = 'Hit! Destroyed: $_enemiesDestroyed / $_totalEnemies';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Line of Sight demo
  // ─────────────────────────────────────────────────────────────────────────

  void _buildLos() {
    _spawnBackground();

    // Player (green)
    _spawnCircleEntity(
      position: Offset.zero,
      radius: 10,
      fillColor: const Color(0xFF00E676),
      strokeColor: Colors.white,
      strokeWidth: 2,
      tag: 'player',
      layer: 10,
    );

    // Blocking walls (cyan)
    final walls = [
      (const Offset(-120, 0), 14.0, 120.0),
      (const Offset(80, 60), 14.0, 90.0),
      (const Offset(0, -90), 110.0, 14.0),
    ];
    for (final (pos, w, h) in walls) {
      _spawnWallBox(
        position: pos,
        width: w,
        height: h,
        color: const Color(0xFF0D3D4A),
        strokeColor: const Color(0xFF00BCD4),
        tag: 'wall',
      );
    }

    // Orange targets scattered around
    final positions = [
      const Offset(-200, 70),
      const Offset(180, -120),
      const Offset(60, 160),
      const Offset(-160, -150),
      const Offset(220, 100),
    ];
    for (final pos in positions) {
      _spawnCircleEntity(
        position: pos,
        radius: 8,
        fillColor: const Color(0xFFFF9800),
        strokeColor: const Color(0xFFFFCC02),
        strokeWidth: 1.5,
        tag: 'target',
        isBlocker: false,
        extra: [_TargetTagComponent()],
      );
    }

    _statusMessage =
        'LOS checked each frame — clear = white ray, blocked = dim';
  }

  void _tickLos() {
    // Remove old LOS rays
    final toKill = _world.entities
        .where((e) => e.hasComponent<_RayVisualComponent>())
        .toList();
    for (final e in toKill) {
      _world.destroyEntity(e);
    }

    const playerPos = Offset.zero;
    final targets = _world.entities
        .where((e) => e.hasComponent<_TargetTagComponent>())
        .toList();
    for (final t in targets) {
      final pos = t.getComponent<TransformComponent>()!.position;
      final clear = _raycastSystem.hasLineOfSight(
        playerPos,
        pos,
        ignoreTag: 'player',
      );
      _spawnRayLine(
        playerPos,
        pos,
        color: clear ? const Color(0xCCFFFFFF) : const Color(0x44FF5252),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reflection demo
  // ─────────────────────────────────────────────────────────────────────────

  void _buildReflect() {
    _spawnBackground();

    // Reflective walls (cyan-tinted)
    final walls = [
      (const Offset(0, 150), 340.0, 14.0, true),
      (const Offset(0, -150), 340.0, 14.0, true),
      (const Offset(170, 0), 14.0, 300.0, true),
      (const Offset(-170, 0), 14.0, 300.0, true),
      // Inner angled box (blocker, not reflective)
      (const Offset(60, 40), 30.0, 30.0, false),
      (const Offset(-80, -60), 30.0, 30.0, false),
    ];
    for (final (pos, w, h, reflective) in walls) {
      _spawnWallBox(
        position: pos,
        width: w,
        height: h,
        color: reflective ? const Color(0xFF053344) : const Color(0xFF1A2A3A),
        strokeColor: reflective
            ? const Color(0xFF00BCD4)
            : const Color(0xFF37474F),
        isReflective: reflective,
        reflectivity: 0.85,
      );
    }

    // Player source
    _spawnCircleEntity(
      position: const Offset(-80, 40),
      radius: 9,
      fillColor: const Color(0xFF29B6F6),
      strokeColor: Colors.white,
      strokeWidth: 2,
      tag: 'player',
      layer: 10,
    );

    _statusMessage =
        'Rays bounce off cyan walls — click to fire a reflection ray';
    _buildReflectShots();
  }

  void _buildReflectShots() {
    // Pre-drawn reflection shots at multiple angles to show off the API
    const origin = Offset(-80, 40);
    final angles = [30.0, 60.0, 100.0, 140.0, 200.0];
    for (final deg in angles) {
      final rad = deg * math.pi / 180;
      final dir = Offset(math.cos(rad), math.sin(rad));
      final ray = Ray(origin: origin, direction: dir, maxDistance: 600.0);
      final hits = _raycastSystem.castRayAll(ray);
      if (hits.isEmpty) {
        _spawnRayLine(
          origin,
          ray.at(ray.maxDistance),
          color: const Color(0xFF29B6F6),
        );
      } else {
        Offset prev = origin;
        for (final hit in hits) {
          _spawnRayLine(prev, hit.point, color: const Color(0xFF29B6F6));
          prev = hit.point;
        }
        _spawnRayLine(prev, hits.last.point, color: const Color(0x4029B6F6));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Ray Tracer demo
  // ─────────────────────────────────────────────────────────────────────────

  void _buildTracer() {
    _spawnBackground();

    // Reflective chamber
    for (final (pos, w, h) in [
      (const Offset(0, 160), 360.0, 12.0),
      (const Offset(0, -160), 360.0, 12.0),
      (const Offset(180, 0), 12.0, 320.0),
      (const Offset(-180, 0), 12.0, 320.0),
    ]) {
      _spawnWallBox(
        position: pos,
        width: w,
        height: h,
        color: const Color(0xFF1A0A2E),
        strokeColor: const Color(0xFFAB47BC),
        isReflective: true,
        reflectivity: 0.75,
      );
    }

    // Inner obstacles (reflective)
    for (final pos in [
      const Offset(60, 60),
      const Offset(-70, -50),
      const Offset(100, -80),
    ]) {
      _spawnCircleEntity(
        position: pos,
        radius: 18,
        fillColor: const Color(0xFF1E0A33),
        strokeColor: const Color(0xFFCE93D8),
        strokeWidth: 2,
        isReflective: true,
        reflectivity: 0.7,
      );
    }

    _rayTracer = RayTracer(
      raycastSystem: _raycastSystem,
      maxBounces: 4,
      minReflectivity: 0.1,
    );

    _statusMessage = 'Click to fire a multi-bounce tracer ray';
  }

  void _fireTracer(Offset screenPos) {
    final camera = _engine.rendering.camera;
    camera.viewportSize = _viewportSize;
    final worldPos = camera.screenToWorld(screenPos);
    const origin = Offset(-120, -40);
    final dir = worldPos - origin;

    final ray = Ray(origin: origin, direction: dir, maxDistance: 800.0);
    final trace = _rayTracer!.trace(ray);

    final colors = [
      const Color(0xFFE040FB),
      const Color(0xFFBA68C8),
      const Color(0xFF9C27B0),
      const Color(0xFF7B1FA2),
      const Color(0xFF4A148C),
    ];

    for (int i = 0; i < trace.segments.length; i++) {
      final seg = trace.segments[i];
      final color = colors[i.clamp(0, colors.length - 1)];
      _spawnRayLine(seg.from, seg.to, color: color);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Scanner demo
  // ─────────────────────────────────────────────────────────────────────────

  void _buildScanner() {
    _spawnBackground();

    // Obstacles of various shapes
    for (final (pos, r) in [
      (const Offset(80, 0), 20.0),
      (const Offset(-100, 60), 15.0),
      (const Offset(40, -100), 12.0),
      (const Offset(-60, -80), 18.0),
      (const Offset(130, 90), 14.0),
      (const Offset(-140, -30), 16.0),
    ]) {
      _spawnCircleEntity(
        position: pos,
        radius: r,
        fillColor: const Color(0xFF1A2A3A),
        strokeColor: const Color(0xFF37474F),
        strokeWidth: 2,
        tag: 'obstacle',
      );
    }

    _spawnCircleEntity(
      position: Offset.zero,
      radius: 8,
      fillColor: const Color(0xFFFF7043),
      strokeColor: Colors.white,
      strokeWidth: 2,
      layer: 10,
    );

    _statusMessage =
        'Scanner sweeps $_scannerDegrees° steps — adjust step size';
  }

  void _tickScanner() {
    // Remove old scan rays
    final toKill = _world.entities
        .where((e) => e.hasComponent<_RayVisualComponent>())
        .toList();
    for (final e in toKill) {
      _world.destroyEntity(e);
    }

    const center = Offset.zero;
    const scanRadius = 220.0;
    final steps = 360 ~/ _scannerDegrees.clamp(1, 90);

    for (int i = 0; i < steps; i++) {
      final angle = (i * 2 * math.pi) / steps;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final ray = Ray(origin: center, direction: dir, maxDistance: scanRadius);
      final hit = _raycastSystem.castRay(ray);
      final end = hit?.point ?? ray.at(scanRadius);

      // Colour by fraction — close = warm, far = cool
      final fraction = (end - center).distance / scanRadius;
      final color = Color.lerp(
        const Color(0xFFFF7043),
        const Color(0x2229B6F6),
        fraction,
      )!;

      _spawnRayLine(center, end, color: color);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stats line
  // ─────────────────────────────────────────────────────────────────────────

  String get _statsLine {
    final entities = _world.entities.length;
    final cam = _engine.rendering.camera;
    final pos = cam.position;
    return 'entities $entities'
        '  pos (${pos.dx.toStringAsFixed(0)}, ${pos.dy.toStringAsFixed(0)})'
        '  zoom ${cam.zoom.toStringAsFixed(2)}';
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
                'RaycastSystem  ·  Ray  ·  RayTracer',
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
    return GestureDetector(
      onTapDown: (d) {
        if (_demo == _Demo.tracer) _fireTracer(d.localPosition);
      },
      child: GameCameraControls(
        camera: _engine.rendering.camera,
        enablePan: false,
        enablePinch: true,
        showZoomLevel: true,
        child: GameWidget(
          key: _gameWidgetKey,
          engine: _engine,
          showFPS: true,
          showDebug: false,
        ),
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
      case _Demo.shoot:
        return _buildShootControls();
      case _Demo.los:
        return _buildLosControls();
      case _Demo.reflect:
        return _buildReflectControls();
      case _Demo.tracer:
        return _buildTracerControls();
      case _Demo.scanner:
        return _buildScannerControls();
    }
  }

  Widget _buildShootControls() {
    return Row(
      children: [
        Text(
          'Destroyed: $_enemiesDestroyed / $_totalEnemies',
          style: const TextStyle(
            color: Color(0xFFFFCA28),
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 12),
        _actionButton(
          'Reset',
          const Color(0xFFFFCA28),
          () => _buildDemo(_Demo.shoot),
        ),
        const Spacer(),
        const Text(
          'castRay · filterTag: enemy',
          style: TextStyle(color: Colors.white24, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildLosControls() {
    return Row(
      children: [
        const Text(
          'White = clear  ·  Dim red = blocked',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const Spacer(),
        const Text(
          'hasLineOfSight · ignoreTag: player',
          style: TextStyle(color: Colors.white24, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildReflectControls() {
    return Row(
      children: [
        _actionButton('Refresh Rays', const Color(0xFF29B6F6), () {
          final toKill = _world.entities
              .where((e) => e.hasComponent<_RayVisualComponent>())
              .toList();
          for (final e in toKill) {
            _world.destroyEntity(e);
          }
          _buildReflectShots();
        }),
        const SizedBox(width: 12),
        const Text(
          'castRayAll · isReflective · reflectivity',
          style: TextStyle(color: Colors.white24, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildTracerControls() {
    return Row(
      children: [
        const Text(
          'Click viewport to fire a traced ray',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const Spacer(),
        const Text(
          'RayTracer · maxBounces: 4',
          style: TextStyle(color: Colors.white24, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildScannerControls() {
    return Row(
      children: [
        const Text(
          'Step:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 8),
        for (final deg in [5, 10, 20, 30, 45]) ...[
          _actionButton(
            '$deg°',
            const Color(0xFFFF7043),
            _scannerDegrees == deg
                ? null
                : () => setState(() => _scannerDegrees = deg),
          ),
          const SizedBox(width: 4),
        ],
        const Spacer(),
        const Text(
          'castRay · 360° sweep',
          style: TextStyle(color: Colors.white24, fontSize: 11),
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
                  'just_game_engine · RaycastSystem API',
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
