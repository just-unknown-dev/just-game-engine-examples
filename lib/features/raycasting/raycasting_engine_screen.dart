import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/widgets.dart';

import '../../core/engine/demo_engine.dart';

// -----------------------------------------------------------------------------
// Demo mode
// -----------------------------------------------------------------------------

enum _Demo {
  shoot,
  los,
  layers,
  shapes,
  scanner,
  reflect,
  tracer;

  /// Whether the demo queries physics bodies (`Physics2DQueries`) rather
  /// than `RaycastSystem`'s analytic colliders.
  bool get usesPhysics => switch (this) {
    reflect || tracer => false,
    _ => true,
  };

  String get label => switch (this) {
    shoot => 'Shoot',
    los => 'Line of Sight',
    layers => 'Layer Mask',
    shapes => 'Shape Queries',
    scanner => 'Scanner',
    reflect => 'Reflection',
    tracer => 'Ray Tracer',
  };

  IconData get icon => switch (this) {
    shoot => Icons.gps_fixed,
    los => Icons.visibility,
    layers => Icons.filter_list,
    shapes => Icons.bubble_chart,
    scanner => Icons.radar,
    reflect => Icons.flip,
    tracer => Icons.scatter_plot,
  };

  Color get accentColor => switch (this) {
    shoot => const Color(0xFFFFCA28),
    los => const Color(0xFF66BB6A),
    layers => const Color(0xFF26C6DA),
    shapes => const Color(0xFFEC407A),
    scanner => const Color(0xFFFF7043),
    reflect => const Color(0xFF29B6F6),
    tracer => const Color(0xFFAB47BC),
  };

  String get description => switch (this) {
    shoot =>
      'Physics2DQueries.raycast against RigidBody2D/Collider2D bodies. Aim '
          'with the pointer, click to fire from the player (green): '
          'ignore: player looks through the shooter, the hit is a PhysicsHit2D '
          'whose entity is tagged "enemy" — or a wall. RayRenderable draws the shot.',
    los =>
      'The eye (pointer) checks line of sight to every target with '
          'raycast(layerMask: walls). Targets are sensors, which queries skip '
          'unless includeSensors: true — so only walls can block a sight line.',
    layers =>
      'Each body sits on one of 16 layers (RigidBody2D.layer; a bare '
          'Collider2D is layer 0). raycastAll returns every hit along the ray, '
          'nearest first, filtered by layerMask — toggle which layers it sees.',
    shapes =>
      'circleCast sweeps a ball toward the pointer and stops where it would '
          'touch; overlapCircle (around the pointer) and overlapBox (the '
          'dashed zone) list the entities whose bodies are inside. Drones are '
          'kinematic bodies moved through their transforms.',
    scanner =>
      'A 360° radial scanner casts a Physics2DQueries.raycast every N° from '
          'the centre, each frame, against static and moving bodies; the hit '
          'ring is coloured by distance.',
    reflect =>
      'RaycastSystem still casts analytic rays against RaycastColliderComponents '
          '(no physics bodies). The beam toward the pointer bounces off cyan '
          'walls with r = d − 2(d·n)n, losing energy by each reflectivity.',
    tracer =>
      'RayTracer fires up to 4 bounces per ray through RaycastSystem. Click to '
          'launch a tracer shot; each segment is a fading RayRenderable entity.',
  };

