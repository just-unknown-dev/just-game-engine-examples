import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:just_game_engine/graphics_3d.dart'
    show
        AnimationPlayerComponent,
        Capsule3D,
        Cone3D,
        Cube3D,
        Cylinder3D,
        EnvironmentComponent,
        LightComponent,
        LightKind,
        ModelComponent,
        Primitive3D,
        Ramp3D,
        Sphere3D,
        Stairs3D;
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/physics_3d.dart'
    show
        BodyType3D,
        CharacterBody3D,
        Collider3D,
        ColliderShape3D,
        CollisionEnter3DEvent,
        DistanceJoint3D,
        FixedJoint3D,
        HingeJoint3D,
        MotorState3D,
        Physics3D,
        PhysicsHit3D,
        PointJoint3D,
        RigidBody3D,
        SensorEnter3DEvent,
        SensorExit3DEvent,
        SliderJoint3D;

import '../../core/engine/demo_engine.dart';

// 3-D physics on just_game_engine 2.x: rigid bodies and colliders, a
// character controller, joints, and rays/sweeps/overlaps — simulated by Jolt
// (Physics3D) and drawn by just_graphics_engine (Graphics3D), in an engine
// this screen owns. Units are metres; +Y is down, gravity is (0, 9.81, 0).

// -----------------------------------------------------------------------------
// Demo mode
// -----------------------------------------------------------------------------

enum _Demo {
  bodies,
  character,
  joints,
  queries;

  String get label => switch (this) {
    bodies => 'Rigid Bodies',
    character => 'Character',
    joints => 'Joints',
    queries => 'Rays & Queries',
  };

  IconData get icon => switch (this) {
    bodies => Icons.view_in_ar,
    character => Icons.directions_walk,
    joints => Icons.link,
    queries => Icons.radar,
  };

  Color get accentColor => switch (this) {
    bodies => const Color(0xFF29B6F6),
    character => const Color(0xFF66BB6A),
    joints => const Color(0xFFFFCA28),
    queries => const Color(0xFFF5746F),
  };

  String get description => switch (this) {
    bodies =>
      'RigidBody3D + Collider3D: boxes, spheres, capsules, cylinders, a convex '
          'hull of coin.glb and a cone matching its Cone3D. Tap the ground to '
          'drop the selected shape; every CollisionEnter3DEvent is counted and '
          'flashes the body.',
    character =>
      'CharacterBody3D (Jolt CharacterVirtual): walks slopes, climbs stairs, '
          'slides off the steep ramp, pushes crates, rides the moving platform '
          'and trips a sensor. The hero.glb animator is fed its speed and '
          'ground state. WASD / arrows, Space to jump, Shift to run.',
    joints =>
      'HingeJoint3D door with a position motor, a PointJoint3D chain, a '
          'DistanceJoint3D pendulum, a FixedJoint3D welded L-block and a '
          'SliderJoint3D piston driven by its motor.',
    queries =>
      'Physics3DQueries: a laser turret raycasts every step (raycastAll counts '
          'what the beam crosses), a probe finds bodies with overlapSphere and '
          'its height with sphereCast. Tap a body to shoot it along the camera '
          'ray.',
  };

  String get codeSnippet => switch (this) {
    bodies =>
      "import 'package:just_game_engine/physics_3d.dart';\n\n"
          '// EngineConfig(physics3D: Physics3D()) — Jolt, built by the pubspec.\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(position: Vector3(0, -6, 0)), // -Y is up\n'
          '  Cube3D(width: 0.8, height: 0.8, depth: 0.8),\n'
          '  Collider3D(shape: ColliderShape3D.box, size: Vector3(0.8, 0.8, 0.8)),\n'
          '  RigidBody3D(mass: 8, restitution: 0.1),\n'
          ']);\n'
          '// A hull of a model, and a collider matching the drawn shape:\n'
          "Collider3D(shape: ColliderShape3D.convexHull, model: 'assets/models/coin.glb')\n"
          'Collider3D(shape: ColliderShape3D.matchShape) // + Cone3D(...)\n\n'
          'world.events.on<CollisionEnter3DEvent>((e) {\n'
          "  print('\${e.entityA.name} hit \${e.entityB.name} at \${e.point}');\n"
          '});',
    character =>
      'final hero = world.createEntityWithComponents([\n'
          '  TransformComponent(), // its feet\n'
          '  CharacterBody3D(radius: 0.3, height: 1.8, stepHeight: 0.4),\n'
          "  ModelComponent(model: 'assets/models/hero.glb'),\n"
          "  AnimationPlayerComponent(clip: 'idle'),\n"
          "  AnimatorComponent(graphPath: 'assets/models/hero.animator.json'),\n"
          "], name: 'Hero');\n"
          'final body = hero.getComponent<CharacterBody3D>()!;\n'
          '// Every fixed update, before physics:\n'
          'body.moveVelocity.setValues(vx, 0, vz);\n'
          'if (jumpPressed && body.isGrounded) body.jump(6.5);\n'
          'hero.getComponent<AnimatorComponent>()!\n'
          "  ..setFloat('planarSpeed', math.sqrt(vx * vx + vz * vz))\n"
          "  ..setBool('grounded', body.isGrounded);",
    joints =>
      '// A door hinged to the world (no connectedBody):\n'
          'HingeJoint3D(\n'
          '  anchor: Vector3(-0.65, 0, 0), axis: Vector3(0, 1, 0),\n'
          '  useLimits: true, minAngle: -1.9, maxAngle: 1.9,\n'
          '  motor: MotorState3D.position, motorTarget: 1.5,\n'
          '  motorMaxTorque: 400,\n'
          ')\n'
          '// A chain: each link to the one before it.\n'
          "PointJoint3D(connectedBody: EntityTarget.name('Link 3'),\n"
          '    anchor: Vector3(-0.15, 0, 0))\n'
          '// A pendulum on a rope to a point in the world:\n'
          'DistanceJoint3D(connectedAnchor: Vector3(2.5, -5.5, 2.5))\n'
          "FixedJoint3D(connectedBody: EntityTarget.name('Weld A'))\n"
          'SliderJoint3D(axis: Vector3(1, 0, 0), useLimits: true,\n'
          '    motor: MotorState3D.velocity, motorTarget: 2, motorMaxForce: 600)',
    queries =>
      'final queries = engine.physics3D!.queries;\n'
          'final hit = queries.raycast(origin, direction,\n'
          '    maxDistance: 14, ignore: turret);\n'
          'if (hit != null) {\n'
          "  print('\${hit.entity?.name} at \${hit.distance} m');\n"
          '  hit.entity?.getComponent<RigidBody3D>()?.addForce(direction * 30);\n'
          '}\n'
          'final crossed = queries.raycastAll(origin, direction).length;\n'
          'final near = queries.overlapSphere(center, 1.2);  // List<Entity>\n'
          'final down = queries.sphereCast(center, 0.3, Vector3(0, 1, 0));\n\n'
          '// From the camera through a pixel:\n'
          'final ray = engine.cameraSystem.mainCamera\n'
          '    .screenToWorldRay(details.localPosition);',
  };
}

