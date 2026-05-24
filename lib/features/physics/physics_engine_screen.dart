import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:just_game_engine/just_game_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  particleStorm,
  gravityWarp,
  bounciness,
  shapeMixer,
  bodyStack,
  sensors,
  queries,
  springChain,
  carPhysics;

  String get label => switch (this) {
    particleStorm => 'Particle Storm',
    gravityWarp => 'Gravity Warp',
    bounciness => 'Bounciness',
    shapeMixer => 'Shape Mixer',
    bodyStack => 'Body Stack',
    sensors => 'Sensors',
    queries => 'Queries',
    springChain => 'Spring Chain',
    carPhysics => 'Car Physics',
  };

  IconData get icon => switch (this) {
    particleStorm => Icons.bubble_chart,
    gravityWarp => Icons.swap_vert,
    bounciness => Icons.sports_tennis,
    shapeMixer => Icons.category,
    bodyStack => Icons.stacked_bar_chart,
    sensors => Icons.radar,
    queries => Icons.search,
    springChain => Icons.link,
    carPhysics => Icons.directions_car,
  };

  Color get accentColor => switch (this) {
    particleStorm => const Color(0xFF29B6F6),
    gravityWarp => const Color(0xFF66BB6A),
    bounciness => const Color(0xFFFF7043),
    shapeMixer => const Color(0xFFAB47BC),
    bodyStack => const Color(0xFFFFCA28),
    sensors => const Color(0xFFFFD54F),
    queries => const Color(0xFFEF9A9A),
    springChain => const Color(0xFFCE93D8),
    carPhysics => const Color(0xFF80CBC4),
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
      'Classic and new collision shapes in one sandbox: circles, rectangles, '
          'convex polygons, capsules, segments, chains, and rounded polygons. '
          'Mix them together to exercise SAT across the full shape set.',
    bodyStack =>
      'Stacked rigid bodies demonstrating impulse resolution and mass-weighted '
          'positional correction. Drop a heavy ball to topple the tower.',
    sensors =>
      'Sensor bodies detect overlaps without resolving collisions. '
          'The yellow zone fires SensorEnterEvent / SensorExitEvent as balls pass through.',
    queries =>
      'castRay · castRayAll · queryAABB · queryCircle — spatial queries against '
          'physics bodies. A rotating ray and a circle zone highlight hits each frame.',
    springChain =>
      'Distance joints with spring stiffness + damping model rope, chains, and '
          'elastic connectors. Weld joints rigidly lock two bodies into one rigid compound.',
    carPhysics =>
      'A 2-D car chassis connected to two wheels via WheelJoints (Box2D spring+motor) '
          'or PrismaticJoint+DistanceJoint fallback. Drive over the ramp with arrow keys or on-screen buttons.',
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
      '// Classic shapes\n'
          'PhysicsBody(shape: CircleShape(r), mass: 1);\n'
          'PhysicsBody(shape: RectangleShape(w, h), mass: 1);\n'
          'PhysicsBody(shape: PolygonShape(vertices), mass: 1);\n\n'
          '// New shapes in the same sandbox\n'
          'PhysicsBody(shape: CapsuleShape(...), mass: 1);\n'
          'PhysicsBody(shape: SegmentShape(p1, p2, thickness: 3), mass: 0);\n'
          'PhysicsBody(shape: ChainShape(points, thickness: 3), mass: 0);\n'
          'PhysicsBody(shape: RoundedPolygonShape.rect(...), mass: 1);',
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
    queries =>
      '// Ray cast against all physics bodies:\n'
          'final hit = engine.physics.castRay(Ray(\n'
          '  origin: Offset(0, 0),\n'
          '  direction: Offset(1, 0),\n'
          '  maxDistance: 500,\n'
          '));\n\n'
          '// All hits sorted nearest-first:\n'
          'final hits = engine.physics.castRayAll(ray);\n\n'
          '// Circle overlap query:\n'
          'final overlapping = engine.physics.queryCircle(\n'
          '  Offset(0, 0), 80.0);\n\n'
          '// AABB overlap query:\n'
          'final inRect = engine.physics.queryAABB(\n'
          '  Rect.fromCenter(center: Offset.zero, width: 160, height: 120));',
    springChain =>
      '// Stiff distance joint (rigid rope segment):\n'
          'engine.physics.addDistanceJoint(\n'
          '  bodyA, bodyB,\n'
          '  length: segmentLength,\n'
          ');\n\n'
          '// Soft spring (elastic connector):\n'
          'engine.physics.addDistanceJoint(\n'
          '  bodyA, bodyB,\n'
          '  length: restLength,\n'
          '  stiffness: 120.0, damping: 0.4,\n'
          ');\n\n'
          '// Weld — rigid compound body:\n'
          'engine.physics.addWeldJoint(bodyA, bodyB);',
    sensors =>
      '// Create a sensor body (no collision resolution)\n'
          'final sensor = PhysicsBody(\n'
          '  position: Vector2(0, 0),\n'
          '  shape: CircleShape(80),\n'
          '  mass: 0,\n'
          '  isSensor: true,   // ← key flag\n'
          ');\n'
          'engine.physics.addBody(sensor);\n\n'
          '// Poll sensor events each frame:\n'
          'engine.physics.pollSensorBeginEvents((a, b) {\n'
          '  // a or b is the sensor body\n'
          '});\n'
          'engine.physics.pollSensorEndEvents((a, b) { ... });',
    carPhysics =>
      '// Box2D WheelJoint — spring suspension + motor:\n'
          'final b2 = engine.physics as Box2DPhysicsEngine;\n'
          'final joint = b2.createWheelJoint(\n'
          '  chassis, wheel,\n'
          '  Offset(wheel.position.x, wheel.position.y),\n'
          '  const Offset(0, 1), // suspension axis (up)\n'
          ');\n'
          'joint?.setWheelSpring(45.0, 0.65); // stiffness, damping\n'
          'joint?.setWheelMotor(12.0, 250.0);  // speed rad/s, maxTorque\n\n'
          '// Dart fallback (no Box2D):\n'
          'engine.physics.addPrismaticJoint(chassis, wheel, Offset(0, 1));\n'
          'engine.physics.addDistanceJoint(chassis, wheel,\n'
          '  length: 14, stiffness: 45, damping: 0.65);',
  };
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
  bool _showColliderDebug = true;

  // ── Particle Storm settings ───────────────────────────────────────────────
  int _ballCount = 200;
  double _initialVelocity = 220;
  bool _gravityEnabled = true;

  // ── Sensor demo state ────────────────────────────────────────────────────
  PhysicsBody? _sensorBody;
  final List<String> _sensorLog = [];
  static const _kMaxSensorLog = 6;

  // ── Queries demo state ───────────────────────────────────────────────────
  RayBodyHit? _queryRayHit;
  int _queryOverlapCount = 0;
  double _queryRayAngle = 0.0; // auto-rotating ray angle in radians

  // ── Car Physics demo state ───────────────────────────────────────────────
  bool _carLeft = false;
  bool _carRight = false;
  bool _carBrake = false;
  PhysicsBody? _carChassis;
  PhysicsBody? _carFrontWheel;
  PhysicsBody? _carRearWheel;
  Box2DJoint? _carFrontJoint;
  Box2DJoint? _carRearJoint;
  bool _carBox2D = false;
  final FocusNode _focusNode = FocusNode();

  final math.Random _random = math.Random();
  Size _arenaSize = const Size(800, 500);

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    if (!_engine.isRunning) {
      if (_engine.isPaused) {
        _engine.resume();
      } else {
        _engine.start();
      }
    }
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buildDemo(_demo);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    _clearAll();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sensor event polling
  // ─────────────────────────────────────────────────────────────────────────

  void _pollSensorEvents() {
    _engine.physics.pollSensorBeginEvents((a, b) {
      final visitor = (a == _sensorBody) ? b : a;
      _sensorLog.insert(0, 'ENTER  body#${visitor.hashCode % 1000}');
      if (_sensorLog.length > _kMaxSensorLog) _sensorLog.removeLast();
    });
    _engine.physics.pollSensorEndEvents((a, b) {
      final visitor = (a == _sensorBody) ? b : a;
      _sensorLog.insert(0, 'EXIT   body#${visitor.hashCode % 1000}');
      if (_sensorLog.length > _kMaxSensorLog) _sensorLog.removeLast();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Queries demo update
  // ─────────────────────────────────────────────────────────────────────────

  void _updateQueries(Duration elapsed) {
    // Rotate the ray angle at 60°/s
    _queryRayAngle = (elapsed.inMicroseconds / 1_000_000.0) * (math.pi / 3.0);
    final dir = Offset(math.cos(_queryRayAngle), math.sin(_queryRayAngle));
    final ray = Ray(
      origin: Offset.zero,
      direction: dir,
      maxDistance: _halfW * 0.9,
    );
    _queryRayHit = _engine.physics.castRay(ray);
    final overlapping = _engine.physics.queryCircle(const Offset(0, 60), 60.0);
    _queryOverlapCount = overlapping.length;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tick
  // ─────────────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    // Prefer the unified GameWidget-driven game loop.
    // If the engine loop is not running (for example, another screen called
    // engine.stop()), run a local fallback step so this showcase stays live.
    if (!_engine.isRunning) {
      if (_lastTick == Duration.zero) {
        _lastTick = elapsed;
      } else {
        final dt = (elapsed - _lastTick).inMicroseconds / 1_000_000.0;
        _lastTick = elapsed;
        _engine.physics.update(dt);
        _world.update(dt);
      }
    } else {
      _lastTick = Duration.zero;
    }

    if (_demo == _Demo.sensors) _pollSensorEvents();
    if (_demo == _Demo.queries) _updateQueries(elapsed);
    if (_demo == _Demo.carPhysics) _updateCarMotor();
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

  void _addBody(PhysicsBody body) {
    _engine.physics.addBody(body);
  }

  void _clearAll() {
    final wasRunning = _engine.isRunning;
    if (wasRunning) {
      _engine.pause();
    }

    // ── Step 1: Destroy all ECS entities and systems
    _world.destroyAllEntities();
    _world.clearSystems();

    // ── Step 2: Clear rendering engine (removes all renderables, layers, effects)
    // This prevents cached renderables and post-process effects from previous
    // demos from affecting the new demo.
    _engine.rendering.clear();

    // ── Step 3: Remove all physics bodies from the current physics engine
    final bodies = List<PhysicsBody>.from(_engine.physics.bodies);
    for (final b in bodies) {
      _engine.physics.removeBody(b);
    }

    // ── Step 4: Explicitly reset physics state to defaults
    // Body removal in Step 3 already destroys every native Box2D body via
    // b2w_destroyBody, leaving the world empty. A full dispose+reinitialize
    // is NOT needed and actually causes a re-init failure on some platforms,
    // which silently switches the engine to the pure-Dart fallback and lets
    // base-class _bodies accumulate across demo switches (ghost collisions).
    // Ensures BOTH the Dart gravity vector AND the native Box2D world gravity
    // are zeroed. Must use setGravity() — gravity.setValues() only updates
    // the Dart Vector2 and does NOT propagate to the native simulation.
    _engine.physics.setGravity(0, 0);

    if (wasRunning) {
      _engine.resume();
    }
  }

  void _buildDemo(_Demo demo) {
    _demo = demo;
    _statusMessage = '';
    _refreshArenaSize();
    _clearAll();
    _engine.rendering.camera.reset();
    _engine.physics.setGravity(0, 98);

    _world.addSystem(PhysicsBridgeSystem());
    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));
    if (_showColliderDebug) {
      _world.addSystem(
        ColliderDebuggerSystem(
          camera: _engine.rendering.camera,
          includeStaticBodies: true,
          includeDynamicBodies: true,
        ),
      );
    }

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
      case _Demo.sensors:
        _sensorBody = null;
        _sensorLog.clear();
        _buildSensorsDemo();
      case _Demo.queries:
        _queryRayHit = null;
        _queryOverlapCount = 0;
        _buildQueriesDemo();
      case _Demo.springChain:
        _buildSpringChainDemo();
      case _Demo.carPhysics:
        _carLeft = false;
        _carRight = false;
        _carBrake = false;
        _carChassis = null;
        _carFrontWheel = null;
        _carRearWheel = null;
        _carFrontJoint = null;
        _carRearJoint = null;
        _carBox2D = false;
        _buildCarPhysicsDemo();
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
      _addBody(body);
      _world.createEntityWithComponents([
        PhysicsBodyRefComponent(body),
        TransformComponent(position: Vector3.fromOffset(w.pos)),
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
    _engine.physics.setGravity(0, _gravityEnabled ? 98 : 0);
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
      _addBody(body);
      _world.createEntityWithComponents([
        PhysicsBodyRefComponent(body),
        TransformComponent(position: Vector3.fromOffset(Offset(x, y))),
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
      _engine.physics.setGravity(0, enabled ? 98 : 0);
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
      _addBody(body);
      _world.createEntityWithComponents([
        PhysicsBodyRefComponent(body),
        TransformComponent(position: Vector3.fromOffset(Offset(x, y))),
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
    _engine.physics.setGravity(gx, gy);
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
    _engine.physics.setGravity(0, 120);
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
      _addBody(body);
      _world.createEntityWithComponents([
        PhysicsBodyRefComponent(body),
        TransformComponent(position: Vector3.fromOffset(w.pos)),
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
      _addBody(body);
      _world.createEntityWithComponents([
        PhysicsBodyRefComponent(body),
        TransformComponent(
          position: Vector3.fromOffset(Offset(x, -_halfH * 0.75)),
        ),
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
    for (int i = 0; i < 10; i++) {
      _addShape(_random.nextInt(3));
    }
    _addNewShape(0);
    _addNewShape(1);
    _addNewShape(2);
    _addNewShape(3);
    for (int i = 0; i < 4; i++) {
      _addNewShape(4);
    }
    _statusMessage = 'Classic + new shapes in one collision sandbox';
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
        _addBody(body);
        _world.createEntityWithComponents([
          PhysicsBodyRefComponent(body),
          TransformComponent(position: Vector3.fromOffset(Offset(x, y))),
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
        _addBody(body);
        _world.createEntityWithComponents([
          PhysicsBodyRefComponent(body),
          TransformComponent(position: Vector3.fromOffset(Offset(x, y))),
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
        _addBody(body);
        _world.createEntityWithComponents([
          PhysicsBodyRefComponent(body),
          TransformComponent(position: Vector3.fromOffset(Offset(x, y))),
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
    _engine.physics.setGravity(0, 150);
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
        _addBody(body);
        _world.createEntityWithComponents([
          PhysicsBodyRefComponent(body),
          TransformComponent(position: Vector3.fromOffset(Offset(x, y))),
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
    _addBody(body);
    _world.createEntityWithComponents([
      PhysicsBodyRefComponent(body),
      TransformComponent(position: Vector3.fromOffset(Offset(0, spawnY))),
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
  void _addNewShape(int type) {
    final hw = _halfW - 30.0;
    final hh = _halfH - 30.0;
    final x = (_random.nextDouble() * 2 - 1) * hw;
    final y = (_random.nextDouble() * 2 - 1) * (hh * 0.7) - hh * 0.1;
    final vx = (_random.nextDouble() * 2 - 1) * 100;
    final vy = (_random.nextDouble() * 2 - 1) * 100;
    final color = Color.lerp(
      const Color(0xFF26C6DA),
      const Color(0xFF66BB6A),
      _random.nextDouble(),
    )!;

    switch (type) {
      case 0: // Capsule
        const halfH = 18.0, r = 9.0;
        final body = PhysicsBody(
          position: Vector2(x, y),
          velocity: Vector2(vx, vy),
          shape: CapsuleShape(
            center1: const Offset(0, -halfH),
            center2: const Offset(0, halfH),
            radius: r,
          ),
          mass: 1.2,
          restitution: 0.6,
          friction: 0.1,
          drag: 0.008,
          useGravity: true,
        );
        _addBody(body);
        _world.createEntityWithComponents([
          PhysicsBodyRefComponent(body),
          TransformComponent(position: Vector3.fromOffset(Offset(x, y))),
          RenderableComponent(
            renderable: CustomRenderable(
              layer: 5,
              getBoundsCallback: () => Rect.fromCenter(
                center: Offset.zero,
                width: r * 2 + 4,
                height: halfH * 2 + r * 2 + 4,
              ),
              onRender: (canvas, _) {
                final paint = Paint()..color = color;
                canvas.drawCircle(const Offset(0, -halfH), r, paint);
                canvas.drawCircle(const Offset(0, halfH), r, paint);
                canvas.drawRect(
                  Rect.fromCenter(
                    center: Offset.zero,
                    width: r * 2,
                    height: halfH * 2,
                  ),
                  paint,
                );
                final stroke = Paint()
                  ..color = Colors.white.withValues(alpha: 0.35)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.2;
                canvas.drawCircle(const Offset(0, -halfH), r, stroke);
                canvas.drawCircle(const Offset(0, halfH), r, stroke);
              },
            ),
          ),
        ]);

      case 1: // Diagonal segment (static ramp)
        const p1 = Offset(-55, 0);
        const p2 = Offset(55, -25);
        const thickness = 3.0;
        final body = PhysicsBody(
          position: Vector2(x, y),
          shape: SegmentShape(p1, p2, thickness: thickness),
          mass: 0,
          restitution: 0.5,
          friction: 0.3,
        );
        _addBody(body);
        _world.createEntityWithComponents([
          PhysicsBodyRefComponent(body),
          TransformComponent(position: Vector3.fromOffset(Offset(x, y))),
          RenderableComponent(
            renderable: CustomRenderable(
              layer: 5,
              getBoundsCallback: () => const Rect.fromLTRB(-60, -35, 60, 10),
              onRender: (canvas, _) {
                canvas.drawLine(
                  p1,
                  p2,
                  Paint()
                    ..color = color
                    ..strokeWidth = thickness * 2
                    ..strokeCap = StrokeCap.round,
                );
              },
            ),
          ),
        ]);

      case 2: // Chain (wave terrain, static)
        final chainVerts = [
          const Offset(-70, 10),
          const Offset(-35, -20),
          const Offset(0, 10),
          const Offset(35, -20),
          const Offset(70, 10),
        ];
        final body = PhysicsBody(
          position: Vector2(x, y),
          shape: ChainShape(chainVerts, thickness: 3.0),
          mass: 0,
          restitution: 0.5,
          friction: 0.2,
        );
        _addBody(body);
        _world.createEntityWithComponents([
          PhysicsBodyRefComponent(body),
          TransformComponent(position: Vector3.fromOffset(Offset(x, y))),
          RenderableComponent(
            renderable: CustomRenderable(
              layer: 5,
              getBoundsCallback: () => const Rect.fromLTRB(-75, -25, 75, 15),
              onRender: (canvas, _) {
                final paint = Paint()
                  ..color = color
                  ..strokeWidth = 5
                  ..strokeCap = StrokeCap.round
                  ..strokeJoin = StrokeJoin.round
                  ..style = PaintingStyle.stroke;
                final path = Path()..moveTo(chainVerts[0].dx, chainVerts[0].dy);
                for (final v in chainVerts.skip(1)) {
                  path.lineTo(v.dx, v.dy);
                }
                canvas.drawPath(path, paint);
              },
            ),
          ),
        ]);

      case 3: // Rounded rectangle polygon
        const hw2 = 22.0, hh2 = 16.0, cr = 6.0;
        final body = PhysicsBody(
          position: Vector2(x, y),
          velocity: Vector2(vx, vy),
          shape: RoundedPolygonShape.rect(
            width: hw2 * 2,
            height: hh2 * 2,
            cornerRadius: cr,
          ),
          mass: 1.4,
          restitution: 0.65,
          friction: 0.15,
          drag: 0.01,
          useGravity: true,
        );
        _addBody(body);
        _world.createEntityWithComponents([
          PhysicsBodyRefComponent(body),
          TransformComponent(position: Vector3.fromOffset(Offset(x, y))),
          RenderableComponent(
            renderable: CustomRenderable(
              layer: 5,
              getBoundsCallback: () => Rect.fromCenter(
                center: Offset.zero,
                width: hw2 * 2 + 4,
                height: hh2 * 2 + 4,
              ),
              onRender: (canvas, _) {
                canvas.drawRRect(
                  RRect.fromRectAndRadius(
                    Rect.fromCenter(
                      center: Offset.zero,
                      width: hw2 * 2,
                      height: hh2 * 2,
                    ),
                    const Radius.circular(cr),
                  ),
                  Paint()..color = color,
                );
                canvas.drawRRect(
                  RRect.fromRectAndRadius(
                    Rect.fromCenter(
                      center: Offset.zero,
                      width: hw2 * 2,
                      height: hh2 * 2,
                    ),
                    const Radius.circular(cr),
                  ),
                  Paint()
                    ..color = Colors.white.withValues(alpha: 0.3)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.2,
                );
              },
            ),
          ),
        ]);

      case 4: // Small circle (classic, for cross-shape collisions)
        const r = 9.0;
        final body = PhysicsBody(
          position: Vector2(x, y),
          velocity: Vector2(vx, vy),
          shape: CircleShape(r),
          mass: 0.8,
          restitution: 0.7,
          friction: 0.05,
          drag: 0.005,
          useGravity: true,
        );
        _addBody(body);
        _world.createEntityWithComponents([
          PhysicsBodyRefComponent(body),
          TransformComponent(position: Vector3.fromOffset(Offset(x, y))),
          RenderableComponent(
            renderable: CircleRenderable(
              radius: r,
              fillColor: Colors.white.withValues(alpha: 0.55),
              strokeColor: Colors.white.withValues(alpha: 0.3),
              strokeWidth: 1,
              layer: 5,
            ),
          ),
        ]);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Sensors
  // ─────────────────────────────────────────────────────────────────────────

  void _buildSensorsDemo() {
    _engine.physics.setGravity(0, 120);
    _createWalls(restitution: 0.6);

    // Large circular sensor zone in the centre
    _sensorBody = PhysicsBody(
      position: Vector2.zero(),
      shape: CircleShape(80.0),
      mass: 0,
      isSensor: true,
      restitution: 0,
      friction: 0,
    );
    _addBody(_sensorBody!);
    _world.createEntityWithComponents([
      PhysicsBodyRefComponent(_sensorBody!),
      TransformComponent(position: Vector3.zero()),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 3,
          getBoundsCallback: () =>
              Rect.fromCircle(center: Offset.zero, radius: 82),
          onRender: (canvas, _) {
            canvas.drawCircle(
              Offset.zero,
              80,
              Paint()
                ..color = const Color(0xFFFFD54F).withValues(alpha: 0.15)
                ..style = PaintingStyle.fill,
            );
            canvas.drawCircle(
              Offset.zero,
              80,
              Paint()
                ..color = const Color(0xFFFFD54F).withValues(alpha: 0.7)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            );
          },
        ),
      ),
    ]);

    // Drop several balls into the scene
    for (int i = 0; i < 12; i++) {
      _addSensorBall();
    }
    _statusMessage = 'Sensor zone active — watch the event log';
  }

  void _addSensorBall() {
    const r = 11.0;
    final hw = _halfW - 20.0;
    final x = (_random.nextDouble() * 2 - 1) * hw;
    final spawnY = -_halfH + r + 10;
    final color = Color.lerp(
      const Color(0xFF29B6F6),
      const Color(0xFFAB47BC),
      _random.nextDouble(),
    )!;
    final body = PhysicsBody(
      position: Vector2(x, spawnY),
      velocity: Vector2((_random.nextDouble() * 2 - 1) * 80, 0),
      shape: CircleShape(r),
      mass: 1.0,
      restitution: 0.75,
      friction: 0.05,
      drag: 0.005,
      useGravity: true,
    );
    _addBody(body);
    _world.createEntityWithComponents([
      PhysicsBodyRefComponent(body),
      TransformComponent(position: Vector3.fromOffset(Offset(x, spawnY))),
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
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Queries
  // ─────────────────────────────────────────────────────────────────────────

  void _buildQueriesDemo() {
    _engine.physics.setGravity(0, 100);
    _createWalls(restitution: 0.7);
    // Mix of bodies to query against
    for (int i = 0; i < 18; i++) {
      _addQueriesBody();
    }
    _statusMessage = 'Rotating ray + circle overlap zone active';
  }

  void _addQueriesBody() {
    final hw = _halfW - 20.0;
    final hh = _halfH - 20.0;
    final x = (_random.nextDouble() * 2 - 1) * hw;
    final y = (_random.nextDouble() * 2 - 1) * hh * 0.6;
    final vx = (_random.nextDouble() * 2 - 1) * 80;
    final vy = (_random.nextDouble() * 2 - 1) * 80;
    final r = 8.0 + _random.nextDouble() * 8;
    final body = PhysicsBody(
      position: Vector2(x, y),
      velocity: Vector2(vx, vy),
      shape: CircleShape(r),
      mass: 1.0,
      restitution: 0.6,
      friction: 0.05,
      drag: 0.005,
      useGravity: true,
    );
    _addBody(body);
    _world.createEntityWithComponents([
      PhysicsBodyRefComponent(body),
      TransformComponent(position: Vector3.fromOffset(Offset(x, y))),
      RenderableComponent(
        renderable: CircleRenderable(
          radius: r,
          fillColor: const Color(0xFFEF9A9A).withValues(alpha: 0.7),
          strokeColor: Colors.white.withValues(alpha: 0.3),
          strokeWidth: 1,
          layer: 5,
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Spring Chain (distance + weld joints)
  // ─────────────────────────────────────────────────────────────────────────

  void _buildSpringChainDemo() {
    _engine.physics.setGravity(0, 180);

    // ── Spring rope: 8 bodies connected by soft distance joints ──
    const ropeN = 8;
    const ropeSegLen = 40.0;
    final ropeX = -_halfW * 0.35;
    final ropeStartY = -_halfH * 0.55;

    // Static hook
    final hook = PhysicsBody(
      position: Vector2(ropeX, ropeStartY),
      shape: CircleShape(6),
      mass: 0,
    );
    _addBody(hook);
    _world.createEntityWithComponents([
      PhysicsBodyRefComponent(hook),
      TransformComponent(position: Vector3(ropeX, ropeStartY, 0)),
      RenderableComponent(
        renderable: CircleRenderable(
          radius: 6,
          fillColor: const Color(0xFFCE93D8),
          strokeColor: Colors.white54,
          strokeWidth: 1,
          layer: 8,
        ),
      ),
    ]);

    PhysicsBody prev = hook;
    for (int i = 0; i < ropeN; i++) {
      final y = ropeStartY + (i + 1) * ropeSegLen;
      final r = 7.0 + (i % 2) * 3.0;
      final bob = PhysicsBody(
        position: Vector2(ropeX, y),
        shape: CircleShape(r),
        mass: 1.0,
        restitution: 0.5,
        friction: 0.05,
        drag: 0.008,
        useGravity: true,
      );
      _addBody(bob);
      _world.createEntityWithComponents([
        PhysicsBodyRefComponent(bob),
        TransformComponent(position: Vector3(ropeX, y, 0)),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: r,
            fillColor: Color.lerp(
              const Color(0xFFCE93D8),
              const Color(0xFF7986CB),
              i / ropeN,
            )!,
            strokeColor: Colors.white.withValues(alpha: 0.3),
            strokeWidth: 1,
            layer: 5,
          ),
        ),
      ]);
      // Soft spring distance joint
      _engine.physics.addDistanceJoint(
        prev,
        bob,
        length: ropeSegLen,
        stiffness: 80.0,
        damping: 0.25,
      );
      prev = bob;
    }

    // Give the rope a push
    prev.velocity.x = 120;

    // ── Weld chain: a rigid beam of 4 boxes weld-joined ──
    const weldN = 4;
    const boxW = 36.0, boxH = 18.0;
    final weldX = _halfW * 0.25;
    final weldY = -_halfH * 0.1;

    PhysicsBody? prevWeld;
    for (int i = 0; i < weldN; i++) {
      final x = weldX + i * (boxW + 2);
      final body = PhysicsBody(
        position: Vector2(x, weldY),
        shape: RectangleShape(boxW, boxH),
        mass: i == 0 ? 0 : 1.5, // first is static anchor
        restitution: 0.3,
        friction: 0.2,
        drag: 0.01,
        useGravity: i > 0,
      );
      _addBody(body);
      _world.createEntityWithComponents([
        PhysicsBodyRefComponent(body),
        TransformComponent(position: Vector3(x, weldY, 0)),
        RenderableComponent(
          renderable: RectangleRenderable(
            size: const Size(boxW, boxH),
            fillColor: const Color(0xFFFFB74D).withValues(alpha: 0.9),
            strokeColor: Colors.white.withValues(alpha: 0.3),
            strokeWidth: 1,
            layer: 5,
          ),
        ),
      ]);
      if (prevWeld != null) {
        _engine.physics.addWeldJoint(prevWeld, body);
      }
      prevWeld = body;
    }

    _statusMessage =
        'Left: spring rope (distance joints)   Right: rigid beam (weld joints)';
  }

  Widget _buildSpringChainControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _actionButton('Shake', const Color(0xFFCE93D8), () {
          // Impulse on all dynamic bodies
          for (final body in _engine.physics.bodies) {
            if (body.mass > 0 && body.isAwake) {
              body.applyImpulse(
                Vector2((_random.nextDouble() * 2 - 1) * 60, -40),
              );
            }
          }
        }),
        _actionButton(
          'Reset',
          const Color(0xFF78909C),
          () => _buildDemo(_demo),
        ),
        const Text(
          'spring rope  ·  weld beam',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Car Physics (wheel joints + curved platform)
  // ─────────────────────────────────────────────────────────────────────────

  void _buildCarPhysicsDemo() {
    _engine.physics.setGravity(0, 300);

    final groundY = _halfH * 0.30;
    final rampTopY = -_halfH * 0.08;

    // ── Track: flat start → ramp up → flat peak → ramp down → flat end ──
    final trackPoints = [
      Offset(-_halfW * 0.9, groundY),
      Offset(-_halfW * 0.4, groundY),
      Offset(-_halfW * 0.05, rampTopY),
      Offset(_halfW * 0.15, rampTopY),
      Offset(_halfW * 0.5, groundY),
      Offset(_halfW * 0.9, groundY),
    ];
    final track = PhysicsBody(
      position: Vector2(0, 0),
      shape: ChainShape(trackPoints, thickness: 4.0),
      mass: 0,
      friction: 0.75,
      restitution: 0.05,
    );
    _addBody(track);
    _world.createEntityWithComponents([
      PhysicsBodyRefComponent(track),
      TransformComponent(position: Vector3(0, 0, 0)),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 3,
          getBoundsCallback: () =>
              Rect.fromLTRB(-_halfW, rampTopY - 10, _halfW, groundY + 10),
          onRender: (canvas, _) {
            final paint = Paint()
              ..color = const Color(0xFF546E7A)
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke;
            final path = Path()..moveTo(trackPoints[0].dx, trackPoints[0].dy);
            for (final v in trackPoints.skip(1)) {
              path.lineTo(v.dx, v.dy);
            }
            canvas.drawPath(path, paint);
          },
        ),
      ),
    ]);

    // ── End-stop walls so the car can't slide off either edge ──
    for (final x in [-_halfW * 0.92, _halfW * 0.92]) {
      final wall = PhysicsBody(
        position: Vector2(x, groundY - 20),
        shape: RectangleShape(8, 40),
        mass: 0,
        friction: 0.5,
        restitution: 0.1,
      );
      _addBody(wall);
      _world.createEntityWithComponents([
        PhysicsBodyRefComponent(wall),
        TransformComponent(position: Vector3(x, groundY - 20, 0)),
        RenderableComponent(
          renderable: RectangleRenderable(
            size: const Size(8, 40),
            fillColor: const Color(0xFF37474F),
            strokeColor: Colors.white24,
            strokeWidth: 1,
            layer: 3,
          ),
        ),
      ]);
    }

    // ── Car chassis ──
    const chassisW = 64.0, chassisH = 18.0;
    const carCollisionGroup = -7;
    final chassisX = -_halfW * 0.65;
    final chassisY = groundY - 40.0;
    final chassis = PhysicsBody(
      position: Vector2(chassisX, chassisY),
      shape: RectangleShape(chassisW, chassisH),
      mass: 6.0,
      friction: 0.3,
      restitution: 0.05,
      drag: 0.02,
      useGravity: true,
      groupIndex: carCollisionGroup,
    );
    _addBody(chassis);
    _world.createEntityWithComponents([
      PhysicsBodyRefComponent(chassis),
      TransformComponent(position: Vector3(chassisX, chassisY, 0)),
      RenderableComponent(
        renderable: RectangleRenderable(
          size: const Size(chassisW, chassisH),
          fillColor: const Color(0xFF80CBC4),
          strokeColor: Colors.white.withValues(alpha: 0.4),
          strokeWidth: 1.5,
          layer: 6,
        ),
      ),
    ]);
    _carChassis = chassis;

    // ── Wheels ──
    const wheelR = 12.0;
    const wheelOffsetX = 22.0;
    const wheelOffsetY = chassisH / 2 + wheelR + 3.0;

    PhysicsBody makeWheel(double wx, double wy) {
      final wheel = PhysicsBody(
        position: Vector2(wx, wy),
        shape: CircleShape(wheelR),
        mass: 1.2,
        friction: 0.9,
        restitution: 0.05,
        drag: 0.01,
        useGravity: true,
        groupIndex: carCollisionGroup,
      );
      _addBody(wheel);
      _world.createEntityWithComponents([
        PhysicsBodyRefComponent(wheel),
        TransformComponent(position: Vector3(wx, wy, 0)),
        RenderableComponent(
          renderable: CircleRenderable(
            radius: wheelR,
            fillColor: const Color(0xFF37474F),
            strokeColor: Colors.white.withValues(alpha: 0.35),
            strokeWidth: 2,
            layer: 7,
          ),
        ),
      ]);
      return wheel;
    }

    final rearWheel = makeWheel(
      chassisX - wheelOffsetX,
      chassisY + wheelOffsetY,
    );
    final frontWheel = makeWheel(
      chassisX + wheelOffsetX,
      chassisY + wheelOffsetY,
    );

    _carRearWheel = rearWheel;
    _carFrontWheel = frontWheel;

    // ── Joints: Box2D WheelJoint if native, else rigid fallback ──
    _carBox2D = _engine.physics.stats['backend'] == 'box2d_v3';
    if (_carBox2D) {
      final b2 = _engine.physics as Box2DPhysicsEngine;
      _carRearJoint = b2.createWheelJoint(
        chassis,
        rearWheel,
        Offset(rearWheel.position.x, rearWheel.position.y),
        const Offset(0, 1),
      );
      _carRearJoint?.setWheelSpring(45.0, 0.65);
      _carFrontJoint = b2.createWheelJoint(
        chassis,
        frontWheel,
        Offset(frontWheel.position.x, frontWheel.position.y),
        const Offset(0, 1),
      );
      _carFrontJoint?.setWheelSpring(45.0, 0.65);
    } else {
      _engine.physics.addWeldJoint(chassis, rearWheel);
      _engine.physics.addWeldJoint(chassis, frontWheel);
    }

    _statusMessage =
        '← → arrow keys or buttons to drive  ·  Space / Brake to stop'
        '  ·  Box2D: $_carBox2D';
  }

  void _updateCarMotor() {
    const motorSpeed = 12.0;
    const maxTorque = 250.0;

    if (_carBox2D) {
      final speed = _carLeft
          ? -motorSpeed
          : _carRight
          ? motorSpeed
          : 0.0;
      final enabled = _carLeft || _carRight || _carBrake;
      final torque = _carBrake ? maxTorque * 3 : maxTorque;
      _carFrontJoint?.setWheelMotor(speed, torque, enable: enabled);
      _carRearJoint?.setWheelMotor(speed, torque, enable: enabled);
    } else {
      final chassis = _carChassis;
      if (chassis == null) return;
      const driveForce = 2200.0;
      const maxSpeed = 240.0;
      if (_carLeft) {
        if (chassis.velocity.x > -maxSpeed) {
          chassis.applyForce(Vector2(-driveForce, 0));
        }
      } else if (_carRight) {
        if (chassis.velocity.x < maxSpeed) {
          chassis.applyForce(Vector2(driveForce, 0));
        }
      }
      if (_carBrake) {
        chassis.velocity.x *= 0.80;
        chassis.angularVelocity *= 0.75;
        final fw = _carFrontWheel;
        final rw = _carRearWheel;
        if (fw != null) fw.angularVelocity *= 0.80;
        if (rw != null) rw.angularVelocity *= 0.80;
      }
    }
  }

  Widget _buildCarPhysicsControls() {
    const accent = Color(0xFF80CBC4);

    Widget driveButton({
      required IconData icon,
      required String label,
      required VoidCallback onDown,
      required VoidCallback onUp,
    }) {
      return Listener(
        onPointerDown: (_) {
          setState(onDown);
          _focusNode.requestFocus();
        },
        onPointerUp: (_) => setState(onUp),
        onPointerCancel: (_) => setState(onUp),
        child: ElevatedButton.icon(
          onPressed: () {},
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 11)),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent.withValues(alpha: 0.18),
            foregroundColor: accent,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    return Row(
      children: [
        driveButton(
          icon: Icons.arrow_back,
          label: 'Left',
          onDown: () => _carLeft = true,
          onUp: () => _carLeft = false,
        ),
        const SizedBox(width: 6),
        Listener(
          onPointerDown: (_) {
            setState(() => _carBrake = true);
            _focusNode.requestFocus();
          },
          onPointerUp: (_) => setState(() => _carBrake = false),
          onPointerCancel: (_) => setState(() => _carBrake = false),
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('Brake', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.18),
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(width: 6),
        driveButton(
          icon: Icons.arrow_forward,
          label: 'Right',
          onDown: () => _carRight = true,
          onUp: () => _carRight = false,
        ),
        const Spacer(),
        _actionButton('Reset', accent, () => _buildDemo(_demo)),
        const SizedBox(width: 10),
        const Text(
          'Arrow keys also work',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
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
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, event) {
        if (_demo != _Demo.carPhysics) return KeyEventResult.ignored;
        final down = event is KeyDownEvent;
        final up = event is KeyUpEvent;
        if (!down && !up) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.arrowLeft:
            setState(() {
              _carLeft = down;
              if (down) _carRight = false;
            });
          case LogicalKeyboardKey.arrowRight:
            setState(() {
              _carRight = down;
              if (down) _carLeft = false;
            });
          case LogicalKeyboardKey.space:
            setState(() => _carBrake = down);
          default:
            return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildCanvas()),
          _buildDemoSelector(),
          _buildControlPanel(),
          _buildCodeCard(),
          const SizedBox(height: 10),
        ],
      ),
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
              if (_demo == _Demo.carPhysics) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB74D).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFFFB74D).withValues(alpha: 0.55),
                    ),
                  ),
                  child: const Text(
                    'EXPERIMENTAL',
                    style: TextStyle(
                      color: Color(0xFFFFCC80),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
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
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Collider Debug',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(width: 6),
              Switch(
                value: _showColliderDebug,
                onChanged: (v) {
                  setState(() {
                    _showColliderDebug = v;
                  });
                  _buildDemo(_demo);
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
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
        showDebug: true,
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
              separatorBuilder: (_, _) => const SizedBox(width: 6),
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
      case _Demo.sensors:
        return _buildSensorsControls();
      case _Demo.queries:
        return _buildQueriesControls();
      case _Demo.springChain:
        return _buildSpringChainControls();
      case _Demo.carPhysics:
        return _buildCarPhysicsControls();
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
        _actionButton(
          '+ Capsule',
          const Color(0xFF26C6DA),
          () => setState(() => _addNewShape(0)),
        ),
        _actionButton(
          '+ Segment',
          const Color(0xFF26C6DA),
          () => setState(() => _addNewShape(1)),
        ),
        _actionButton(
          '+ Chain',
          const Color(0xFF26C6DA),
          () => setState(() => _addNewShape(2)),
        ),
        _actionButton(
          '+ Rounded',
          const Color(0xFF26C6DA),
          () => setState(() => _addNewShape(3)),
        ),
        _actionButton(
          '+ Ball',
          const Color(0xFF26C6DA),
          () => setState(() => _addNewShape(4)),
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

  Widget _buildSensorsControls() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionButton(
              '+ Ball',
              const Color(0xFFFFD54F),
              () => setState(_addSensorBall),
            ),
            const SizedBox(height: 4),
            _actionButton('Reset', const Color(0xFF78909C), () {
              _sensorLog.clear();
              _buildDemo(_demo);
            }),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF090F1A),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
              ),
            ),
            child: _sensorLog.isEmpty
                ? const Text(
                    'sensor events will appear here…',
                    style: TextStyle(color: Colors.white30, fontSize: 10),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _sensorLog
                        .map(
                          (e) => Text(
                            e,
                            style: TextStyle(
                              color: e.startsWith('ENTER')
                                  ? const Color(0xFF66BB6A)
                                  : const Color(0xFFFF7043),
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildQueriesControls() {
    final hit = _queryRayHit;
    return Row(
      children: [
        _actionButton(
          '+ Body',
          const Color(0xFFEF9A9A),
          () => setState(_addQueriesBody),
        ),
        const SizedBox(width: 8),
        _actionButton(
          'Reset',
          const Color(0xFF78909C),
          () => _buildDemo(_demo),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hit == null
                    ? 'ray: no hit'
                    : 'ray hit @ (${hit.point.dx.toStringAsFixed(1)}, '
                          '${hit.point.dy.toStringAsFixed(1)})  '
                          'd=${hit.distance.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Color(0xFFEF9A9A),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'circle query ∩ $_queryOverlapCount bodies',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
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