  String get codeSnippet => switch (this) {
    shoot =>
      'final queries = Physics2DQueries(\n'
          '  engine.physics,\n'
          '  world.getSystem<PhysicsSystem>()!, // DefaultSystem.physics\n'
          ');\n\n'
          '// An enemy: a static circle body on layer 2, tagged.\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(position: Vector3(90, 0, 0)),\n'
          '  RigidBody2D(bodyType: BodyType.static, layer: 2),\n'
          '  Collider2D(shape: ColliderShape2D.circle, radius: 7),\n'
          "  TagComponent.of(['enemy']),\n"
          ']);\n\n'
          'final PhysicsHit2D? hit = queries.raycast(\n'
          '  playerPos, aim - playerPos,\n'
          '  maxDistance: 800,\n'
          '  ignore: player, // look through the shooter\n'
          ');\n'
          "if (hit?.entity?.hasTag('enemy') ?? false) {\n"
          '  world.destroyEntity(hit!.entity!); // its body goes too\n'
          '}',
    los =>
      '// Targets are sensors: queries skip them by default.\n'
          'RigidBody2D(bodyType: BodyType.static, isSensor: true, layer: 3)\n\n'
          "for (final target in world.allTagged('target')) {\n"
          '  final to = target.getComponent<TransformComponent>()!\n'
          '      .position.toOffset();\n'
          '  final hit = queries.raycast(\n'
          '    eye, to - eye,\n'
          '    maxDistance: (to - eye).distance,\n'
          '    layerMask: 1 << 0, // walls only\n'
          '  );\n'
          '  final visible = hit == null;\n'
          '}',
    layers =>
      '// One layer per body (0..15); a mask has bit n for layer n.\n'
          'Collider2D(size: Vector2(20, 160))     // wall: layer 0\n'
          'RigidBody2D(bodyType: BodyType.static, layer: 1) // glass\n'
          'RigidBody2D(bodyType: BodyType.static, layer: 2) // crate\n\n'
          'final hits = queries.raycastAll(\n'
          '  origin, aim - origin,\n'
          '  maxDistance: 900,\n'
          '  layerMask: (1 << 0) | (1 << 2), // walls + crates\n'
          ');\n'
          'for (final PhysicsHit2D h in hits) {\n'
          '  // nearest first: h.entity, h.point, h.normal,\n'
          '  // h.distance, h.fraction\n'
          '}',
    shapes =>
      '// Where would an 18-unit ball moving toward the aim stop?\n'
          'final hit = queries.circleCast(\n'
          '  origin, 18, aim - origin,\n'
          '  maxDistance: 600,\n'
          ');\n'
          'final stop = origin + dir * (hit?.distance ?? 600);\n\n'
          '// Who is inside a circle / a box right now?\n'
          'final List<Entity> near = queries.overlapCircle(aim, 70);\n'
          'final inZone = queries.overlapBox(\n'
          '  const Rect.fromLTWH(60, -190, 220, 120),\n'
          ');\n\n'
          '// A drone: kinematic, moved through its transform.\n'
          'RigidBody2D(bodyType: BodyType.kinematic, layer: 2)',
    scanner =>
      '// Radial sweep with physics queries:\n'
          'for (var i = 0; i < steps; i++) {\n'
          '  final a = i * 2 * math.pi / steps;\n'
          '  final dir = Offset(math.cos(a), math.sin(a));\n'
          '  final hit = queries.raycast(\n'
          '    center, dir,\n'
          '    maxDistance: scanRadius,\n'
          '  );\n'
          '  final end = hit?.point ?? center + dir * scanRadius;\n'
          '  // Draw a ray from center to end\n'
          '}',
    reflect =>
      '// RaycastSystem: analytic rays, no physics bodies.\n'
          'RaycastColliderComponent(\n'
          '  width: 340, height: 14,\n'
          '  isReflective: true,\n'
          '  reflectivity: 0.85, // energy kept per bounce\n'
          ');\n\n'
          'var ray = Ray(origin: src, direction: aim - src,\n'
          '    maxDistance: 900);\n'
          'for (var b = 0; b < 6; b++) {\n'
          '  final hit = raycastSystem.castRay(ray);\n'
          '  if (hit == null) break;\n'
          '  final d = ray.direction, n = hit.normal;\n'
          '  // r = d - 2(d·n)n\n'
          '  final r = d - n * (2 * (d.dx * n.dx + d.dy * n.dy));\n'
          '  ray = Ray(origin: hit.point + r, direction: r,\n'
          '      maxDistance: 900);\n'
          '}',
    tracer =>
      'final tracer = RayTracer(\n'
          '  raycastSystem: raycastSystem,\n'
          '  maxBounces: 4,\n'
          '  minReflectivity: 0.1,\n'
          ');\n\n'
          'final trace = tracer.trace(\n'
          '  Ray(origin: o, direction: aim - o, maxDistance: 800),\n'
          ');\n'
          'for (final seg in trace.segments) {\n'
          '  world.createEntityWithComponents([\n'
          '    TransformComponent(),\n'
          '    RenderableComponent(\n'
          '      syncTransform: false,\n'
          '      renderable: RayRenderable(\n'
          '        start: seg.from, end: seg.to, lifetime: 1.2),\n'
          '    ),\n'
          '  ]);\n'
          '}\n'
          '// RayRenderable.update(dt) fades it; isExpired when done.',
  };
}

// -----------------------------------------------------------------------------
// ECS helpers
// -----------------------------------------------------------------------------

/// Marks a fading [RayRenderable] for [_RayFadeSystem].
class _RayFadeComponent extends Component {}

/// Advances every fading ray and destroys it once it has faded out.
class _RayFadeSystem extends System {
  @override
  List<Type> get requiredComponents => const [
    RenderableComponent,
    _RayFadeComponent,
  ];

  @override
  void update(double dt) {
    final expired = <Entity>[];
    forEach((entity) {
      final ray = entity.getComponent<RenderableComponent>()!.renderable;
      if (ray is! RayRenderable) return;
      ray.update(dt);
      if (ray.isExpired) expired.add(entity);
    });
    for (final entity in expired) {
      world.destroyEntity(entity);
    }
  }
}

/// A drone flying a Lissajous path; its kinematic body follows the
/// transform.
class _DroneComponent extends Component {
  _DroneComponent({
    required this.center,
    required this.radiusX,
    required this.radiusY,
    required this.speed,
    this.phase = 0,
  });
  final Offset center;
  final double radiusX;
  final double radiusY;
  final double speed;
  final double phase;
  double time = 0;
}

class _DroneSystem extends System {
  @override
  List<Type> get requiredComponents => const [
    TransformComponent,
    _DroneComponent,
  ];

  // Above PhysicsSystem (90): the bodies follow this step's transforms.
  @override
  int get priority => 95;

  @override
  void update(double dt) {
    forEach((entity) {
      final d = entity.getComponent<_DroneComponent>()!;
      d.time += dt;
      final a = d.phase + d.time * d.speed;
      entity.getComponent<TransformComponent>()!.position.setValues(
        d.center.dx + math.cos(a) * d.radiusX,
        d.center.dy + math.sin(a * 2) * d.radiusY,
        0,
      );
    });
  }
}

/// Runs [onFrame] once per rendered frame — after the frame's fixed
/// updates, before it is drawn — so the overlay shows this frame's queries.
class _FrameHook extends System implements FrameSystem {
  _FrameHook(this.onFrame);

  final void Function(double dt) onFrame;

  @override
  List<Type> get requiredComponents => const [];

  @override
  void frame(double deltaTime, double alpha) => onFrame(deltaTime);
}

/// What the current frame's queries found, drawn over the world.
class _Overlay {
  final List<(Offset, Offset, Color, double)> lines = [];
  final List<(Offset, double, Color, double)> rings = [];
  final List<(Offset, double, Color)> dots = [];
  final List<(Rect, Color)> boxes = [];
  final List<(Offset, String, Color)> labels = [];

  void clear() {
    lines.clear();
    rings.clear();
    dots.clear();
    boxes.clear();
    labels.clear();
  }