enum _Shape {
  box,
  sphere,
  capsule,
  cylinder,
  hull,
  cone;

  String get label => switch (this) {
    box => 'Box',
    sphere => 'Sphere',
    capsule => 'Capsule',
    cylinder => 'Cylinder',
    hull => 'Hull (coin.glb)',
    cone => 'Cone (match)',
  };
}

const List<Color> _palette = [
  Color(0xFFFF5252),
  Color(0xFFFFB74D),
  Color(0xFFFFEE58),
  Color(0xFF66BB6A),
  Color(0xFF26C6DA),
  Color(0xFF5C6BC0),
  Color(0xFFAB47BC),
  Color(0xFFEC407A),
  Color(0xFFE0E0E0),
];

const String _heroModel = 'assets/models/hero.glb';
const String _heroGraph = 'assets/models/hero.animator.json';
const String _coinModel = 'assets/models/coin.glb';
const String _crateModel = 'assets/models/crate.glb';

String _mat(String name) => 'assets/materials/pbr_$name.material.json';

/// Hold-to-move directions of the on-screen pad.
enum _Dir { forward, back, left, right }

// -----------------------------------------------------------------------------
// ECS helper
// -----------------------------------------------------------------------------

/// Runs a callback in the engine's fixed update at [priority]: 95 runs
/// before physics (90) — gameplay —, 85 after it — what follows bodies.
class _UpdateHook extends System {
  _UpdateHook(this.onUpdate, int priority) {
    this.priority = priority;
  }

  final void Function(double dt) onUpdate;

  @override
  List<Type> get requiredComponents => const [];

  @override
  void update(double deltaTime) => onUpdate(deltaTime);
}

// -----------------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------------

class Physics3DScreen extends StatefulWidget {
  const Physics3DScreen({super.key});

  @override
  State<Physics3DScreen> createState() => _Physics3DScreenState();
}