  void line(Offset a, Offset b, Color color, [double width = 1.5]) =>
      lines.add((a, b, color, width));

  void ring(Offset c, double r, Color color, [double width = 1.5]) =>
      rings.add((c, r, color, width));

  void dot(Offset c, Color color, [double r = 4]) => dots.add((c, r, color));

  /// A hit: a dot and its surface normal.
  void hit(Offset point, Offset normal, Color color, {double r = 4}) {
    dot(point, color, r);
    line(point, point + normal * 18, color.withValues(alpha: 0.8), 1.2);
  }

  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _fill = Paint();

  void paint(Canvas canvas) {
    for (final (rect, color) in boxes) {
      canvas.drawRect(rect, _fill..color = color.withValues(alpha: 0.08));
      canvas.drawRect(
        rect,
        _stroke
          ..color = color
          ..strokeWidth = 1.5,
      );
    }
    for (final (a, b, color, width) in lines) {
      canvas.drawLine(
        a,
        b,
        _stroke
          ..color = color
          ..strokeWidth = width,
      );
    }
    for (final (c, r, color, width) in rings) {
      canvas.drawCircle(
        c,
        r,
        _stroke
          ..color = color
          ..strokeWidth = width,
      );
    }
    for (final (c, r, color) in dots) {
      canvas.drawCircle(c, r, _fill..color = color);
    }
    for (final (at, text, color) in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, at);
      painter.dispose();
    }
  }
}

// -----------------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------------

class RaycastingEngineScreen extends StatefulWidget {
  const RaycastingEngineScreen({super.key});

  @override
  State<RaycastingEngineScreen> createState() => _RaycastingEngineScreenState();
}

class _RaycastingEngineScreenState extends State<RaycastingEngineScreen>
    with SingleTickerProviderStateMixin {
  // -- Engine --------------------------------------------------------------
  /// The app's shared, already running engine — never `Engine()`.
  late final Engine _engine = demoEngine;
  late final World _world = _engine.world;

  /// Refreshes the live stats only; the engine runs itself.
  late final Ticker _ticker;
  Duration _lastRefresh = Duration.zero;

  // -- Demo -----------------------------------------------------------------
  _Demo _demo = _Demo.shoot;
  String _statusMessage = '';

  // -- Queries --------------------------------------------------------------
  Physics2DQueries? _queries;
  RaycastSystem? _raycastSystem;
  RayTracer? _rayTracer;
  final _Overlay _overlay = _Overlay();
  int _queriesLastFrame = 0;

  // -- Pointer --------------------------------------------------------------
  /// Where the pointer is over the canvas, in canvas pixels; null when it
  /// is not over it (the aim then sweeps by itself).
  Offset? _pointer;

  // -- Shoot demo -----------------------------------------------------------
  Entity? _player;
  int _totalEnemies = 12;

  // -- LOS demo -------------------------------------------------------------
  int _visibleTargets = 0;

  // -- Layer demo -----------------------------------------------------------
  int _layerMask = (1 << _wallLayer) | (1 << _glassLayer) | (1 << _crateLayer);
  int _lastHitCount = 0;

  // -- Shape demo -----------------------------------------------------------
  int _nearCount = 0;
  int _zoneCount = 0;
  static const Rect _zone = Rect.fromLTWH(60, -190, 220, 120);

  // -- Scanner demo ---------------------------------------------------------
  int _scannerDegrees = 10;

  // -- Reflect demo ---------------------------------------------------------
  int _bounces = 0;

  // -- Layers ---------------------------------------------------------------
  static const int _wallLayer = 0;
  static const int _glassLayer = 1;
  static const int _crateLayer = 2;
  static const int _sensorLayer = 3;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buildDemo(_demo);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    // Destroys every entity (their bodies go with them), removes this
    // screen's systems and puts gravity back — the engine keeps running.
    DemoEngine.reset(_engine);
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (elapsed - _lastRefresh < const Duration(milliseconds: 100)) return;
    _lastRefresh = elapsed;
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------------------
  // Demo builder
  // -------------------------------------------------------------------------

  void _buildDemo(_Demo demo) {
    _demo = demo;
    _statusMessage = '';
    _rayTracer = null;
    _player = null;
    _overlay.clear();

    DemoEngine.reset(
      _engine,
      include: {
        DefaultSystem.rendering,
        if (demo.usesPhysics) DefaultSystem.physics,
      },
    );
    // Top-down: nothing falls.
    _engine.physics.setGravity(0, 0);

    final physicsSystem = _world.getSystem<PhysicsSystem>();
    _queries = physicsSystem == null
        ? null
        : Physics2DQueries(_engine.physics, physicsSystem);

    final raycast = _raycastSystem = RaycastSystem();
    _world
      ..addSystem(raycast)
      ..addSystem(_RayFadeSystem())
      ..addSystem(_DroneSystem())
      ..addSystem(_FrameHook(_onFrame));

    _spawnBackground();
    _spawnOverlay();

    switch (demo) {
      case _Demo.shoot:
        _buildShoot();
      case _Demo.los:
        _buildLos();
      case _Demo.layers:
        _buildLayers();
      case _Demo.shapes:
        _buildShapes();
      case _Demo.scanner:
        _buildScanner();
      case _Demo.reflect:
        _buildReflect();
      case _Demo.tracer:
        _buildTracer();
    }

    if (mounted) setState(() {});
  }

  /// Runs every rendered frame: this frame's queries, into the overlay.
  void _onFrame(double dt) {
    _overlay.clear();
    _queriesLastFrame = 0;
    switch (_demo) {
      case _Demo.shoot:
        _frameShoot();
      case _Demo.los:
        _frameLos();
      case _Demo.layers:
        _frameLayers();
      case _Demo.shapes:
        _frameShapes();
      case _Demo.scanner:
        _frameScanner();
      case _Demo.reflect:
        _frameReflect();
      case _Demo.tracer:
        break;
    }
  }

  // -------------------------------------------------------------------------
  // Shared helpers
  // -------------------------------------------------------------------------

  Camera get _camera => _engine.cameraSystem.mainCamera;

  /// The aim in world space: the pointer, or a slow sweep without one.
  Offset get _aim {
    final pointer = _pointer;
    if (pointer != null) return _camera.screenToWorld(pointer);
    final t = _engine.time.totalTime * 0.6;
    return Offset(math.cos(t) * 220, math.sin(t * 1.3) * 140);
  }

  void _spawnBackground() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -10,
          getBoundsCallback: () =>
              const Rect.fromLTWH(-2000, -2000, 4000, 4000),
          onRender: (canvas, _) {
            final paint = Paint()..color = const Color(0xFF080F1A);
            canvas.drawRect(
              const Rect.fromLTWH(-2000, -2000, 4000, 4000),
              paint,
            );
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
    ], name: 'Background');
  }

  /// One entity draws whatever this frame's queries found.
  void _spawnOverlay() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: 50,
          onRender: (canvas, _) => _overlay.paint(canvas),
        ),
      ),
    ], name: 'Query Overlay');
  }

  /// A body for the physics demos: a circle when [radius] is set, else a
  /// box of [size]. A bare `Collider2D` is a static body on layer 0; a
  /// `RigidBody2D` is added for any other layer, a sensor or a kinematic
  /// body.
  Entity _spawnBody({
    required Offset position,
    double? radius,
    Size size = const Size(20, 20),
    required Color fill,
    Color? stroke,
    int layer = _wallLayer,
    BodyType bodyType = BodyType.static,
    bool sensor = false,
    List<String> tags = const [],
    List<Component> extra = const [],
    int drawLayer = 5,
    String? name,
  }) {
    final circle = radius != null;
    return _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(position)),
      RenderableComponent(
        renderable: circle
            ? CircleRenderable(
                radius: radius,
                fillColor: fill,
                strokeColor: stroke ?? fill,
                strokeWidth: 1.5,
                layer: drawLayer,
              )
            : RectangleRenderable(
                size: size,
                fillColor: fill,
                strokeColor: stroke ?? fill,
                strokeWidth: 1.5,
                layer: drawLayer,
              ),
      ),
      if (layer != _wallLayer || sensor || bodyType != BodyType.static)
        RigidBody2D(bodyType: bodyType, layer: layer, isSensor: sensor),
      circle
          ? Collider2D(shape: ColliderShape2D.circle, radius: radius)
          : Collider2D(size: Vector2(size.width, size.height)),
      if (tags.isNotEmpty) TagComponent.of(tags),
      ...extra,
    ], name: name);
  }

  void _spawnWall(Offset position, double w, double h) => _spawnBody(
    position: position,
    size: Size(w, h),
    fill: const Color(0xFF0D3D4A),
    stroke: const Color(0xFF00BCD4),
    tags: const ['wall'],
    drawLayer: 3,
  );

  /// A box for the RaycastSystem demos: analytic collider, no body.
  void _spawnRayBox({
    required Offset position,
    required double width,
    required double height,
    Color color = const Color(0xFF1A3A5C),
    Color? strokeColor,
    bool isReflective = false,
    double reflectivity = 0.8,
  }) {
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(position)),
      RenderableComponent(
        renderable: RectangleRenderable(
          size: Size(width, height),
          fillColor: color,
          strokeColor: strokeColor ?? color.withValues(alpha: 0.8),
          strokeWidth: 1.5,
          layer: 3,
        ),
      ),
      RaycastColliderComponent(
        width: width,
        height: height,
        isBlocker: true,
        isReflective: isReflective,
        reflectivity: reflectivity,
      ),
    ]);
  }

  void _spawnRayCircle({
    required Offset position,
    required double radius,
    required Color fill,
    required Color stroke,
    bool isReflective = false,
    double reflectivity = 0.8,
    int layer = 5,
  }) {
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(position)),
      RenderableComponent(
        renderable: CircleRenderable(
          radius: radius,
          fillColor: fill,
          strokeColor: stroke,
          strokeWidth: 2,
          layer: layer,
        ),
      ),
      RaycastColliderComponent(
        radius: radius,
        isReflective: isReflective,
        reflectivity: reflectivity,
      ),
    ]);
  }

  /// A fading beam: a [RayRenderable] on an entity, faded and removed by
  /// [_RayFadeSystem].
  void _spawnRay(
    Offset from,
    Offset to, {
    Color color = const Color(0xFFFFFF44),
    double lifetime = 0.35,
    double width = 2.5,
  }) {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: RayRenderable(
          start: from,
          end: to,
          color: color,
          width: width,
          lifetime: lifetime,
          layer: 8,
        ),
      ),
      _RayFadeComponent(),
    ]);
  }

  void _spawnDrones(int count, {Offset center = Offset.zero}) {
    for (var i = 0; i < count; i++) {
      _spawnBody(
        position: center,
        radius: 11,
        fill: const Color(0xFF3E2723),
        stroke: const Color(0xFFFFB74D),
        layer: _crateLayer,
        bodyType: BodyType.kinematic,
        tags: const ['drone'],
        extra: [
          _DroneComponent(
            center: center,
            radiusX: 150 + i * 40,
            radiusY: 70 + i * 20,
            speed: 0.5 + i * 0.15,
            phase: i * 2.1,
          ),
        ],
        drawLayer: 6,
      );
    }
  }

  /// Roughly how far an entity's collider reaches from its centre.
  double _reachOf(Entity entity) {
    final c = entity.getComponent<Collider2D>();
    if (c == null) return 12;
    if (c.shape == ColliderShape2D.circle) return c.radius;
    return math.sqrt(c.size.x * c.size.x + c.size.y * c.size.y) / 2;
  }

  Offset _positionOf(Entity entity) =>
      entity.getComponent<TransformComponent>()!.position.toOffset();

  // -------------------------------------------------------------------------
  // Shoot
  // -------------------------------------------------------------------------

  void _buildShoot() {
    _totalEnemies = 12;

    // The shooter has a body too: `ignore: player` looks through it.
    _player = _spawnBody(
      position: Offset.zero,
      radius: 9,
      fill: const Color(0xFF00E676),
      stroke: Colors.white,
      tags: const ['player'],
      drawLayer: 10,
      name: 'Player',
    );

    final rng = math.Random(99);
    for (int i = 0; i < _totalEnemies; i++) {
      final ring = i < 6 ? 90.0 : 160.0;
      final angle =
          (2 * math.pi * i) / (i < 6 ? 6 : (_totalEnemies - 6)) +
          rng.nextDouble() * 0.4;
      _spawnBody(
        position: Offset(ring * math.cos(angle), ring * math.sin(angle)),
        radius: 7,
        fill: const Color(0xFFFF3333),
        stroke: Colors.yellowAccent,
        layer: _crateLayer,
        tags: const ['enemy'],
      );
    }

    for (final (pos, w, h) in [
      (const Offset(-60, 50), 12.0, 60.0),
      (const Offset(55, -45), 60.0, 12.0),
      (const Offset(-30, -80), 10.0, 50.0),
    ]) {
      _spawnWall(pos, w, h);
    }

    _statusMessage = 'Aim with the pointer, click to fire';
  }

  void _frameShoot() {
    final queries = _queries;
    if (queries == null) return;
    const origin = Offset.zero;
    final dir = _aim - origin;
    final hit = queries.raycast(origin, dir, maxDistance: 800, ignore: _player);
    _queriesLastFrame++;
    final end = hit?.point ?? origin + _unit(dir) * 800;
    _overlay.line(origin, end, const Color(0x55FFCA28), 1);
    if (hit != null) {
      final enemy = hit.entity?.hasTag('enemy') ?? false;
      _overlay.hit(
        hit.point,
        hit.normal,
        enemy ? const Color(0xFFFF5252) : const Color(0xFF00BCD4),
      );
    }
  }

  void _fireShot(Offset aim) {
    final queries = _queries;
    if (queries == null) return;
    const origin = Offset.zero;
    final dir = aim - origin;
    final hit = queries.raycast(origin, dir, maxDistance: 800, ignore: _player);
    _spawnRay(origin, hit?.point ?? origin + _unit(dir) * 800);

    final target = hit?.entity;
    if (target != null && target.hasTag('enemy')) {
      // Its body is taken out of the physics world with it.
      _world.destroyEntity(target);
      final left = _world.allTagged('enemy').length;
      _statusMessage =
          'Hit enemy #${target.id} at ${hit!.distance.toStringAsFixed(0)} '
          '— ${_totalEnemies - left} / $_totalEnemies destroyed';
    } else if (hit != null) {
      _statusMessage =
          'Blocked by ${hit.entity?.hasTag('wall') ?? false ? 'a wall' : 'something'}';
    } else {
      _statusMessage = 'Miss';
    }
    setState(() {});
  }

  // -------------------------------------------------------------------------
  // Line of sight
  // -------------------------------------------------------------------------

  void _buildLos() {
    for (final (pos, w, h) in [
      (const Offset(-120, 0), 14.0, 120.0),
      (const Offset(80, 60), 14.0, 90.0),
      (const Offset(0, -90), 110.0, 14.0),
      (const Offset(170, -60), 60.0, 14.0),
    ]) {
      _spawnWall(pos, w, h);
    }

    for (final pos in [
      const Offset(-200, 70),
      const Offset(180, -120),
      const Offset(60, 160),
      const Offset(-160, -150),
      const Offset(220, 100),
      const Offset(-20, 40),
    ]) {
      _spawnBody(
        position: pos,
        radius: 8,
        fill: const Color(0xFFFF9800),
        stroke: const Color(0xFFFFCC02),
        layer: _sensorLayer,
        sensor: true,
        tags: const ['target'],
      );
    }

    _statusMessage = 'Move the pointer — it is the eye';
  }

  void _frameLos() {
    final queries = _queries;
    if (queries == null) return;
    final eye = _aim;
    _overlay
      ..ring(eye, 10, Colors.white, 2)
      ..dot(eye, const Color(0xFF00E676), 6);
    var visible = 0;
    for (final target in _world.allTagged('target')) {
      final to = _positionOf(target);
      final delta = to - eye;
      final hit = queries.raycast(
        eye,
        delta,
        maxDistance: delta.distance,
        layerMask: 1 << _wallLayer,
      );
      _queriesLastFrame++;
      if (hit == null) {
        visible++;
        _overlay
          ..line(eye, to, const Color(0xCCFFFFFF), 1.5)
          ..ring(to, 13, const Color(0xFF00E676), 2);
      } else {
        _overlay
          ..line(eye, hit.point, const Color(0x66FF5252), 1)
          ..line(hit.point, to, const Color(0x22FF5252), 1)
          ..dot(hit.point, const Color(0xFFFF5252), 3);
      }
    }
    _visibleTargets = visible;
  }

  // -------------------------------------------------------------------------
  // Layer mask
  // -------------------------------------------------------------------------

  static const Offset _layerOrigin = Offset(-300, 0);

  void _buildLayers() {
    // Walls (layer 0): bare colliders.
    _spawnWall(const Offset(260, 0), 20, 360);
    _spawnWall(const Offset(40, -150), 20, 120);

    // Glass panes (layer 1).
    for (final x in [-160.0, -20.0, 120.0]) {
      _spawnBody(
        position: Offset(x, 0),
        size: const Size(8, 220),
        fill: const Color(0x5580DEEA),
        stroke: const Color(0xFF80DEEA),
        layer: _glassLayer,
        tags: const ['glass'],
      );
    }

    // Crates (layer 2).
    final rng = math.Random(4);
    for (var i = 0; i < 9; i++) {
      _spawnBody(
        position: Offset(-230 + i * 55.0, -120 + rng.nextDouble() * 240),
        size: const Size(26, 26),
        fill: const Color(0xFF5D4037),
        stroke: const Color(0xFFFFB74D),
        layer: _crateLayer,
        tags: const ['crate'],
      );
    }

    _statusMessage = 'Toggle layers — raycastAll sees only those';
  }

  void _frameLayers() {
    final queries = _queries;
    if (queries == null) return;
    const origin = _layerOrigin;
    final dir = _aim - origin;
    final hits = queries.raycastAll(
      origin,
      dir,
      maxDistance: 900,
      layerMask: _layerMask,
    );
    _queriesLastFrame++;
    _lastHitCount = hits.length;
    _overlay
      ..dot(origin, const Color(0xFF26C6DA), 7)
      ..line(origin, origin + _unit(dir) * 900, const Color(0x5526C6DA), 1.5);
    for (var i = 0; i < hits.length; i++) {
      final h = hits[i];
      final color = _layerColor(h.entity);
      _overlay
        ..hit(h.point, h.normal, color, r: i == 0 ? 6 : 4)
        ..labels.add((h.point + const Offset(6, -16), '${i + 1}', color));
    }
  }

  Color _layerColor(Entity? entity) {
    if (entity == null) return Colors.white;
    if (entity.hasTag('glass')) return const Color(0xFF80DEEA);
    if (entity.hasTag('crate')) return const Color(0xFFFFB74D);
    return const Color(0xFF00BCD4);
  }

  void _toggleLayer(int layer) {
    setState(() => _layerMask ^= 1 << layer);
  }

  // -------------------------------------------------------------------------
  // Shape queries
  // -------------------------------------------------------------------------

  static const Offset _castOrigin = Offset(-300, 120);
  static const double _castRadius = 18;

  void _buildShapes() {
    final rng = math.Random(12);
    for (var i = 0; i < 10; i++) {
      final pos = Offset(
        -200 + rng.nextDouble() * 420,
        -160 + rng.nextDouble() * 320,
      );
      if (i.isEven) {
        _spawnBody(
          position: pos,
          radius: 12 + rng.nextDouble() * 14,
          fill: const Color(0xFF1A2A3A),
          stroke: const Color(0xFF607D8B),
        );
      } else {
        _spawnBody(
          position: pos,
          size: Size(20 + rng.nextDouble() * 40, 20 + rng.nextDouble() * 40),
          fill: const Color(0xFF1A2A3A),
          stroke: const Color(0xFF607D8B),
        );
      }
    }
    _spawnDrones(3, center: const Offset(40, -40));
    _statusMessage = 'Pointer = overlapCircle centre and circleCast target';
  }

  void _frameShapes() {
    final queries = _queries;
    if (queries == null) return;
    final aim = _aim;

    // circleCast: a ball swept from the origin toward the aim.
    const origin = _castOrigin;
    final dir = _unit(aim - origin);
    const maxDistance = 700.0;
    final hit = queries.circleCast(
      origin,
      _castRadius,
      dir,
      maxDistance: maxDistance,
    );
    final travel = hit?.distance ?? maxDistance;
    final stop = origin + dir * travel;
    final side = Offset(-dir.dy, dir.dx) * _castRadius;
    const sweep = Color(0xFFEC407A);
    _overlay
      ..ring(origin, _castRadius, sweep.withValues(alpha: 0.5), 1)
      ..line(origin + side, stop + side, sweep.withValues(alpha: 0.35), 1)
      ..line(origin - side, stop - side, sweep.withValues(alpha: 0.35), 1)
      ..ring(stop, _castRadius, sweep, 2);
    if (hit != null) _overlay.hit(hit.point, hit.normal, Colors.white, r: 3);

    // overlapCircle around the aim.
    final near = queries.overlapCircle(aim, 70);
    _overlay.ring(aim, 70, const Color(0xFFFFCA28), 1.5);
    for (final e in near) {
      _overlay.ring(_positionOf(e), _reachOf(e) + 5, const Color(0xFFFFCA28));
    }

    // overlapBox over the fixed zone.
    final inZone = queries.overlapBox(_zone);
    _overlay.boxes.add((_zone, const Color(0xFF66BB6A)));
    _overlay.labels.add((
      _zone.topLeft + const Offset(4, 2),
      'overlapBox: ${inZone.length}',
      const Color(0xFF66BB6A),
    ));
    for (final e in inZone) {
      _overlay.ring(_positionOf(e), _reachOf(e) + 9, const Color(0xFF66BB6A));
    }

    _queriesLastFrame += 3;
    _nearCount = near.length;
    _zoneCount = inZone.length;
  }

  // -------------------------------------------------------------------------
  // Scanner
  // -------------------------------------------------------------------------

  void _buildScanner() {
    for (final (pos, r) in [
      (const Offset(80, 0), 20.0),
      (const Offset(-100, 60), 15.0),
      (const Offset(40, -100), 12.0),
      (const Offset(-60, -80), 18.0),
      (const Offset(130, 90), 14.0),
      (const Offset(-140, -30), 16.0),
    ]) {
      _spawnBody(
        position: pos,
        radius: r,
        fill: const Color(0xFF1A2A3A),
        stroke: const Color(0xFF37474F),
        tags: const ['obstacle'],
      );
    }
    _spawnDrones(2);

    _spawnBody(
      position: Offset.zero,
      radius: 8,
      fill: const Color(0xFFFF7043),
      stroke: Colors.white,
      layer: _sensorLayer,
      sensor: true, // the scanner itself: invisible to its own rays
      drawLayer: 10,
      name: 'Scanner',
    );

    _statusMessage = 'Sweeping every $_scannerDegrees° — adjust the step';
  }

  void _frameScanner() {
    final queries = _queries;
    if (queries == null) return;
    const center = Offset.zero;
    const scanRadius = 220.0;
    final steps = 360 ~/ _scannerDegrees.clamp(1, 90);
    for (int i = 0; i < steps; i++) {
      final angle = (i * 2 * math.pi) / steps;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final hit = queries.raycast(center, dir, maxDistance: scanRadius);
      final end = hit?.point ?? center + dir * scanRadius;
      final fraction = hit?.fraction ?? 1.0;
      final color = Color.lerp(
        const Color(0xFFFF7043),
        const Color(0x2229B6F6),
        fraction,
      )!;
      _overlay.line(center, end, color, 1.5);
      if (hit != null) _overlay.dot(hit.point, color, 2.5);
    }
    _queriesLastFrame += steps;
  }

  // -------------------------------------------------------------------------
  // Reflection (RaycastSystem)
  // -------------------------------------------------------------------------

  static const Offset _reflectSource = Offset(-80, 40);

  void _buildReflect() {
    final walls = [
      (const Offset(0, 150), 340.0, 14.0, true),
      (const Offset(0, -150), 340.0, 14.0, true),
      (const Offset(170, 0), 14.0, 300.0, true),
      (const Offset(-170, 0), 14.0, 300.0, true),
      // Inner blocks: block, but do not reflect.
      (const Offset(60, 40), 30.0, 30.0, false),
      (const Offset(-80, -60), 30.0, 30.0, false),
    ];
    for (final (pos, w, h, reflective) in walls) {
      _spawnRayBox(
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

    _spawnRayCircle(
      position: _reflectSource,
      radius: 9,
      fill: const Color(0xFF29B6F6),
      stroke: Colors.white,
      layer: 10,
    );

    _statusMessage = 'Aim with the pointer — the beam bounces off cyan walls';
  }

  void _frameReflect() {
    final raycast = _raycastSystem;
    if (raycast == null) return;
    var ray = Ray(
      origin: _reflectSource,
      direction: _aim - _reflectSource,
      maxDistance: 900,
    );
    var energy = 1.0;
    var bounces = 0;
    for (var b = 0; b < 6; b++) {
      final hit = raycast.castRay(ray);
      _queriesLastFrame++;
      final color = const Color(
        0xFF29B6F6,
      ).withValues(alpha: (0.25 + 0.75 * energy).clamp(0.0, 1.0));
      if (hit == null) {
        _overlay.line(ray.origin, ray.at(ray.maxDistance), color, 2);
        break;
      }
      _overlay
        ..line(ray.origin, hit.point, color, 2)
        ..hit(hit.point, hit.normal, color, r: 3);
      final collider = hit.entity.getComponent<RaycastColliderComponent>()!;
      if (!collider.isReflective) break;
      // r = d - 2(d·n)n
      final d = ray.direction, n = hit.normal;
      final reflected = d - n * (2 * (d.dx * n.dx + d.dy * n.dy));
      energy *= collider.reflectivity;
      bounces++;
      ray = Ray(
        origin: hit.point + reflected,
        direction: reflected,
        maxDistance: 900,
      );
    }
    _bounces = bounces;
  }

  // -------------------------------------------------------------------------
  // Ray tracer (RaycastSystem + RayTracer)
  // -------------------------------------------------------------------------

  static const Offset _tracerOrigin = Offset(-120, -40);

  void _buildTracer() {
    for (final (pos, w, h) in [
      (const Offset(0, 160), 360.0, 12.0),
      (const Offset(0, -160), 360.0, 12.0),
      (const Offset(180, 0), 12.0, 320.0),
      (const Offset(-180, 0), 12.0, 320.0),
    ]) {
      _spawnRayBox(
        position: pos,
        width: w,
        height: h,
        color: const Color(0xFF1A0A2E),
        strokeColor: const Color(0xFFAB47BC),
        isReflective: true,
        reflectivity: 0.75,
      );
    }

    for (final pos in [
      const Offset(60, 60),
      const Offset(-70, 50),
      const Offset(100, -80),
    ]) {
      _spawnRayCircle(
        position: pos,
        radius: 18,
        fill: const Color(0xFF1E0A33),
        stroke: const Color(0xFFCE93D8),
        isReflective: true,
        reflectivity: 0.7,
      );
    }

    _spawnRayCircle(
      position: _tracerOrigin,
      radius: 7,
      fill: const Color(0xFFE040FB),
      stroke: Colors.white,
      layer: 10,
    );

    _rayTracer = RayTracer(
      raycastSystem: _raycastSystem!,
      maxBounces: 4,
      minReflectivity: 0.1,
    );

    _statusMessage = 'Click to fire a multi-bounce tracer ray';
  }

  void _fireTracer(Offset aim) {
    final tracer = _rayTracer;
    if (tracer == null) return;
    final trace = tracer.trace(
      Ray(
        origin: _tracerOrigin,
        direction: aim - _tracerOrigin,
        maxDistance: 800,
      ),
    );
    const colors = [
      Color(0xFFE040FB),
      Color(0xFFBA68C8),
      Color(0xFF9C27B0),
      Color(0xFF7B1FA2),
      Color(0xFF4A148C),
    ];
    for (int i = 0; i < trace.segments.length; i++) {
      final seg = trace.segments[i];
      _spawnRay(
        seg.from,
        seg.to,
        color: colors[i.clamp(0, colors.length - 1)],
        lifetime: 1.2,
        width: 3 - i * 0.4,
      );
    }
    setState(
      () => _statusMessage =
          '${trace.segments.length} segments, '
          '${trace.totalLength.toStringAsFixed(0)} units',
    );
  }

  // -------------------------------------------------------------------------
  // Input
  // -------------------------------------------------------------------------

  void _onTapDown(TapDownDetails details) {
    final aim = _camera.screenToWorld(details.localPosition);
    switch (_demo) {
      case _Demo.shoot:
        _fireShot(aim);
      case _Demo.tracer:
        _fireTracer(aim);
      default:
        break;
    }
  }

  static Offset _unit(Offset v) {
    final d = v.distance;
    return d == 0 ? const Offset(1, 0) : v / d;
  }

  // -------------------------------------------------------------------------
  // Stats line
  // -------------------------------------------------------------------------

  String get _statsLine {
    final cam = _camera;
    final base =
        'entities ${_world.entities.length}'
        '  bodies ${_engine.physics.bodies.length}'
        '  queries/frame $_queriesLastFrame'
        '  zoom ${cam.zoom.toStringAsFixed(2)}';
    final extra = switch (_demo) {
      _Demo.shoot =>
        '  enemies ${_world.allTagged('enemy').length}/$_totalEnemies',
      _Demo.los =>
        '  in sight $_visibleTargets/${_world.allTagged('target').length}',
      _Demo.layers => '  hits $_lastHitCount',
      _Demo.shapes => '  overlapCircle $_nearCount  overlapBox $_zoneCount',
      _Demo.reflect => '  bounces $_bounces',
      _ => '',
    };
    return base + extra;
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

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
              Flexible(
                child: Text(
                  _demo.usesPhysics
                      ? 'Physics2DQueries  ·  PhysicsHit2D  ·  RayRenderable'
                      : 'RaycastSystem  ·  Ray  ·  RayTracer',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF29B6F6),
                    fontSize: 10,
                  ),
                ),
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
    return MouseRegion(
      onExit: (_) => _pointer = null,
      child: Listener(
        onPointerHover: (e) => _pointer = e.localPosition,
        onPointerMove: (e) => _pointer = e.localPosition,
        onPointerDown: (e) => _pointer = e.localPosition,
        child: GestureDetector(
          onTapDown: _onTapDown,
          child: GameCameraControls(
            camera: _camera,
            enablePan: false,
            enablePinch: true,
            showZoomLevel: true,
            child: GameWidget(engine: _engine, showFPS: true, showDebug: true),
          ),
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
              separatorBuilder: (context, index) => const SizedBox(width: 6),
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
        return _hint(
          'White = clear  ·  red = blocked',
          'raycast · layerMask: 1 << 0 · sensors skipped',
        );
      case _Demo.layers:
        return _buildLayerControls();
      case _Demo.shapes:
        return _hint(
          'Pink: circleCast  ·  yellow: overlapCircle  ·  green: overlapBox',
          'PhysicsHit2D · List<Entity>',
        );
      case _Demo.scanner:
        return _buildScannerControls();
      case _Demo.reflect:
        return _hint(
          'Move the pointer to steer the beam',
          'RaycastSystem.castRay · r = d − 2(d·n)n',
        );
      case _Demo.tracer:
        return _hint(
          'Click the viewport to fire a traced ray',
          'RayTracer · maxBounces: 4 · RayRenderable',
        );
    }
  }

  Widget _hint(String left, String right) {
    return Row(
      children: [
        Flexible(
          child: Text(
            left,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            right,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildShootControls() {
    final left = _world.allTagged('enemy').length;
    return Row(
      children: [
        Text(
          'Destroyed: ${_totalEnemies - left} / $_totalEnemies',
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
        const Flexible(
          child: Text(
            "raycast · ignore: player · hasTag('enemy')",
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildLayerControls() {
    const color = Color(0xFF26C6DA);
    Widget toggle(String name, int layer) => _actionButton(
      '$name (layer $layer)',
      color,
      () => _toggleLayer(layer),
      selected: _layerMask & (1 << layer) != 0,
    );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'layerMask:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        toggle('walls', _wallLayer),
        toggle('glass', _glassLayer),
        toggle('crates', _crateLayer),
        Text(
          '0b${_layerMask.toRadixString(2).padLeft(3, '0')}',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
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
        for (final deg in [2, 5, 10, 20, 45]) ...[
          _actionButton(
            '$deg°',
            const Color(0xFFFF7043),
            _scannerDegrees == deg
                ? null
                : () => setState(() {
                    _scannerDegrees = deg;
                    _statusMessage =
                        'Sweeping every $_scannerDegrees° — '
                        '${360 ~/ deg} raycasts per frame';
                  }),
          ),
          const SizedBox(width: 4),
        ],
        const Spacer(),
        const Flexible(
          child: Text(
            'raycast · 360° sweep',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    String label,
    Color color,
    VoidCallback? onTap, {
    bool selected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: onTap == null
              ? const Color(0xFF111C2A)
              : color.withValues(alpha: selected ? 0.3 : 0.15),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: onTap != null
                ? color.withValues(alpha: selected ? 0.9 : 0.55)
                : const Color(0xFF1A2535),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap != null ? Colors.white : Colors.white30,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
                Text(
                  _demo.usesPhysics
                      ? 'just_game_engine 2.x · Physics2DQueries API'
                      : 'just_game_engine 2.x · RaycastSystem API',
                  style: const TextStyle(color: Colors.white24, fontSize: 9),
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