class _Physics3DScreenState extends State<Physics3DScreen>
    with SingleTickerProviderStateMixin {
  Engine? _engine;
  Object? _startError;
  bool _disposed = false;
  _Demo _demo = _Demo.bodies;

  late final Ticker _hud;
  Duration _lastHud = Duration.zero;
  final math.Random _rng = math.Random(7);

  final List<EventSubscription> _subscriptions = [];
  int _contacts = 0;
  String _lastContact = '-';

  // ── Per-demo state ─────────────────────────────────────────────────────
  double _time = 0;
  OrbitFollowComponent? _orbit;
  void Function(double dt)? _step;
  void Function(double dt)? _lateStep;
  final List<TransformComponent> _moving = [];
  final List<TransformComponent> _lateMoving = [];

  // Bodies
  _Shape _shape = _Shape.box;
  bool _bouncy = false;
  int _spawnCount = 0;
  final List<Entity> _spawned = [];
  final Set<Entity> _flashable = {};
  final Map<Entity, double> _flash = {};

  // Character
  Entity? _hero;
  CharacterBody3D? _body;
  final Set<_Dir> _held = {};
  bool _run = false;
  bool _jumpQueued = false;
  bool _spaceWasDown = false;
  int _zoneEntries = 0;
  bool _inZone = false;
  Entity? _zone;

  // Joints
  HingeJoint3D? _door;
  bool _doorOpen = false;
  bool _doorFree = false;
  SliderJoint3D? _piston;
  Entity? _chainEnd;

  // Queries
  String _laserInfo = '-';
  String _probeInfo = '-';
  String _shotInfo = 'tap a body';
  bool _laserPush = true;
  final Set<Entity> _highlighted = {};

  // Pointer
  Offset? _lastPointer;
  Offset? _downAt;
  double _dragged = 0;

  @override
  void initState() {
    super.initState();
    _hud = createTicker(_onHud);
    unawaited(_start());
  }

  Future<void> _start() async {
    final Engine engine;
    try {
      // 3-D physics when Physics3D.isSupported (Jolt), else none.
      engine = await Demo3DEngine.create(physics: true);
    } on Object catch (e) {
      if (!_disposed) setState(() => _startError = e);
      return;
    }
    if (_disposed) {
      // The screen went while the engine was starting.
      unawaited(engine.dispose());
      return;
    }
    final world = engine.world;
    world
      ..addSystem(_UpdateHook(_onUpdate, 95))
      ..addSystem(_UpdateHook(_onLateUpdate, 85));
    _subscriptions
      ..add(world.events.on<CollisionEnter3DEvent>(_onCollision))
      ..add(
        world.events.on<SensorEnter3DEvent>((e) {
          if (e.sensor == _zone && e.other == _hero) {
            _zoneEntries++;
            _inZone = true;
            _zone?.getComponent<Primitive3D>()?.emissionStrength = 5;
          }
        }),
      )
      ..add(
        world.events.on<SensorExit3DEvent>((e) {
          if (e.sensor == _zone && e.other == _hero) {
            _inZone = false;
            _zone?.getComponent<Primitive3D>()?.emissionStrength = 1.2;
          }
        }),
      );
    _engine = engine;
    _buildDemo(_demo);
    _hud.start();
  }

  @override
  void dispose() {
    _disposed = true;
    _hud.dispose();
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    final engine = _engine;
    _engine = null;
    if (engine != null) unawaited(engine.dispose());
    super.dispose();
  }

  void _onHud(Duration elapsed) {
    if (elapsed - _lastHud < const Duration(milliseconds: 250)) return;
    _lastHud = elapsed;
    if (mounted) setState(() {});
  }

  void _onCollision(CollisionEnter3DEvent e) {
    _contacts++;
    _lastContact =
        '${e.entityA.name ?? '#${e.entityA.id}'} ↔ '
        '${e.entityB.name ?? '#${e.entityB.id}'}';
    for (final entity in [e.entityA, e.entityB]) {
      if (_flashable.contains(entity)) _flash[entity] = 1;
    }
  }

  void _onUpdate(double dt) {
    _time += dt;
    for (final t in _moving) {
      t.capturePrevious();
    }
    _step?.call(dt);
    _updateFlashes(dt);
  }

  void _onLateUpdate(double dt) {
    for (final t in _lateMoving) {
      t.capturePrevious();
    }
    _lateStep?.call(dt);
  }

  /// Bodies light up when they hit something, fading out (in a few steps,
  /// so only a few looks are made).
  void _updateFlashes(double dt) {
    if (_flash.isEmpty) return;
    for (final entity in _flash.keys.toList()) {
      final shape = entity.isAlive ? entity.getComponent<Primitive3D>() : null;
      final left = _flash[entity]! - dt * 2.5;
      if (shape == null) {
        _flash.remove(entity);
        continue;
      }
      if (left <= 0) {
        shape
          ..emission = const Color(0xFF000000)
          ..emissionStrength = 1;
        _flash.remove(entity);
      } else {
        _flash[entity] = left;
        shape
          ..emission = const Color(0xFFFF9A3C)
          ..emissionStrength = (left * 4).ceil() / 2;
      }
    }
  }

  World get _world => _engine!.world;
  Physics3D? get _physics => _engine?.physics3D;

  // ---------------------------------------------------------------------------
  // Building blocks
  // ---------------------------------------------------------------------------

  Entity _spawn(
    String name,
    Vector3 position,
    List<Component> components, {
    Vector3? euler,
    Vector3? scale,
  }) => _world.createEntityWithComponents([
    TransformComponent(position: position, euler: euler, scale: scale),
    ...components,
  ], name: name);

  /// A static solid, its collider the shape it is drawn as.
  Entity _solid(
    String name,
    Vector3 position,
    Primitive3D shape, {
    Vector3? euler,
  }) => _spawn(name, position, [
    shape,
    Collider3D(shape: ColliderShape3D.matchShape),
  ], euler: euler);

  void _environment() {
    _world.createEntityWithComponents([
      EnvironmentComponent(
        zenith: const Color(0xFF2B62C0),
        horizon: const Color(0xFFC9DCEF),
        ground: const Color(0xFF6E5D4B),
        ambientSky: const Color(0xFFA9C1E6),
        ambientGround: const Color(0xFF7A6550),
        exposure: 1.05,
        fog: true,
        fogColor: const Color(0xFFE6D5C3),
        fogDensity: 0.01,
        fogStart: 25,
      ),
    ], name: 'Sky');
    _spawn('Sun', Vector3(0, -12, 0), [
      LightComponent(
        kind: LightKind.directional,
        color: const Color(0xFFFFF4E0),
        intensity: 1.3,
      ),
    ], euler: Vector3(-0.95, 0.7, 0));
  }

  /// The ground: a static slab whose top is at y = 0.
  void _ground(double size) {
    _solid(
      'Ground',
      Vector3(0, 0.5, 0),
      Cube3D(
        width: size,
        height: 1,
        depth: size,
        material: _mat('stone'),
        color: const Color(0xFF5F5A55),
        roughness: 0.92,
      ),
    );
  }

  void _orbitCamera(
    String target, {
    double distance = 14,
    double yaw = 0.5,
    double pitch = -0.45,
    Vector3? pivot,
    double maxDistance = 40,
  }) {
    final orbit = OrbitFollowComponent(
      distance: distance,
      minDistance: 2,
      maxDistance: maxDistance,
      yaw: yaw,
      pitch: pitch,
      minPitch: -1.35,
      maxPitch: -0.05,
      pivot: pivot ?? Vector3.zero(),
      damping: 0.1,
    );
    _orbit = orbit;
    _spawn('Orbit Cam', Vector3.zero(), [
      VirtualCameraComponent(
        follow: EntityTarget.name(target),
        projection: CameraProjection.perspective,
        fieldOfView: 0.95,
        nearClip: 0.1,
        farClip: 400,
      ),
      orbit,
    ]);
  }

  Vector3 _randomEuler() => Vector3(
    _rng.nextDouble() * math.pi,
    _rng.nextDouble() * math.pi,
    _rng.nextDouble() * math.pi,
  );

  /// A dynamic body of [kind] at [at].
  Entity _spawnBody(
    _Shape kind,
    Vector3 at, {
    bool flash = true,
    Vector3? velocity,
  }) {
    final color = _palette[_rng.nextInt(_palette.length)];
    final metal = _rng.nextDouble() < 0.3;
    final metallic = metal ? 1.0 : 0.0;
    final roughness = metal ? 0.25 : 0.55;
    final (Component look, Collider3D collider, double mass) = switch (kind) {
      _Shape.box => (
        Cube3D(
          width: 0.8,
          height: 0.8,
          depth: 0.8,
          color: color,
          metallic: metallic,
          roughness: roughness,
        ),
        Collider3D(shape: ColliderShape3D.box, size: Vector3(0.8, 0.8, 0.8)),
        8.0,
      ),
      _Shape.sphere => (
        Sphere3D(
          radius: 0.45,
          color: color,
          metallic: metallic,
          roughness: roughness,
        ),
        Collider3D(shape: ColliderShape3D.sphere, radius: 0.45),
        5.0,
      ),
      _Shape.capsule => (
        Capsule3D(
          radius: 0.3,
          height: 1.2,
          color: color,
          metallic: metallic,
          roughness: roughness,
        ),
        Collider3D(shape: ColliderShape3D.capsule, radius: 0.3, height: 1.2),
        6.0,
      ),
      _Shape.cylinder => (
        Cylinder3D(
          radius: 0.4,
          height: 0.8,
          color: color,
          metallic: metallic,
          roughness: roughness,
        ),
        Collider3D(shape: ColliderShape3D.cylinder, radius: 0.4, height: 0.8),
        7.0,
      ),
      // The hull of a model's vertices, scaled flat: a gem.
      _Shape.hull => (
        ModelComponent(model: _coinModel),
        Collider3D(shape: ColliderShape3D.convexHull, model: _coinModel),
        3.0,
      ),
      // The collider takes the shape it is drawn as (convex parts).
      _Shape.cone => (
        Cone3D(
          radius: 0.45,
          height: 0.9,
          segments: 24,
          color: color,
          metallic: metallic,
          roughness: roughness,
        ),
        Collider3D(shape: ColliderShape3D.matchShape),
        4.0,
      ),
    };
    final entity = _spawn(
      '${kind.label.split(' ').first} ${++_spawnCount}',
      at,
      [
        look,
        collider,
        RigidBody3D(
          mass: mass,
          friction: 0.6,
          restitution: _bouncy ? 0.65 : 0.1,
          initialVelocity: velocity,
          initialAngularVelocity: Vector3(
            _rng.nextDouble() * 4 - 2,
            _rng.nextDouble() * 4 - 2,
            _rng.nextDouble() * 4 - 2,
          ),
        ),
      ],
      euler: _randomEuler(),
      scale: kind == _Shape.hull ? Vector3(1.6, 1.6, 0.7) : null,
    );
    if (flash) _flashable.add(entity);
    _spawned.add(entity);
    // Keep the count sane: the oldest go first.
    while (_spawned.length > 160) {
      final old = _spawned.removeAt(0);
      _flashable.remove(old);
      _flash.remove(old);
      if (old.isAlive) _world.destroyEntity(old);
    }
    return entity;
  }

  // ---------------------------------------------------------------------------
  // Demo builders
  // ---------------------------------------------------------------------------

  void _buildDemo(_Demo demo) {
    final engine = _engine;
    if (engine == null) return;
    engine.world.destroyAllEntities();
    engine.cameraSystem.brain
      ..reset()
      ..updateMode = CameraUpdateMode.frame;
    _orbit = null;
    _step = null;
    _lateStep = null;
    _moving.clear();
    _lateMoving.clear();
    _spawned.clear();
    _flashable.clear();
    _flash.clear();
    _highlighted.clear();
    _hero = null;
    _body = null;
    _zone = null;
    _inZone = false;
    _door = null;
    _piston = null;
    _chainEnd = null;
    _held.clear();
    _time = 0;
    _contacts = 0;
    _lastContact = '-';

    switch (demo) {
      case _Demo.bodies:
        _buildBodies();
      case _Demo.character:
        _buildCharacter();
      case _Demo.joints:
        _buildJoints();
      case _Demo.queries:
        _buildQueries();
    }
    if (mounted) setState(() => _demo = demo);
  }

  // ── Rigid bodies ───────────────────────────────────────────────────────

  void _buildBodies() {
    _environment();
    _ground(30);
    _spawn('Pivot', Vector3.zero(), const []);
    // A rim, a ramp, steps and posts to tumble over.
    for (final (x, z, w, d) in const [
      (0.0, -14.8, 30.0, 0.4),
      (0.0, 14.8, 30.0, 0.4),
      (-14.8, 0.0, 0.4, 30.0),
      (14.8, 0.0, 0.4, 30.0),
    ]) {
      _solid(
        'Rim',
        Vector3(x, -0.3, z),
        Cube3D(width: w, height: 0.6, depth: d, material: _mat('stone')),
      );
    }
    _solid(
      'Ramp',
      Vector3(-4, -0.9, -2),
      Ramp3D(width: 3, height: 1.8, depth: 5, material: _mat('marble')),
      euler: Vector3(0, math.pi / 2, 0),
    );
    _solid(
      'Steps',
      Vector3(4, -0.75, 1),
      Stairs3D(
        width: 3,
        height: 1.5,
        depth: 3,
        steps: 5,
        material: _mat('marble'),
      ),
      euler: Vector3(0, -math.pi / 2, 0),
    );
    for (var i = 0; i < 5; i++) {
      final a = 2 * math.pi * i / 5 + 0.3;
      _solid(
        'Post',
        Vector3(2.2 * math.sin(a), -0.6, 2.2 * math.cos(a) - 5.5),
        Cylinder3D(radius: 0.25, height: 1.2, material: _mat('copper')),
      );
    }
    _rain(14);
    _orbitCamera('Pivot', distance: 18, yaw: 0.6, pitch: -0.55);
  }

  void _rain(int count) {
    for (var i = 0; i < count; i++) {
      final kind = _Shape.values[_rng.nextInt(_Shape.values.length)];
      _spawnBody(
        kind,
        Vector3(
          _rng.nextDouble() * 10 - 5,
          -6 - _rng.nextDouble() * 6,
          _rng.nextDouble() * 10 - 5,
        ),
      );
    }
  }

  void _dropAt(Vector3 point) {
    _spawnBody(_shape, Vector3(point.x, math.min(point.y - 5, -5), point.z));
  }

  // ── Character ──────────────────────────────────────────────────────────

  void _buildCharacter() {
    _environment();
    _ground(44);
    _zoneEntries = 0;
    // Stairs up onto a block (rising towards +Z).
    _solid(
      'Stairs',
      Vector3(5, -0.6, 2),
      Stairs3D(
        width: 3,
        height: 1.2,
        depth: 3,
        steps: 6,
        material: _mat('marble'),
      ),
    );
    _solid(
      'Stairs Top',
      Vector3(5, -0.6, 5),
      Cube3D(width: 3, height: 1.2, depth: 3, material: _mat('marble')),
    );
    // A gentle ramp (17°) and one too steep to walk (51°).
    _solid(
      'Ramp',
      Vector3(-5, -0.75, 2),
      Ramp3D(width: 3, height: 1.5, depth: 5, material: _mat('jade')),
    );
    _solid(
      'Ramp Top',
      Vector3(-5, -0.75, 6.5),
      Cube3D(width: 3, height: 1.5, depth: 4, material: _mat('jade')),
    );
    _solid(
      'Steep Ramp',
      Vector3(-10, -1.25, 2),
      Ramp3D(width: 2.5, height: 2.5, depth: 2, material: _mat('ruby')),
    );
    // Crates to push (glTF models with box colliders) and balls to kick.
    for (var i = 0; i < 6; i++) {
      _spawn(
        'Crate ${i + 1}',
        Vector3(-1.1 + (i % 3) * 1.1, -0.5 - (i ~/ 3) * 1.02, 6.5),
        [
          ModelComponent(model: _crateModel),
          Collider3D(shape: ColliderShape3D.box, size: Vector3(1, 1, 1)),
          RigidBody3D(mass: 15),
        ],
      );
    }
    for (var i = 0; i < 3; i++) {
      _spawn('Ball ${i + 1}', Vector3(-1.5 + i * 1.5, -0.5, 3), [
        Sphere3D(radius: 0.5, color: _palette[i * 2], roughness: 0.4),
        Collider3D(shape: ColliderShape3D.sphere, radius: 0.5),
        RigidBody3D(mass: 3, restitution: 0.5),
      ]);
    }
    // A kinematic platform the game moves: it carries the hero.
    final platform = _spawn('Platform', Vector3(0, -0.16, 11), [
      Cube3D(width: 3, height: 0.3, depth: 3, material: _mat('gold')),
      Collider3D(shape: ColliderShape3D.matchShape),
      RigidBody3D(bodyType: BodyType3D.kinematic),
    ]);
    final platformT = platform.getComponent<TransformComponent>()!;
    // A sensor zone: reports the hero entering and leaving.
    _zone = _spawn('Zone', Vector3(7, -0.03, -3), [
      Cylinder3D(
        radius: 1.5,
        height: 0.06,
        color: const Color(0xFF0E1220),
        emission: const Color(0xFF19E6FF),
        emissionStrength: 1.2,
        castShadows: false,
      ),
      Collider3D(
        shape: ColliderShape3D.cylinder,
        radius: 1.5,
        height: 2,
        offset: Vector3(0, -1, 0),
      ),
      RigidBody3D(bodyType: BodyType3D.static, isSensor: true),
    ]);

    // The hero: a character body drawn as hero.glb.
    final animator = AnimatorComponent(graphPath: _heroGraph)
      ..setBool('grounded', true)
      ..setFloat('onGround', 1)
      ..setBool('jumping', false)
      ..setBool('crouching', false)
      ..setBool('striking', false)
      ..setBool('inCombat', false)
      ..setFloat('planarSpeed', 0);
    final hero = _spawn('Hero', Vector3(0, 0, -1), [
      CharacterBody3D(radius: 0.3, height: 1.8, stepHeight: 0.4),
      ModelComponent(model: _heroModel),
      AnimationPlayerComponent(clip: 'idle'),
      animator,
    ], euler: Vector3(0, math.pi, 0));
    _hero = hero;
    _body = hero.getComponent<CharacterBody3D>();
    final heroT = hero.getComponent<TransformComponent>()!;

    _orbitCamera(
      'Hero',
      distance: 7,
      yaw: 0,
      pitch: -0.35,
      pivot: Vector3(0, -1.3, 0),
      maxDistance: 16,
    );

    _step = (dt) {
      platformT.position.x = 6 * math.sin(_time * 0.45);
      _moveHero(dt, heroT, animator);
    };
  }

  bool _key(LogicalKeyboardKey key) =>
      HardwareKeyboard.instance.isLogicalKeyPressed(key);

  void _moveHero(
    double dt,
    TransformComponent heroT,
    AnimatorComponent animator,
  ) {
    final body = _body;
    if (body == null) return;
    var forward = 0.0, right = 0.0;
    if (_key(LogicalKeyboardKey.keyW) ||
        _key(LogicalKeyboardKey.arrowUp) ||
        _held.contains(_Dir.forward)) {
      forward += 1;
    }
    if (_key(LogicalKeyboardKey.keyS) ||
        _key(LogicalKeyboardKey.arrowDown) ||
        _held.contains(_Dir.back)) {
      forward -= 1;
    }
    if (_key(LogicalKeyboardKey.keyD) ||
        _key(LogicalKeyboardKey.arrowRight) ||
        _held.contains(_Dir.right)) {
      right += 1;
    }
    if (_key(LogicalKeyboardKey.keyA) ||
        _key(LogicalKeyboardKey.arrowLeft) ||
        _held.contains(_Dir.left)) {
      right -= 1;
    }
    final space = _key(LogicalKeyboardKey.space);
    if (space && !_spaceWasDown) _jumpQueued = true;
    _spaceWasDown = space;
    final running =
        _run ||
        _key(LogicalKeyboardKey.shiftLeft) ||
        _key(LogicalKeyboardKey.shiftRight);

    // Relative to the camera: forward is where it looks, level.
    final yaw = _orbit?.yaw ?? 0;
    var vx = math.sin(yaw) * forward + math.cos(yaw) * right;
    var vz = math.cos(yaw) * forward - math.sin(yaw) * right;
    final len = math.sqrt(vx * vx + vz * vz);
    if (len > 1) {
      vx /= len;
      vz /= len;
    }
    final speed = running ? 4.5 : 2.0;
    body.moveVelocity.setValues(vx * speed, 0, vz * speed);
    if (_jumpQueued) {
      if (body.isGrounded) body.jump(6.5);
      _jumpQueued = false;
    }
    // Face where it runs (the model faces -Z, hence + pi), turning smoothly.
    if (len > 0.1) {
      final target = math.atan2(vx, vz) + math.pi;
      var turn = (target - heroT.eulerY) % (2 * math.pi);
      if (turn > math.pi) turn -= 2 * math.pi;
      heroT.eulerY = heroT.eulerY + turn * math.min(1.0, dt * 12);
    }
    // What the third-person kit would bind, fed by hand.
    final v = body.velocity;
    final grounded = body.isGrounded;
    animator
      ..setFloat('planarSpeed', math.sqrt(v.x * v.x + v.z * v.z))
      ..setBool('grounded', grounded)
      ..setFloat('onGround', grounded ? 1 : 0)
      ..setBool('jumping', !grounded && v.y < -0.5);
    // Fell off the world: back to the start.
    if (heroT.position.y > 30) _respawnHero();
  }

  void _respawnHero() {
    _hero?.getComponent<TransformComponent>()?.position.setValues(0, -0.5, -1);
  }

  // ── Joints ─────────────────────────────────────────────────────────────

  void _buildJoints() {
    _environment();
    _ground(30);
    _spawn('Pivot', Vector3(0, 0, 0), const []);

    // A door on a hinge to the world, between two posts.
    _solid(
      'Door Post L',
      Vector3(-4.6, -1.1, 0),
      Cube3D(width: 0.2, height: 2.2, depth: 0.2, material: _mat('obsidian')),
    );
    _solid(
      'Door Post R',
      Vector3(-3.1, -1.1, 0),
      Cube3D(width: 0.2, height: 2.2, depth: 0.2, material: _mat('obsidian')),
    );
    _solid(
      'Lintel',
      Vector3(-3.85, -2.3, 0),
      Cube3D(width: 1.7, height: 0.2, depth: 0.2, material: _mat('obsidian')),
    );
    final door = HingeJoint3D(
      anchor: Vector3(-0.65, 0, 0),
      axis: Vector3(0, 1, 0),
      useLimits: true,
      minAngle: -1.9,
      maxAngle: 1.9,
      motor: MotorState3D.position,
      motorTarget: 0,
      motorMaxTorque: 400,
    );
    _door = door;
    _doorOpen = false;
    _doorFree = false;
    _spawn('Door', Vector3(-3.85, -1.05, 0), [
      Cube3D(width: 1.2, height: 2.0, depth: 0.1, material: _mat('copper')),
      Collider3D(shape: ColliderShape3D.box, size: Vector3(1.2, 2.0, 0.1)),
      RigidBody3D(mass: 20, angularDamping: 0.3),
      door,
    ]);

    // A chain of point (ball) joints from a block, swinging.
    _solid(
      'Chain Anchor',
      Vector3(1, -4.4, 0),
      Cube3D(width: 0.4, height: 0.2, depth: 0.4, material: _mat('chrome')),
    );
    var previous = 'Chain Anchor';
    for (var i = 0; i < 10; i++) {
      final name = 'Link ${i + 1}';
      final last = i == 9;
      final radius = last ? 0.25 : 0.12;
      final x = 1.37 + 0.3 * i + (last ? 0.13 : 0);
      final link = _spawn(name, Vector3(x, -4.4, 0), [
        Sphere3D(
          radius: radius,
          material: last ? _mat('gold') : _mat('chrome'),
          color: last ? const Color(0xFFFFC356) : const Color(0xFFE9ECF1),
          metallic: 1,
          roughness: 0.2,
        ),
        Collider3D(shape: ColliderShape3D.sphere, radius: radius),
        RigidBody3D(mass: last ? 3 : 0.5, linearDamping: 0.1),
        PointJoint3D(
          connectedBody: EntityTarget.name(previous),
          anchor: Vector3(-(last ? 0.21 : 0.15), 0, 0),
        ),
      ]);
      previous = name;
      if (last) _chainEnd = link;
    }

    // A pendulum: a ball on a rope to a point in the world.
    final anchor = Vector3(2.5, -5.5, 2.5);
    _spawn('Rope Hook', anchor, [
      Cube3D(width: 0.3, height: 0.15, depth: 0.3, material: _mat('obsidian')),
    ]);
    final ball = _spawn('Pendulum', Vector3(6.2, -3.2, 2.5), [
      Sphere3D(radius: 0.4, material: _mat('ruby'), roughness: 0.15),
      Collider3D(shape: ColliderShape3D.sphere, radius: 0.4),
      RigidBody3D(mass: 10),
      DistanceJoint3D(connectedAnchor: anchor),
    ]);
    final ballT = ball.getComponent<TransformComponent>()!;
    final rope = _spawn('Rope', anchor, [
      Cylinder3D(
        radius: 0.025,
        height: 1,
        color: const Color(0xFFD8C8A8),
        castShadows: false,
      ),
    ]);
    final ropeT = rope.getComponent<TransformComponent>()!;
    _lateMoving.add(ropeT);
    _placeRope(ropeT, anchor, ballT.position);

    // Three blocks welded into one L that tumbles as a whole.
    _dropWeld();

    // A piston on a slider joint, its motor pushing back and forth.
    _spawn('Rail', Vector3(-1, -0.03, -4), [
      Cube3D(width: 4, height: 0.06, depth: 0.3, material: _mat('chrome')),
    ]);
    final piston = SliderJoint3D(
      axis: Vector3(1, 0, 0),
      useLimits: true,
      minPosition: -1.5,
      maxPosition: 1.5,
      motor: MotorState3D.velocity,
      motorTarget: 2,
      motorMaxForce: 600,
    );
    _piston = piston;
    _spawn('Piston', Vector3(-1, -0.37, -4), [
      Cube3D(width: 0.6, height: 0.6, depth: 0.6, material: _mat('gold')),
      Collider3D(shape: ColliderShape3D.box, size: Vector3(0.6, 0.6, 0.6)),
      RigidBody3D(mass: 10),
      piston,
    ]);
    for (var i = 0; i < 3; i++) {
      _spawnBody(
        _Shape.sphere,
        Vector3(1.4 + i * 0.95, -0.5, -4),
        flash: false,
      );
    }

    _orbitCamera(
      'Pivot',
      distance: 15,
      yaw: 0.35,
      pitch: -0.4,
      pivot: Vector3(0, -2, 0),
    );

    _step = (dt) {
      // The piston's motor turns round every 1.6 s.
      piston.motorTarget = (_time ~/ 1.6).isEven ? 2.0 : -2.0;
    };
    _lateStep = (dt) => _placeRope(ropeT, anchor, ballT.position);
  }

  /// Stretches the rope (a 1 m cylinder along Y) from [a] to [b].
  void _placeRope(TransformComponent rope, Vector3 a, Vector3 b) {
    final d = b - a;
    final length = d.length;
    if (length < 1e-6) return;
    rope.position.setValues((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2);
    rope.scale.setValues(1, length, 1);
    final dir = d / length;
    final axis = Vector3(0, 1, 0).cross(dir);
    rope.setRotation(Quaternion.axisAngle(axis, math.acos(dir.y.clamp(-1, 1))));
  }

  void _dropWeld() {
    for (final name in const ['Weld A', 'Weld B', 'Weld C']) {
      final e = _world.findEntityByName(name);
      if (e != null) _world.destroyEntity(e);
    }
    Cube3D block() =>
        Cube3D(width: 0.6, height: 0.6, depth: 0.6, material: _mat('jade'));
    Collider3D box() =>
        Collider3D(shape: ColliderShape3D.box, size: Vector3(0.6, 0.6, 0.6));
    _spawn('Weld A', Vector3(3, -4, -2.5), [
      block(),
      box(),
      RigidBody3D(mass: 4),
    ]);
    _spawn('Weld B', Vector3(3.65, -4, -2.5), [
      block(),
      box(),
      RigidBody3D(mass: 4),
      FixedJoint3D(connectedBody: const EntityTarget.name('Weld A')),
    ]);
    _spawn('Weld C', Vector3(3.65, -4.65, -2.5), [
      block(),
      box(),
      RigidBody3D(mass: 4),
      FixedJoint3D(connectedBody: const EntityTarget.name('Weld B')),
    ]);
  }

  void _toggleDoor() {
    final door = _door;
    if (door == null) return;
    setState(() {
      _doorOpen = !_doorOpen;
      _doorFree = false;
    });
    door
      ..motor = MotorState3D.position
      ..motorTarget = _doorOpen ? 1.5 : 0;
    _wake(_world.findEntityByName('Door'));
  }

  void _freeDoor() {
    final door = _door;
    if (door == null) return;
    setState(() => _doorFree = true);
    door.motor = MotorState3D.off;
    _world
        .findEntityByName('Door')
        ?.getComponent<RigidBody3D>()
        ?.addAngularImpulse(Vector3(0, 40, 0));
  }

  void _kickChain() {
    _chainEnd?.getComponent<RigidBody3D>()?.addImpulse(Vector3(0, 0, 18));
  }

  void _wake(Entity? entity) => entity?.getComponent<RigidBody3D>()?.wakeUp();

  // ── Queries ────────────────────────────────────────────────────────────

  void _buildQueries() {
    _environment();
    _ground(30);
    _spawn('Pivot', Vector3.zero(), const []);
    // Something to hit: a ring of loose bodies and a few pillars.
    for (var i = 0; i < 26; i++) {
      final a = 2 * math.pi * i / 26 + _rng.nextDouble() * 0.2;
      final r = 3.5 + _rng.nextDouble() * 4;
      final kind = const [
        _Shape.box,
        _Shape.sphere,
        _Shape.cylinder,
        _Shape.capsule,
      ][i % 4];
      _spawnBody(
        kind,
        Vector3(r * math.sin(a), -0.6 - _rng.nextDouble(), r * math.cos(a)),
        flash: false,
      );
    }
    for (var i = 0; i < 4; i++) {
      final a = math.pi / 4 + i * math.pi / 2;
      _solid(
        'Pillar ${i + 1}',
        Vector3(9.5 * math.sin(a), -1.25, 9.5 * math.cos(a)),
        Cylinder3D(radius: 0.5, height: 2.5, material: _mat('marble')),
      );
    }

    // The laser turret: a static solid the ray ignores.
    final turret = _solid(
      'Turret',
      Vector3(0, -0.35, 0),
      Cylinder3D(radius: 0.35, height: 0.7, material: _mat('obsidian')),
    );
    final beam = _spawn('Laser', Vector3(0, -0.55, 0), [
      Cube3D(
        width: 0.04,
        height: 0.04,
        depth: 1,
        color: const Color(0xFFFF2040),
        unlit: true,
        castShadows: false,
      ),
    ]);
    final beamT = beam.getComponent<TransformComponent>()!;
    final marker = _spawn('Laser Hit', Vector3.zero(), [
      Sphere3D(
        radius: 0.12,
        color: const Color(0xFFFFE04A),
        unlit: true,
        castShadows: false,
      ),
      LightComponent(color: const Color(0xFFFF4060), intensity: 4, range: 3),
    ]);
    final markerT = marker.getComponent<TransformComponent>()!;
    // The probe: a see-through ball; overlaps light up what is inside.
    final probe = _spawn('Probe', Vector3(5, -0.6, 0), [
      Sphere3D(
        radius: 1.2,
        material: _mat('glass'),
        color: const Color(0xFFC8ECFF),
        opacity: 0.25,
        castShadows: false,
      ),
    ]);
    final probeT = probe.getComponent<TransformComponent>()!;
    _lateMoving.addAll([beamT, markerT, probeT]);

    _orbitCamera('Pivot', distance: 17, yaw: 0.4, pitch: -0.7);

    final origin = Vector3(0, -0.55, 0);
    final direction = Vector3.zero();
    _lateStep = (dt) {
      final queries = _physics?.queries;
      // Laser: one ray a step, round and round.
      final a = _time * 0.6;
      direction.setValues(math.sin(a), 0, math.cos(a));
      final hit = queries?.raycast(
        origin,
        direction,
        maxDistance: 14,
        ignore: turret,
      );
      final length = hit?.distance ?? 14;
      beamT.position.setValues(
        origin.x + direction.x * length / 2,
        origin.y,
        origin.z + direction.z * length / 2,
      );
      beamT.scale.setValues(1, 1, length);
      beamT.eulerY = a;
      marker.isActive = hit != null;
      if (hit != null) {
        markerT.position.setFrom(hit.point);
        final crossed = queries!
            .raycastAll(origin, direction, maxDistance: 14, ignore: turret)
            .length;
        _laserInfo =
            '${hit.entity?.name ?? 'body ${hit.body}'} at '
            '${hit.distance.toStringAsFixed(2)} m  ·  crosses $crossed';
        final rigid = hit.entity?.getComponent<RigidBody3D>();
        if (_laserPush &&
            rigid != null &&
            rigid.bodyType == BodyType3D.dynamic) {
          rigid.addForce(direction * 30);
        }
      } else {
        _laserInfo = 'nothing within 14 m';
      }

      // Probe: round the ring; overlapSphere finds what is inside it.
      final p = _time * 0.35;
      probeT.position.setValues(5 * math.sin(p), -1.25, 5 * math.cos(p));
      final inside = queries?.overlapSphere(probeT.position, 1.2) ?? const [];
      for (final e in _highlighted.toList()) {
        if (!inside.contains(e)) {
          _highlight(e, false);
          _highlighted.remove(e);
        }
      }
      for (final e in inside) {
        if (_highlighted.add(e)) _highlight(e, true);
      }
      final below = queries?.sphereCast(
        probeT.position,
        0.3,
        Vector3(0, 1, 0),
        maxDistance: 5,
      );
      _probeInfo =
          'overlaps ${inside.length}  ·  sphereCast down: '
          '${below == null ? '-' : '${below.distance.toStringAsFixed(2)} m to ${below.entity?.name}'}';
    };
  }

  void _highlight(Entity entity, bool on) {
    final shape = entity.isAlive ? entity.getComponent<Primitive3D>() : null;
    if (shape == null || shape.material.isNotEmpty) return;
    shape
      ..emission = on ? const Color(0xFF19E6FF) : const Color(0xFF000000)
      ..emissionStrength = on ? 1.5 : 1;
  }

  // ---------------------------------------------------------------------------
  // Pointer: orbit, zoom, tap
  // ---------------------------------------------------------------------------

  void _onPointerDown(PointerDownEvent e) {
    _lastPointer = e.localPosition;
    _downAt = e.localPosition;
    _dragged = 0;
  }

  void _onPointerMove(PointerMoveEvent e) {
    final last = _lastPointer;
    _lastPointer = e.localPosition;
    if (last == null || e.buttons == 0) return;
    final d = e.localPosition - last;
    _dragged += d.distance;
    final orbit = _orbit;
    if (orbit == null || _dragged < 4) return;
    orbit
      ..yaw += d.dx * 0.008
      ..pitch = (orbit.pitch - d.dy * 0.006).clamp(
        orbit.minPitch,
        orbit.maxPitch,
      );
  }

  void _onPointerUp(PointerUpEvent e) {
    final down = _downAt;
    _lastPointer = null;
    _downAt = null;
    if (down != null && _dragged < 6) _onTap(e.localPosition);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final orbit = _orbit;
      if (orbit == null || e is! PointerScrollEvent) return;
      final steps = -e.scrollDelta.dy / 100;
      orbit.distance = (orbit.distance * (1 - steps * 0.12)).clamp(
        orbit.minDistance,
        orbit.maxDistance,
      );
    });
  }

  /// A tap: the ray from the camera through it, into the physics world.
  void _onTap(Offset at) {
    final engine = _engine;
    if (engine == null) return;
    final ray = engine.cameraSystem.mainCamera.screenToWorldRay(at);
    final dir = ray.direction;
    final PhysicsHit3D? hit = _physics?.queries.raycast(
      ray.origin,
      dir,
      maxDistance: 300,
    );
    switch (_demo) {
      case _Demo.bodies:
        if (hit != null) {
          _dropAt(hit.point);
        } else if (dir.y.abs() > 1e-6) {
          // No physics here: drop where the ray meets the ground (y = 0).
          final t = -ray.origin.y / dir.y;
          if (t > 0) _dropAt(ray.origin + dir * t);
        }
      case _Demo.queries:
        final rigid = hit?.entity?.getComponent<RigidBody3D>();
        if (hit == null) {
          setState(() => _shotInfo = 'missed');
        } else if (rigid != null && rigid.bodyType == BodyType3D.dynamic) {
          rigid
            ..addImpulse(dir * (rigid.mass * 9))
            ..wakeUp();
          setState(
            () => _shotInfo =
                'shot ${hit.entity?.name} at ${hit.distance.toStringAsFixed(1)} m',
          );
        } else {
          setState(
            () => _shotInfo = 'hit ${hit.entity?.name ?? 'body'} (not dynamic)',
          );
        }
      case _Demo.character:
      case _Demo.joints:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------

  String get _statsLine {
    final engine = _engine;
    if (engine == null) return 'starting the 3-D engine…';
    final physics = engine.physics3D;
    final bodies = physics != null && physics.hasWorld
        ? physics.world.bodyCount
        : 0;
    return 'bodies $bodies  entities ${engine.world.entityCount}'
        '  contacts $_contacts  last: $_lastContact';
  }

  String get _statusMessage {
    if (_engine == null) return '';
    switch (_demo) {
      case _Demo.bodies:
        return 'Selected: ${_shape.label}  ·  restitution '
            '${_bouncy ? 0.65 : 0.1}  ·  ${_spawned.length} spawned';
      case _Demo.character:
        final body = _body;
        if (body == null) return '';
        final v = body.velocity;
        return 'ground: ${body.groundState.name}'
            '${body.groundEntity == null ? '' : ' (${body.groundEntity!.name})'}'
            '  ·  speed ${math.sqrt(v.x * v.x + v.z * v.z).toStringAsFixed(1)} m/s'
            '  ·  zone ${_inZone ? 'INSIDE' : 'outside'}, entered $_zoneEntries×';
      case _Demo.joints:
        final door = _door, piston = _piston;
        if (door == null || piston == null) return '';
        return 'door angle ${door.angle.toStringAsFixed(2)} rad  ·  piston '
            '${piston.position.toStringAsFixed(2)} m  ·  motor '
            '${_doorFree ? 'off' : (_doorOpen ? 'open' : 'closed')}';
      case _Demo.queries:
        return 'laser: $_laserInfo  ·  probe: $_probeInfo  ·  $_shotInfo';
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

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

  /// Why 3-D cannot be simulated or drawn here, or null.
  String? get _unsupported {
    final engine = _engine;
    if (engine == null) return null;
    final graphics = engine.graphics3D?.unsupportedReason;
    if (engine.physics3D == null) {
      return '3-D physics is not available here: '
          '${Physics3D.unsupportedReason ?? 'Physics3D is off'}';
    }
    if (graphics != null) return '3-D is not drawn here: $graphics';
    return null;
  }

  Widget _buildHeader() {
    final problem = _unsupported;
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
              const Flexible(
                child: Text(
                  'Physics3D (Jolt)  *  RigidBody3D  *  Collider3D  *  Joint3D',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF29B6F6), fontSize: 10),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
          if (problem != null) ...[
            const SizedBox(height: 3),
            Text(
              problem,
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    final engine = _engine;
    if (engine == null) {
      return ColoredBox(
        color: const Color(0xFF07070F),
        child: Center(
          child: _startError == null
              ? const CircularProgressIndicator(color: Color(0xFFF5746F))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'The 3-D engine could not start:\n$_startError',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFF8A80),
                      fontSize: 12,
                    ),
                  ),
                ),
        ),
      );
    }
    final problem = _unsupported;
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: (_) {
            _lastPointer = null;
            _downAt = null;
          },
          onPointerSignal: _onPointerSignal,
          child: GameWidget(engine: engine, showFPS: true),
        ),
        Positioned(
          left: 12,
          bottom: 10,
          child: IgnorePointer(
            child: Text(switch (_demo) {
              _Demo.bodies =>
                'Tap to drop  *  Drag to orbit  *  Scroll to zoom',
              _Demo.character =>
                'WASD / arrows  *  Space jump  *  Shift run  *  Drag to orbit',
              _Demo.joints => 'Drag to orbit  *  Scroll to zoom',
              _Demo.queries => 'Tap a body to shoot it  *  Drag to orbit',
            }, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        ),
        if (_demo == _Demo.character)
          Positioned(right: 12, bottom: 12, child: _buildPad()),
        if (problem != null)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFF8A80)),
                ),
                child: Text(
                  problem,
                  style: const TextStyle(
                    color: Color(0xFFFF8A80),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// On-screen controls for the character: hold an arrow to walk.
  Widget _buildPad() {
    Widget hold(IconData icon, _Dir dir) => Listener(
      onPointerDown: (_) => _held.add(dir),
      onPointerUp: (_) => _held.remove(dir),
      onPointerCancel: (_) => _held.remove(dir),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            hold(Icons.keyboard_arrow_up, _Dir.forward),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                hold(Icons.keyboard_arrow_left, _Dir.left),
                const SizedBox(width: 44),
                hold(Icons.keyboard_arrow_right, _Dir.right),
              ],
            ),
            const SizedBox(height: 4),
            hold(Icons.keyboard_arrow_down, _Dir.back),
          ],
        ),
        const SizedBox(width: 12),
        Listener(
          onPointerDown: (_) => _jumpQueued = true,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _demo.accentColor.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: _demo.accentColor),
            ),
            child: const Center(
              child: Text(
                'JUMP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
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
                  onSelected: _engine == null ? null : (_) => _buildDemo(d),
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: _engine == null ? const SizedBox(height: 8) : _buildDemoControls(),
    );
  }

  Widget _buildDemoControls() {
    final accent = _demo.accentColor;
    switch (_demo) {
      case _Demo.bodies:
        return Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final s in _Shape.values)
              _choice(s.label, _shape == s, () => setState(() => _shape = s)),
            _actionButton('Drop', accent, () {
              _spawnBody(
                _shape,
                Vector3(
                  _rng.nextDouble() * 4 - 2,
                  -7,
                  _rng.nextDouble() * 4 - 2,
                ),
              );
            }),
            _actionButton('Rain ×20', accent, () => _rain(20)),
            _toggle('Bouncy', _bouncy, (v) => setState(() => _bouncy = v)),
            _actionButton('Reset', accent, () => _buildDemo(_Demo.bodies)),
          ],
        );
      case _Demo.character:
        return Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _toggle('Run', _run, (v) => setState(() => _run = v)),
            _actionButton('Jump', accent, () => _jumpQueued = true),
            _actionButton('Respawn', accent, _respawnHero),
            _label(
              'Stairs and the jade ramp are walkable; the red ramp (51°) is '
              'too steep. The gold platform carries you.',
            ),
          ],
        );
      case _Demo.joints:
        return Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _actionButton(
              _doorOpen ? 'Close door' : 'Open door',
              accent,
              _toggleDoor,
            ),
            _actionButton('Free swing', accent, _freeDoor),
            _actionButton('Kick chain', accent, _kickChain),
            _actionButton('Drop welded L', accent, _dropWeld),
            _actionButton('Throw ball at door', accent, () {
              // Thrown from in front of the door, at it (+Z).
              _spawnBody(
                _Shape.sphere,
                Vector3(-3.6 + _rng.nextDouble() * 0.5, -1.4, -4),
                flash: false,
                velocity: Vector3(0, -2.5, 9),
              );
            }),
            _actionButton('Reset', accent, () => _buildDemo(_Demo.joints)),
          ],
        );
      case _Demo.queries:
        return Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _toggle(
              'Laser pushes',
              _laserPush,
              (v) => setState(() => _laserPush = v),
            ),
            _actionButton('Reset', accent, () => _buildDemo(_Demo.queries)),
            _label(
              'Physics3DQueries: raycast, raycastAll, overlapSphere, '
              'sphereCast',
            ),
          ],
        );
    }
  }

  // ── Small widgets ──────────────────────────────────────────────────────

  Widget _label(String text) =>
      Text(text, style: const TextStyle(color: Colors.white38, fontSize: 11));

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    final accent = _demo.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.2)
              : const Color(0xFF0E1A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.75)
                : const Color(0xFF1E2E40),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 30,
          child: FittedBox(
            child: Switch(
              value: value,
              activeTrackColor: _demo.accentColor.withValues(alpha: 0.6),
              onChanged: onChanged,
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
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
                  'just_game_engine  physics_3d.dart',
                  style: TextStyle(color: Colors.white24, fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              width: double.infinity,
              child: SingleChildScrollView(
                child: SelectableText(
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
