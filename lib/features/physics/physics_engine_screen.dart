import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/widgets.dart';

import '../../core/engine/demo_engine.dart';
import '../../core/widgets/common_tag.dart';

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
  layers,
  forces,
  springChain,
  carPhysics,
  characterBody;

  String get label => switch (this) {
    particleStorm => 'Particle Storm',
    gravityWarp => 'Gravity Warp',
    bounciness => 'Bounciness',
    shapeMixer => 'Shape Mixer',
    bodyStack => 'Body Stack',
    sensors => 'Sensors',
    queries => 'Queries',
    layers => 'Collision Layers',
    forces => 'Forces',
    springChain => 'Joints',
    carPhysics => 'Car Physics',
    characterBody => 'Character Body',
  };

  IconData get icon => switch (this) {
    particleStorm => Icons.bubble_chart,
    gravityWarp => Icons.swap_vert,
    bounciness => Icons.sports_tennis,
    shapeMixer => Icons.category,
    bodyStack => Icons.stacked_bar_chart,
    sensors => Icons.radar,
    queries => Icons.search,
    layers => Icons.layers,
    forces => Icons.air,
    springChain => Icons.link,
    carPhysics => Icons.directions_car,
    characterBody => Icons.directions_run,
  };

  Color get accentColor => switch (this) {
    particleStorm => const Color(0xFF29B6F6),
    gravityWarp => const Color(0xFF66BB6A),
    bounciness => const Color(0xFFFF7043),
    shapeMixer => const Color(0xFFAB47BC),
    bodyStack => const Color(0xFFFFCA28),
    sensors => const Color(0xFFFFD54F),
    queries => const Color(0xFFEF9A9A),
    layers => const Color(0xFF4DD0E1),
    forces => const Color(0xFFAED581),
    springChain => const Color(0xFFCE93D8),
    carPhysics => const Color(0xFF80CBC4),
    characterBody => const Color(0xFFF5746F),
  };

  /// Added with just_game_engine 2.x.
  bool get isNew => switch (this) {
    layers || forces || characterBody => true,
    _ => false,
  };

  String get description => switch (this) {
    particleStorm =>
      'Hundreds of RigidBody2D + Collider2D circles stepped by PhysicsSystem '
          '(native Box2D, pure Dart on the web). Tune ball count and initial '
          'speed to explore performance limits.',
    gravityWarp =>
      'engine.physics.setGravity() at run time — PhysicsSystem wakes every '
          'sleeping body when gravity changes, so all of them respond at once.',
    bounciness =>
      'RigidBody2D.restitution [0…1] controls the energy kept on impact. '
          'Six columns each drop a ball with a different restitution.',
    shapeMixer =>
      'Every Collider2D shape in one sandbox: circle, box, rounded box, '
          'polygon, capsule, and static segments and chains.',
    bodyStack =>
      'A tower of dynamic boxes resting on each other. Drop a 15 kg ball to '
          'topple it, or add more shapes.',
    sensors =>
      'A RigidBody2D(isSensor: true) reports overlaps and stops nothing. '
          'SensorEnter2DEvent / SensorExit2DEvent arrive on world.events.',
    queries =>
      'Physics2DQueries answers in entities: a rotating raycast and an '
          'overlapCircle zone highlight what they find every frame.',
    layers =>
      'Sixteen collision layers (0–15) with a collidesWith mask per body. '
          'Red balls rest on the red shelf, blue on the blue, ghosts pass '
          'through both. Set collidesWith = 0 to drop a shelf.',
    forces =>
      'Push bodies from code: addForce (wind), addImpulse (kick), setVelocity '
          '(launch), addAngularImpulse (spin) — applied at the next step.',
    springChain =>
      'Joints are components naming the other body with an EntityTarget: a '
          'springy DistanceJoint2D rope, a rigid FixedJoint2D beam, and a '
          'motorised SliderJoint2D piston.',
    carPhysics =>
      'A chassis on two WheelJoint2D suspensions with motors (Box2D on '
          'native, the Dart wheel joint on the web). Drive over the ramp with '
          '←/→ (A/D), brake with Space, or use the on-screen buttons.',
    characterBody =>
      'CharacterBody2D: a character gameplay moves (moveVelocity, jump) that '
          'walks slopes, climbs steps, jumps up through one-way platforms, '
          'rides moving platforms and pushes crates. ←/→ or A/D move, '
          'Space/W/↑ jumps.',
  };

  String get codeSnippet => switch (this) {
    particleStorm =>
      '// A dynamic body: RigidBody2D (how it moves) + Collider2D (its shape)\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(position: Vector3(x, y, 0)),\n'
          '  RigidBody2D(\n'
          '    mass: 1,\n'
          '    restitution: 0.94,\n'
          '    friction: 0.01,\n'
          '    linearDamping: 0.01,\n'
          '    initialVelocity: Offset(vx, vy),\n'
          '  ),\n'
          '  Collider2D(shape: ColliderShape2D.circle, radius: 6),\n'
          '  RenderableComponent(renderable: CircleRenderable(...)),\n'
          ']);\n\n'
          '// PhysicsSystem steps engine.physics and syncs the transforms:\n'
          'world.addSystem(PhysicsSystem(engine.physics, camera: camera));',
    gravityWarp =>
      '// Gravity lives on the physics engine; a change wakes\n'
          '// every sleeping body at the next step.\n'
          'engine.physics.setGravity(0, 98);   // ↓ down\n'
          'engine.physics.setGravity(0, -98);  // ↑ up\n'
          'engine.physics.setGravity(-98, 0);  // ← left\n'
          'engine.physics.setGravity(98, 0);   // → right\n'
          'engine.physics.setGravity(0, 0);    // zero-g\n\n'
          '// Per body: float, or fall twice as hard\n'
          'RigidBody2D(gravityScale: 0);\n'
          'RigidBody2D(gravityScale: 2);',
    bounciness =>
      '// restitution 0 = no bounce (the 2.x default)\n'
          '// restitution 1 = keeps all of its energy\n'
          'RigidBody2D(\n'
          '  mass: 1,\n'
          '  restitution: 0.8,   // ← tune this\n'
          '  friction: 0,\n'
          '  linearDamping: 0,\n'
          '),\n'
          'Collider2D(shape: ColliderShape2D.circle, radius: 14),\n\n'
          '// A Collider2D alone is a static body; add a static\n'
          '// RigidBody2D to give it a material:\n'
          'RigidBody2D(bodyType: BodyType.static, restitution: 1),\n'
          'Collider2D(size: Vector2(width, 24)),',
    shapeMixer =>
      'Collider2D(shape: ColliderShape2D.circle, radius: 10)\n'
          'Collider2D(size: Vector2(28, 20))                 // box\n'
          'Collider2D(size: Vector2(44, 32), cornerRadius: 6)\n'
          'Collider2D(shape: ColliderShape2D.polygon, points: triangle)\n'
          'Collider2D(shape: ColliderShape2D.capsule, radius: 9, height: 54)\n'
          'Collider2D(\n'
          '  shape: ColliderShape2D.segment,\n'
          '  points: [Offset(-55, 0), Offset(55, -25)],\n'
          '  thickness: 3,\n'
          ')\n'
          'Collider2D(shape: ColliderShape2D.chain, points: wave, thickness: 3)\n'
          '// …or whatever the entity draws, kept in step:\n'
          'Collider2D(shape: ColliderShape2D.matchShape)',
    bodyStack =>
      '// A block: mass 0 would work it out from the area\n'
          '// (PhysicsSystem.autoMassPerSquareUnit, 0.1 kg per unit²)\n'
          'RigidBody2D(mass: 2, friction: 0.6, restitution: 0.1),\n'
          'Collider2D(size: Vector2(58, 26)),\n\n'
          '// The wrecking ball:\n'
          'RigidBody2D(mass: 15, restitution: 0.3, friction: 0.3),\n'
          'Collider2D(shape: ColliderShape2D.circle, radius: 20),\n\n'
          '// Read back after each step:\n'
          'rigid.linearVelocity; rigid.isAwake; rigid.isGrounded;',
    sensors =>
      '// A sensor reports overlaps and stops nothing:\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(),\n'
          '  RigidBody2D(bodyType: BodyType.static, isSensor: true),\n'
          '  Collider2D(shape: ColliderShape2D.circle, radius: 80),\n'
          '], name: \'Zone\');\n\n'
          'final enter = world.events.on<SensorEnter2DEvent>((e) {\n'
          '  debugPrint(\'\${e.other.name} entered \${e.sensor.name}\');\n'
          '});\n'
          'final exit = world.events.on<SensorExit2DEvent>((e) { ... });\n'
          '// Collisions: CollisionEnter2DEvent / CollisionExit2DEvent\n\n'
          '// dispose():\n'
          'enter.cancel();\n'
          'exit.cancel();',
    queries =>
      'final queries = Physics2DQueries(\n'
          '  engine.physics,\n'
          '  world.getSystem<PhysicsSystem>()!,\n'
          ');\n\n'
          '// First hit along a ray, as an entity:\n'
          'final hit = queries.raycast(Offset.zero, dir, maxDistance: 400);\n'
          'debugPrint(\'\${hit?.entity?.name} at \${hit?.point}\');\n\n'
          '// Everything a ray crosses, nearest first:\n'
          'final hits = queries.raycastAll(Offset.zero, dir);\n\n'
          '// Overlaps and sweeps, filtered by layer (bit n = layer n):\n'
          'final inZone = queries.overlapCircle(const Offset(0, 60), 60);\n'
          'final inBox = queries.overlapBox(rect, layerMask: 1 << 2);\n'
          'final swept = queries.circleCast(origin, 8, dir);',
    layers =>
      '// Layers 0–15; collidesWith is a mask (bit n = layer n).\n'
          '// Two bodies collide only if each accepts the other\'s layer.\n'
          'RigidBody2D(layer: 1, collidesWith: 1 << 0 | 1 << 1), // red\n'
          'RigidBody2D(layer: 2, collidesWith: 1 << 0 | 1 << 2), // blue\n'
          'RigidBody2D(layer: 3, collidesWith: 1 << 0),          // ghost\n\n'
          '// A shelf only the red layer stands on:\n'
          'RigidBody2D(\n'
          '  bodyType: BodyType.static,\n'
          '  layer: 1,\n'
          '  collidesWith: 1 << 1,\n'
          '),\n\n'
          '// Collide with nothing for a while (a crumbling floor):\n'
          'shelf.collidesWith = 0;   // null = the project\'s grid\n\n'
          '// Names and grid: assets/project/physics.json\n'
          'final layers = engine.context.physicsLayers;\n'
          'layers.nameOf(1); layers.collides(1, 2);',
    forces =>
      'final body = entity.getComponent<RigidBody2D>()!;\n\n'
          '// Each applies at the next physics step:\n'
          'body.addForce(const Offset(700, 0));     // this step (wind)\n'
          'body.addImpulse(const Offset(0, -700));  // instant kick\n'
          'body.setVelocity(const Offset(0, -500)); // launch\n'
          'body.addAngularImpulse(1500);            // spin\n'
          'body.addTorque(200);\n'
          'body.setAngularVelocity(0);\n'
          'body.wakeUp();\n\n'
          '// Read back after the step:\n'
          'body.linearVelocity; body.angularVelocity; body.isGrounded;',
    springChain =>
      '// A joint sits on one body\'s entity and names the other\n'
          '// with an EntityTarget (a name, a tag or self).\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(position: Vector3(x, y, 0)),\n'
          '  RigidBody2D(mass: 1),\n'
          '  Collider2D(shape: ColliderShape2D.circle, radius: 8),\n'
          '  DistanceJoint2D(\n'
          '    connectedBody: EntityTarget.name(\'Rope 2\'),\n'
          '    length: 40,\n'
          '    stiffness: 5,   // spring in Hz (0 = rigid)\n'
          '    damping: 0.2,   // damping ratio\n'
          '  ),\n'
          '], name: \'Rope 3\');\n\n'
          'FixedJoint2D(connectedBody: const EntityTarget.name(\'Beam 0\'));\n'
          'SliderJoint2D(\n'
          '  connectedBody: const EntityTarget.name(\'Rail\'),\n'
          '  axis: const Offset(1, 0),\n'
          '  useLimits: true, minPosition: -80, maxPosition: 80,\n'
          '  enableMotor: true, motorSpeed: 60, motorMaxForce: 4000,\n'
          ');',
    carPhysics =>
      '// One WheelJoint2D per entity: the chassis holds the rear wheel,\n'
          '// the cabin (welded on with a FixedJoint2D) the front one.\n'
          'RigidBody2D(mass: 6, groupIndex: -7), // car parts never touch\n'
          'Collider2D(size: Vector2(64, 18)),\n'
          'WheelJoint2D(\n'
          '  connectedBody: const EntityTarget.name(\'Rear Wheel\'),\n'
          '  axis: const Offset(0, 1),  // suspension, chassis space\n'
          '  stiffness: 45,             // Hz\n'
          '  damping: 0.65,             // ratio\n'
          '  enableMotor: true,\n'
          '  motorSpeed: 200,           // rad/s\n'
          '  motorMaxTorque: 400,\n'
          '),\n\n'
          '// Drive: change the motor (the joint is made again)\n'
          'wheel.motorSpeed = right ? 200 : -200;',
    characterBody =>
      '// Moved by gameplay, not the simulation:\n'
          'final hero = CharacterBody2D(\n'
          '  radius: 14, height: 44,   // capsule\n'
          '  maxSlopeAngle: 0.87,      // ~50°\n'
          '  stepHeight: 12,           // climbs steps\n'
          '  stickToFloor: 10,         // hugs the floor going down\n'
          ');\n'
          'world.createEntityWithComponents(\n'
          '  [TransformComponent(position: Vector3(x, y, 0)), hero],\n'
          '  name: \'Hero\',\n'
          ');\n\n'
          '// Each step, before PhysicsSystem:\n'
          'hero.moveVelocity = Offset(dir * 240, 0);\n'
          'if (jumpPressed && hero.isGrounded) hero.jump(560);\n\n'
          '// Platforms it understands:\n'
          'Collider2D(size: Vector2(160, 10), oneWay: true);\n'
          'RigidBody2D(bodyType: BodyType.kinematic); // + VelocityComponent\n'
          'hero.groundEntity; hero.groundNormal; hero.velocity;',
  };
}

/// Runs a callback every fixed update of the world, before
/// [PhysicsSystem] — where gameplay steers bodies and characters.
/// `DemoEngine.reset` removes it with the demo.
class _DemoDriver extends System {
  _DemoDriver(this.onStep) {
    priority = SystemPriorities.playerControl;
  }

  final void Function(double dt) onStep;

  @override
  List<Type> get requiredComponents => const [];

  @override
  void update(double deltaTime) => onStep(deltaTime);
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
  // ── Engine (the app's shared, already running 2-D engine) ───────────────
  late final Engine _engine = demoEngine;
  late final World _world = _engine.world;
  late final Ticker _ticker;
  final GlobalKey _canvasKey = GlobalKey();
  final List<EventSubscription> _subscriptions = [];

  // ── State ────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.particleStorm;
  String _statusMessage = '';
  bool _showColliderDebug = false;
  String _backend = '';
  int _collisionEnters = 0;

  // ── Particle Storm settings ───────────────────────────────────────────────
  int _ballCount = 200;
  double _initialVelocity = 220;
  bool _gravityEnabled = true;

  // ── Sensor demo state ────────────────────────────────────────────────────
  Entity? _sensorEntity;
  final Set<Entity> _insideSensor = {};
  final List<String> _sensorLog = [];
  static const _kMaxSensorLog = 6;

  // ── Queries demo state ───────────────────────────────────────────────────
  Physics2DQueries? _queries;
  PhysicsHit2D? _queryRayHit;
  List<Entity> _queryOverlap = const [];
  double _queryRayAngle = 0.0;

  // ── Layers demo state ────────────────────────────────────────────────────
  static const _kLayerNames = ['World', 'Red', 'Blue', 'Ghost'];
  static const _kLayerColors = [
    Color(0xFF3D6A8A),
    Color(0xFFEF5350),
    Color(0xFF42A5F5),
    Color(0xFFB0BEC5),
  ];
  RigidBody2D? _redShelf;
  RigidBody2D? _blueShelf;

  // ── Forces demo state ────────────────────────────────────────────────────
  final List<RigidBody2D> _forceBodies = [];
  bool _windOn = false;
  static const _kWindForce = 700.0;

  // ── Joints demo state ────────────────────────────────────────────────────
  final List<Entity> _ropeEntities = [];
  SliderJoint2D? _slider;
  TransformComponent? _pistonTransform;
  double _railX = 0;
  static const _kPistonTravel = 80.0;

  // ── Car Physics demo state ───────────────────────────────────────────────
  bool _carLeft = false;
  bool _carRight = false;
  bool _carBrake = false;
  RigidBody2D? _carChassis;
  WheelJoint2D? _carRearJoint;
  WheelJoint2D? _carFrontJoint;
  double _carMotorSpeed = 200.0;
  double _carMaxTorque = 400.0;

  // ── Character demo state ─────────────────────────────────────────────────
  CharacterBody2D? _hero;
  Entity? _heroEntity;
  Entity? _goalEntity;
  VelocityComponent? _platformVelocity;
  TransformComponent? _platformTransform;
  double _platformMinX = 0;
  double _platformMaxX = 0;
  bool _padLeft = false;
  bool _padRight = false;
  bool _padJump = false;
  bool _jumpWasDown = false;
  double _heroFacing = 1;
  int _goalHits = 0;
  static const _kHeroSpeed = 240.0;
  static const _kHeroJump = 560.0;
  static const _kHeroGravity = 1200.0;
  static const _kPlatformSpeed = 80.0;

  final FocusNode _focusNode = FocusNode();
  final math.Random _random = math.Random();
  Size _arenaSize = const Size(800, 500);

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // The world outlives the demos, so the events are listened to once.
    _subscriptions
      ..add(_world.events.on<SensorEnter2DEvent>(_onSensorEnter))
      ..add(_world.events.on<SensorExit2DEvent>(_onSensorExit))
      ..add(
        _world.events.on<CollisionEnter2DEvent>((_) => _collisionEnters++),
      );
    // Only for the live HUD: the engine's own loop steps the world.
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buildDemo(_demo);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    // Leaves the shared engine clean and running for the next screen.
    DemoEngine.reset(_engine);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Events
  // ─────────────────────────────────────────────────────────────────────────

  static String _nameOf(Entity e) => '${e.name ?? 'entity'}#${e.id}';

  void _onSensorEnter(SensorEnter2DEvent e) {
    if (_demo == _Demo.sensors && identical(e.sensor, _sensorEntity)) {
      _insideSensor.add(e.other);
      _sensorLog.insert(0, 'ENTER  ${_nameOf(e.other)}');
      if (_sensorLog.length > _kMaxSensorLog) _sensorLog.removeLast();
    } else if (_demo == _Demo.characterBody &&
        identical(e.sensor, _goalEntity) &&
        identical(e.other, _heroEntity)) {
      _goalHits++;
      _statusMessage = 'Goal reached ×$_goalHits  (SensorEnter2DEvent)';
    }
  }

  void _onSensorExit(SensorExit2DEvent e) {
    if (_demo != _Demo.sensors || !identical(e.sensor, _sensorEntity)) return;
    _insideSensor.remove(e.other);
    _sensorLog.insert(0, 'EXIT   ${_nameOf(e.other)}');
    if (_sensorLog.length > _kMaxSensorLog) _sensorLog.removeLast();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tick (HUD only) and fixed-step driver
  // ─────────────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (_demo == _Demo.queries) _updateQueries();
    if (mounted) setState(() {});
  }

  /// Runs inside the engine's fixed update, before physics.
  void _onFixedStep(double dt) {
    switch (_demo) {
      case _Demo.forces:
        _applyWind();
      case _Demo.springChain:
        _drivePiston();
      case _Demo.carPhysics:
        _driveCar();
      case _Demo.characterBody:
        _driveCharacter();
      default:
        break;
    }
  }

  void _updateQueries() {
    final queries = _queries;
    if (queries == null) return;
    // Engine time stands still while the engine is paused.
    _queryRayAngle = _engine.time.totalTime * (math.pi / 3.0);
    final dir = Offset(math.cos(_queryRayAngle), math.sin(_queryRayAngle));
    _queryRayHit = queries.raycast(
      Offset.zero,
      dir,
      maxDistance: _halfW * 0.9,
    );
    _queryOverlap = queries.overlapCircle(const Offset(0, 60), 60.0);
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

  void _buildDemo(_Demo demo) {
    _demo = demo;
    _statusMessage = '';
    _collisionEnters = 0;
    _refreshArenaSize();

    // A clean world: entities, demo systems and stray bodies go; camera,
    // gravity and time scale are reset; the engine runs again if paused.
    DemoEngine.reset(
      _engine,
      include: {DefaultSystem.rendering, DefaultSystem.physics},
    );
    _world.addSystem(_DemoDriver(_onFixedStep));
    _applyColliderDebug();
    _backend = _engine.physics.stats['backend'] == 'box2d_v3'
        ? 'Box2D'
        : 'pure Dart';
    _engine.physics.setGravity(0, 98);

    _queries = null;
    _queryRayHit = null;
    _queryOverlap = const [];
    _sensorEntity = null;
    _insideSensor.clear();
    _sensorLog.clear();
    _redShelf = null;
    _blueShelf = null;
    _forceBodies.clear();
    _windOn = false;
    _ropeEntities.clear();
    _slider = null;
    _pistonTransform = null;
    _carLeft = _carRight = _carBrake = false;
    _carChassis = null;
    _carRearJoint = null;
    _carFrontJoint = null;
    _hero = null;
    _heroEntity = null;
    _goalEntity = null;
    _platformVelocity = null;
    _platformTransform = null;
    _padLeft = _padRight = _padJump = false;
    _jumpWasDown = false;
    _goalHits = 0;

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
        _buildSensorsDemo();
      case _Demo.queries:
        _buildQueriesDemo();
      case _Demo.layers:
        _buildLayersDemo();
      case _Demo.forces:
        _buildForcesDemo();
      case _Demo.springChain:
        _buildSpringChainDemo();
      case _Demo.carPhysics:
        _buildCarPhysicsDemo();
      case _Demo.characterBody:
        _buildCharacterDemo();
    }
    _focusNode.requestFocus();
    if (mounted) setState(() {});
  }

  /// Collider outlines are PhysicsSystem's own switch (debug builds only).
  void _applyColliderDebug() {
    _world.getSystem<PhysicsSystem>()?.drawsOutlines = _showColliderDebug;
  }

  /// One entity: a transform, an optional rigid body (none = static), a
  /// collider and what it looks like.
  Entity _spawn({
    required Offset at,
    required Collider2D collider,
    RigidBody2D? rigid,
    Renderable? look,
    double angle = 0,
    String? name,
    List<Component> extra = const [],
  }) {
    return _world.createEntityWithComponents([
      TransformComponent(position: Vector3(at.dx, at.dy, 0), angle: angle),
      ?rigid,
      collider,
      if (look != null) RenderableComponent(renderable: look),
      ...extra,
    ], name: name);
  }

  static RigidBody2D _staticBody({
    double restitution = 0,
    double friction = 0.5,
    int layer = 0,
    int? collidesWith,
  }) => RigidBody2D(
    bodyType: BodyType.static,
    restitution: restitution,
    friction: friction,
    layer: layer,
    collidesWith: collidesWith,
  );

  static Collider2D _circle(double r) =>
      Collider2D(shape: ColliderShape2D.circle, radius: r);

  static Collider2D _box(double w, double h) => Collider2D(size: Vector2(w, h));

  /// Every dynamic body in the world.
  Iterable<RigidBody2D> get _dynamicBodies sync* {
    for (final e in _world.entities) {
      final rigid = e.getComponent<RigidBody2D>();
      if (rigid != null && rigid.isDynamic) yield rigid;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Arena walls (viewport-relative helper)
  // ─────────────────────────────────────────────────────────────────────────

  double get _halfW => (_arenaSize.width - 50) / 2;
  double get _halfH => (_arenaSize.height - 50) / 2;
  static const _kThick = 24.0;

  void _createWalls({
    double restitution = 0.96,
    double friction = 0.02,
    bool ceiling = true,
  }) {
    final hw = _halfW;
    final hh = _halfH;
    final wallDefs = <({Offset pos, Size size})>[
      (
        pos: Offset(0, hh + _kThick / 2),
        size: Size(hw * 2 + _kThick * 2, _kThick),
      ),
      if (ceiling)
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
      _spawn(
        at: w.pos,
        rigid: _staticBody(restitution: restitution, friction: friction),
        collider: _box(w.size.width, w.size.height),
        look: RectangleRenderable(
          size: w.size,
          fillColor: const Color(0xFF1A2E44),
          strokeColor: const Color(0xFF3D6A8A),
          strokeWidth: 1.5,
          layer: 1,
        ),
        name: 'Wall',
      );
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
      _spawn(
        at: Offset(x, y),
        rigid: RigidBody2D(
          mass: 1.0,
          restitution: 0.94,
          friction: 0.01,
          linearDamping: 0.01,
          initialVelocity: Offset(vx, vy),
        ),
        collider: _circle(r),
        look: CircleRenderable(
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
        name: 'Ball',
      );
    }
  }

  void _setParticleGravity(bool enabled) {
    setState(() {
      _gravityEnabled = enabled;
      // PhysicsSystem wakes every body when gravity changes.
      _engine.physics.setGravity(0, enabled ? 98 : 0);
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
      _spawn(
        at: Offset(x, y),
        rigid: RigidBody2D(
          mass: 1.0,
          restitution: 0.88,
          friction: 0.01,
          linearDamping: 0.003,
          initialVelocity: Offset(
            (_random.nextDouble() * 2 - 1) * 80,
            (_random.nextDouble() * 2 - 1) * 80,
          ),
        ),
        collider: _circle(9.0),
        look: CircleRenderable(
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
        name: 'Ball',
      );
    }
    _statusMessage = 'Tap a direction to warp gravity';
  }

  void _warpGravity(double gx, double gy, String label) {
    _engine.physics.setGravity(gx, gy);
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
    // Floor + side walls only (no ceiling — let bouncy balls fly up). The
    // floor is perfectly elastic so each ball's restitution decides.
    _createWalls(restitution: 1.0, friction: 0, ceiling: false);
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
      _spawn(
        at: Offset(x, -_halfH * 0.75),
        rigid: RigidBody2D(
          mass: 1.0,
          restitution: rest,
          friction: 0.0,
          linearDamping: 0.0,
          angularDamping: 0.0,
        ),
        collider: _circle(14.0),
        look: CustomRenderable(
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
        name: 'Ball e=${rest.toStringAsFixed(1)}',
      );
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
    _statusMessage = 'Every Collider2D shape in one collision sandbox';
  }

  void _addShape(int type) {
    final hw = _halfW - 20.0;
    final hh = _halfH - 20.0;
    final at = Offset(
      (_random.nextDouble() * 2 - 1) * hw,
      (_random.nextDouble() * 2 - 1) * hh,
    );
    final velocity = Offset(
      (_random.nextDouble() * 2 - 1) * 120,
      (_random.nextDouble() * 2 - 1) * 120,
    );
    final color = Color.lerp(
      const Color(0xFFAB47BC),
      const Color(0xFF29B6F6),
      _random.nextDouble(),
    )!;

    switch (type) {
      case 0: // Circle
        const r = 10.0;
        _spawn(
          at: at,
          rigid: RigidBody2D(
            mass: 1.0,
            restitution: 0.75,
            friction: 0.1,
            linearDamping: 0.005,
            initialVelocity: velocity,
          ),
          collider: _circle(r),
          look: CircleRenderable(
            radius: r,
            fillColor: color,
            strokeColor: Colors.white.withValues(alpha: 0.4),
            strokeWidth: 1.2,
            layer: 5,
          ),
          name: 'Circle',
        );

      case 1: // Box
        const w = 28.0, h = 20.0;
        _spawn(
          at: at,
          rigid: RigidBody2D(
            mass: 1.5,
            restitution: 0.6,
            friction: 0.2,
            linearDamping: 0.01,
            initialVelocity: velocity,
          ),
          collider: _box(w, h),
          look: RectangleRenderable(
            size: const Size(w, h),
            fillColor: color,
            strokeColor: Colors.white.withValues(alpha: 0.4),
            strokeWidth: 1.2,
            layer: 5,
          ),
          name: 'Box',
        );

      case 2: // Triangle polygon
        const r = 14.0;
        const verts = [Offset(0, -r), Offset(r, r * 0.7), Offset(-r, r * 0.7)];
        _spawn(
          at: at,
          rigid: RigidBody2D(
            mass: 1.2,
            restitution: 0.7,
            friction: 0.15,
            linearDamping: 0.008,
            initialVelocity: velocity,
          ),
          collider: Collider2D(
            shape: ColliderShape2D.polygon,
            points: verts,
          ),
          look: CustomRenderable(
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
          name: 'Triangle',
        );
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
        _spawn(
          at: Offset(x, y),
          rigid: RigidBody2D(
            mass: 2.0,
            restitution: 0.1,
            friction: 0.6,
            linearDamping: 0.02,
          ),
          collider: _box(blockW, blockH),
          look: RectangleRenderable(
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
          name: 'Block $row.$col',
        );
      }
    }
  }

  void _dropHeavyBall() {
    const r = 20.0;
    final spawnY = -_halfH + r + 10;
    _spawn(
      at: Offset((_random.nextDouble() * 2 - 1) * 20, spawnY),
      rigid: RigidBody2D(
        mass: 15.0,
        restitution: 0.3,
        friction: 0.3,
        linearDamping: 0.01,
      ),
      collider: _circle(r),
      look: CircleRenderable(
        radius: r,
        fillColor: const Color(0xFFFF5252),
        strokeColor: Colors.white.withValues(alpha: 0.6),
        strokeWidth: 2,
        layer: 10,
      ),
      name: 'Wrecking Ball',
    );
    setState(() => _statusMessage = 'Heavy ball dropped!');
  }

  void _addNewShape(int type) {
    final hw = _halfW - 30.0;
    final hh = _halfH - 30.0;
    final at = Offset(
      (_random.nextDouble() * 2 - 1) * hw,
      (_random.nextDouble() * 2 - 1) * (hh * 0.7) - hh * 0.1,
    );
    final velocity = Offset(
      (_random.nextDouble() * 2 - 1) * 100,
      (_random.nextDouble() * 2 - 1) * 100,
    );
    final color = Color.lerp(
      const Color(0xFF26C6DA),
      const Color(0xFF66BB6A),
      _random.nextDouble(),
    )!;

    switch (type) {
      case 0: // Capsule (along Y, 54 tall overall)
        const halfH = 18.0, r = 9.0;
        _spawn(
          at: at,
          rigid: RigidBody2D(
            mass: 1.2,
            restitution: 0.6,
            friction: 0.1,
            linearDamping: 0.008,
            initialVelocity: velocity,
          ),
          collider: Collider2D(
            shape: ColliderShape2D.capsule,
            radius: r,
            height: halfH * 2 + r * 2,
          ),
          look: CustomRenderable(
            layer: 5,
            getBoundsCallback: () => Rect.fromCenter(
              center: Offset.zero,
              width: r * 2 + 4,
              height: halfH * 2 + r * 2 + 4,
            ),
            onRender: (canvas, _) {
              final rrect = RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset.zero,
                  width: r * 2,
                  height: halfH * 2 + r * 2,
                ),
                const Radius.circular(r),
              );
              canvas.drawRRect(rrect, Paint()..color = color);
              canvas.drawRRect(
                rrect,
                Paint()
                  ..color = Colors.white.withValues(alpha: 0.35)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.2,
              );
            },
          ),
          name: 'Capsule',
        );

      case 1: // Diagonal segment (static ramp)
        const p1 = Offset(-55, 0);
        const p2 = Offset(55, -25);
        const thickness = 3.0;
        _spawn(
          at: at,
          rigid: _staticBody(restitution: 0.5, friction: 0.3),
          collider: Collider2D(
            shape: ColliderShape2D.segment,
            points: const [p1, p2],
            thickness: thickness,
          ),
          look: CustomRenderable(
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
          name: 'Segment',
        );

      case 2: // Chain (wave terrain, static)
        const chainVerts = [
          Offset(-70, 10),
          Offset(-35, -20),
          Offset(0, 10),
          Offset(35, -20),
          Offset(70, 10),
        ];
        _spawn(
          at: at,
          rigid: _staticBody(restitution: 0.5, friction: 0.2),
          collider: Collider2D(
            shape: ColliderShape2D.chain,
            points: chainVerts,
            thickness: 3.0,
          ),
          look: CustomRenderable(
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
          name: 'Chain',
        );

      case 3: // Box with rounded corners
        const hw2 = 22.0, hh2 = 16.0, cr = 6.0;
        _spawn(
          at: at,
          rigid: RigidBody2D(
            mass: 1.4,
            restitution: 0.65,
            friction: 0.15,
            linearDamping: 0.01,
            initialVelocity: velocity,
          ),
          collider: Collider2D(
            size: Vector2(hw2 * 2, hh2 * 2),
            cornerRadius: cr,
          ),
          look: CustomRenderable(
            layer: 5,
            getBoundsCallback: () => Rect.fromCenter(
              center: Offset.zero,
              width: hw2 * 2 + 4,
              height: hh2 * 2 + 4,
            ),
            onRender: (canvas, _) {
              final rrect = RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset.zero,
                  width: hw2 * 2,
                  height: hh2 * 2,
                ),
                const Radius.circular(cr),
              );
              canvas.drawRRect(rrect, Paint()..color = color);
              canvas.drawRRect(
                rrect,
                Paint()
                  ..color = Colors.white.withValues(alpha: 0.3)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.2,
              );
            },
          ),
          name: 'Rounded Box',
        );

      case 4: // Small circle (for cross-shape collisions)
        const r = 9.0;
        _spawn(
          at: at,
          rigid: RigidBody2D(
            mass: 0.8,
            restitution: 0.7,
            friction: 0.05,
            linearDamping: 0.005,
            initialVelocity: velocity,
          ),
          collider: _circle(r),
          look: CircleRenderable(
            radius: r,
            fillColor: Colors.white.withValues(alpha: 0.55),
            strokeColor: Colors.white.withValues(alpha: 0.3),
            strokeWidth: 1,
            layer: 5,
          ),
          name: 'Ball',
        );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Sensors
  // ─────────────────────────────────────────────────────────────────────────

  void _buildSensorsDemo() {
    _engine.physics.setGravity(0, 120);
    _createWalls(restitution: 0.6);

    // A large static circular sensor in the centre.
    _sensorEntity = _spawn(
      at: Offset.zero,
      rigid: RigidBody2D(bodyType: BodyType.static, isSensor: true),
      collider: _circle(80.0),
      look: CustomRenderable(
        layer: 3,
        getBoundsCallback: () =>
            Rect.fromCircle(center: Offset.zero, radius: 82),
        onRender: (canvas, _) {
          final occupied = _insideSensor.isNotEmpty;
          canvas.drawCircle(
            Offset.zero,
            80,
            Paint()
              ..color = const Color(
                0xFFFFD54F,
              ).withValues(alpha: occupied ? 0.28 : 0.12),
          );
          canvas.drawCircle(
            Offset.zero,
            80,
            Paint()
              ..color = const Color(0xFFFFD54F).withValues(alpha: 0.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = occupied ? 3 : 2,
          );
        },
      ),
      name: 'Sensor Zone',
    );

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
    _spawn(
      at: Offset(x, spawnY),
      rigid: RigidBody2D(
        mass: 1.0,
        restitution: 0.75,
        friction: 0.05,
        linearDamping: 0.005,
        initialVelocity: Offset((_random.nextDouble() * 2 - 1) * 80, 0),
      ),
      collider: _circle(r),
      look: CircleRenderable(
        radius: r,
        fillColor: Color.lerp(
          const Color(0xFF29B6F6),
          const Color(0xFFAB47BC),
          _random.nextDouble(),
        )!,
        strokeColor: Colors.white.withValues(alpha: 0.4),
        strokeWidth: 1.2,
        layer: 5,
      ),
      name: 'Ball',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Queries
  // ─────────────────────────────────────────────────────────────────────────

  void _buildQueriesDemo() {
    _engine.physics.setGravity(0, 100);
    _createWalls(restitution: 0.7);
    for (int i = 0; i < 18; i++) {
      _addQueriesBody();
    }
    _queries = Physics2DQueries(
      _engine.physics,
      _world.getSystem<PhysicsSystem>()!,
    );

    // What the queries found, drawn over the world (in world space).
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 20,
          getBoundsCallback: () => Rect.fromCenter(
            center: Offset.zero,
            width: _halfW * 2 + 100,
            height: _halfH * 2 + 100,
          ),
          onRender: (canvas, _) => _paintQueries(canvas),
        ),
      ),
    ], name: 'Query Overlay');
    _statusMessage = 'Rotating raycast + overlapCircle zone active';
  }

  void _paintQueries(Canvas canvas) {
    const accent = Color(0xFFEF9A9A);
    final dir = Offset(math.cos(_queryRayAngle), math.sin(_queryRayAngle));
    final hit = _queryRayHit;
    final end = hit?.point ?? dir * (_halfW * 0.9);
    canvas.drawLine(
      Offset.zero,
      end,
      Paint()
        ..color = accent.withValues(alpha: 0.9)
        ..strokeWidth = 2,
    );
    if (hit != null) {
      canvas.drawCircle(hit.point, 5, Paint()..color = Colors.white);
      canvas.drawLine(
        hit.point,
        hit.point + hit.normal * 18,
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 1.5,
      );
    }
    canvas.drawCircle(
      const Offset(0, 60),
      60,
      Paint()
        ..color = accent.withValues(alpha: _queryOverlap.isEmpty ? 0.08 : 0.2),
    );
    canvas.drawCircle(
      const Offset(0, 60),
      60,
      Paint()
        ..color = accent.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final e in _queryOverlap) {
      final t = e.getComponent<TransformComponent>();
      final c = e.getComponent<Collider2D>();
      if (t == null || c == null) continue;
      canvas.drawCircle(
        Offset(t.position.x, t.position.y),
        c.radius + 3,
        ring,
      );
    }
  }

  void _addQueriesBody() {
    final hw = _halfW - 20.0;
    final hh = _halfH - 20.0;
    final x = (_random.nextDouble() * 2 - 1) * hw;
    final y = (_random.nextDouble() * 2 - 1) * hh * 0.6;
    final r = 8.0 + _random.nextDouble() * 8;
    _spawn(
      at: Offset(x, y),
      rigid: RigidBody2D(
        mass: 1.0,
        restitution: 0.6,
        friction: 0.05,
        linearDamping: 0.005,
        initialVelocity: Offset(
          (_random.nextDouble() * 2 - 1) * 80,
          (_random.nextDouble() * 2 - 1) * 80,
        ),
      ),
      collider: _circle(r),
      look: CircleRenderable(
        radius: r,
        fillColor: const Color(0xFFEF9A9A).withValues(alpha: 0.7),
        strokeColor: Colors.white.withValues(alpha: 0.3),
        strokeWidth: 1,
        layer: 5,
      ),
      name: 'Target',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Collision Layers
  // ─────────────────────────────────────────────────────────────────────────

  void _buildLayersDemo() {
    _engine.physics.setGravity(0, 200);
    // Walls: layer 0 ('World'), colliding with every layer.
    _createWalls(restitution: 0.3, friction: 0.3);

    final hw = _halfW, hh = _halfH;
    final shelfW = hw * 1.3;
    // Blue shelf above, red shelf below: red balls fall through the blue.
    Entity shelf(int layer, double y) => _spawn(
      at: Offset(0, y),
      rigid: _staticBody(
        friction: 0.4,
        restitution: 0.2,
        layer: layer,
        collidesWith: 1 << layer, // only its own colour
      ),
      collider: _box(shelfW, 10),
      look: CustomRenderable(
        layer: 3,
        getBoundsCallback: () =>
            Rect.fromCenter(center: Offset.zero, width: shelfW, height: 14),
        onRender: (canvas, _) {
          final rigid = layer == 1 ? _redShelf : _blueShelf;
          final solid = rigid?.collidesWith != 0;
          final color = _kLayerColors[layer];
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: shelfW,
            height: 10,
          );
          canvas.drawRect(
            rect,
            Paint()..color = color.withValues(alpha: solid ? 0.85 : 0.18),
          );
          canvas.drawRect(
            rect,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        },
      ),
      name: '${_kLayerNames[layer]} Shelf',
    );
    _blueShelf = shelf(2, -hh * 0.2).getComponent<RigidBody2D>();
    _redShelf = shelf(1, hh * 0.35).getComponent<RigidBody2D>();

    for (var i = 0; i < 6; i++) {
      _addLayerBall(1);
      _addLayerBall(2);
      if (i.isEven) _addLayerBall(3);
    }
    _statusMessage =
        'Red (layer 1) and Blue (layer 2) stop on their shelves; '
        'Ghost (layer 3) collides with the walls only';
  }

  void _addLayerBall(int layer) {
    const r = 10.0;
    final x = (_random.nextDouble() * 2 - 1) * _halfW * 0.6;
    final y = -_halfH + 20 + _random.nextDouble() * 40;
    final color = _kLayerColors[layer];
    _spawn(
      at: Offset(x, y),
      rigid: RigidBody2D(
        mass: 1,
        restitution: 0.3,
        friction: 0.3,
        layer: layer,
        // World (0) plus its own layer — ghosts only the world.
        collidesWith: layer == 3 ? 1 << 0 : (1 << 0) | (1 << layer),
      ),
      collider: _circle(r),
      look: CircleRenderable(
        radius: r,
        fillColor: color.withValues(alpha: layer == 3 ? 0.45 : 0.9),
        strokeColor: Colors.white.withValues(alpha: 0.5),
        strokeWidth: 1,
        layer: 5,
      ),
      name: '${_kLayerNames[layer]} Ball',
    );
  }

  void _toggleShelf(RigidBody2D? shelf) {
    if (shelf == null) return;
    setState(() {
      // 0 collides with nothing; back to its own layer's mask.
      shelf.collidesWith = shelf.collidesWith == 0 ? 1 << shelf.layer : 0;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Forces from code
  // ─────────────────────────────────────────────────────────────────────────

  void _buildForcesDemo() {
    _engine.physics.setGravity(0, 300);
    _createWalls(restitution: 0.3, friction: 0.4);
    final hw = _halfW, hh = _halfH;
    for (var i = 0; i < 8; i++) {
      final x = -hw * 0.7 + i * (hw * 1.4 / 7);
      final round = i.isOdd;
      final color = Color.lerp(
        const Color(0xFFAED581),
        const Color(0xFF26A69A),
        i / 7,
      )!;
      final e = _spawn(
        at: Offset(x, hh - 40),
        rigid: RigidBody2D(mass: 2, friction: 0.4, restitution: 0.25),
        collider: round ? _circle(14) : _box(30, 30),
        look: round
            ? CustomRenderable(
                layer: 5,
                getBoundsCallback: () =>
                    Rect.fromCircle(center: Offset.zero, radius: 16),
                onRender: (canvas, _) {
                  canvas.drawCircle(Offset.zero, 14, Paint()..color = color);
                  // A spoke, so spin shows.
                  canvas.drawLine(
                    Offset.zero,
                    const Offset(13, 0),
                    Paint()
                      ..color = Colors.black54
                      ..strokeWidth = 2,
                  );
                },
              )
            : RectangleRenderable(
                size: const Size(30, 30),
                fillColor: color,
                strokeColor: Colors.white.withValues(alpha: 0.4),
                strokeWidth: 1.2,
                layer: 5,
              ),
        name: round ? 'Ball $i' : 'Crate $i',
      );
      _forceBodies.add(e.getComponent<RigidBody2D>()!);
    }
    _statusMessage = 'Each button calls a RigidBody2D method on every body';
  }

  /// Wind: a force has to be added every step it should act.
  void _applyWind() {
    if (!_windOn) return;
    for (final body in _forceBodies) {
      body.addForce(const Offset(_kWindForce, 0));
    }
  }

  void _forEachForceBody(void Function(RigidBody2D body) action, String what) {
    for (final body in _forceBodies) {
      action(body);
    }
    setState(() => _statusMessage = what);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Joints (distance, fixed, slider)
  // ─────────────────────────────────────────────────────────────────────────

  void _buildSpringChainDemo() {
    _engine.physics.setGravity(0, 180);
    _createWalls(restitution: 0.2, friction: 0.4);

    // ── Spring rope: bobs held by soft DistanceJoint2Ds ──
    const ropeN = 8;
    const ropeSegLen = 40.0;
    final ropeX = -_halfW * 0.35;
    final ropeStartY = -_halfH * 0.55;

    // The static hook: a collider alone is a static body.
    _ropeEntities.add(
      _spawn(
        at: Offset(ropeX, ropeStartY),
        collider: _circle(6),
        look: CircleRenderable(
          radius: 6,
          fillColor: const Color(0xFFCE93D8),
          strokeColor: Colors.white54,
          strokeWidth: 1,
          layer: 8,
        ),
        name: 'Rope 0',
      ),
    );

    for (int i = 1; i <= ropeN; i++) {
      final y = ropeStartY + i * ropeSegLen;
      final r = 7.0 + (i % 2) * 3.0;
      _ropeEntities.add(
        _spawn(
          at: Offset(ropeX, y),
          rigid: RigidBody2D(
            mass: 1.0,
            restitution: 0.3,
            friction: 0.05,
            linearDamping: 0.05,
            // Give the end of the rope a push.
            initialVelocity: i == ropeN ? const Offset(160, 0) : Offset.zero,
          ),
          collider: _circle(r),
          look: CircleRenderable(
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
          name: 'Rope $i',
          extra: [
            DistanceJoint2D(
              connectedBody: EntityTarget.name('Rope ${i - 1}'),
              length: ropeSegLen,
              stiffness: 5, // Hz: springy
              damping: 0.2,
            ),
          ],
        ),
      );
    }

    // The rope drawn between its bobs.
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 4,
          getBoundsCallback: () => Rect.fromCenter(
            center: Offset.zero,
            width: _halfW * 2 + 100,
            height: _halfH * 2 + 100,
          ),
          onRender: (canvas, _) {
            final path = Path();
            var first = true;
            for (final e in _ropeEntities) {
              final p = e.getComponent<TransformComponent>()?.position;
              if (p == null) continue;
              first ? path.moveTo(p.x, p.y) : path.lineTo(p.x, p.y);
              first = false;
            }
            canvas.drawPath(
              path,
              Paint()
                ..color = const Color(0xFFCE93D8).withValues(alpha: 0.5)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          },
        ),
      ),
    ], name: 'Rope Line');

    // ── Rigid beam: boxes held together by FixedJoint2Ds ──
    const weldN = 4;
    const boxW = 36.0, boxH = 18.0;
    final weldX = _halfW * 0.25;
    final weldY = -_halfH * 0.3;
    for (int i = 0; i < weldN; i++) {
      final x = weldX + i * (boxW + 2);
      _spawn(
        at: Offset(x, weldY),
        // The first box is the static anchor.
        rigid: i == 0
            ? _staticBody(friction: 0.2)
            : RigidBody2D(mass: 1.5, restitution: 0.3, friction: 0.2),
        collider: _box(boxW, boxH),
        look: RectangleRenderable(
          size: const Size(boxW, boxH),
          fillColor: i == 0
              ? const Color(0xFF8D6E63)
              : const Color(0xFFFFB74D).withValues(alpha: 0.9),
          strokeColor: Colors.white.withValues(alpha: 0.3),
          strokeWidth: 1,
          layer: 5,
        ),
        name: 'Beam $i',
        extra: [
          if (i > 0)
            FixedJoint2D(connectedBody: EntityTarget.name('Beam ${i - 1}')),
        ],
      );
    }

    // ── Piston: a box on a motorised SliderJoint2D along a rail ──
    final railY = _halfH * 0.45;
    final railX = _halfW * 0.35;
    _railX = railX;
    _spawn(
      at: Offset(railX, railY),
      // A body for the joint to hold on to, colliding with nothing.
      rigid: _staticBody(collidesWith: 0),
      collider: _box(6, 6),
      look: CustomRenderable(
        layer: 3,
        getBoundsCallback: () => const Rect.fromLTRB(-110, -6, 110, 6),
        onRender: (canvas, _) {
          canvas.drawLine(
            const Offset(-100, 0),
            const Offset(100, 0),
            Paint()
              ..color = const Color(0xFF90A4AE)
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
        },
      ),
      name: 'Rail',
    );
    _slider = SliderJoint2D(
      connectedBody: const EntityTarget.name('Rail'),
      axis: const Offset(1, 0),
      useLimits: true,
      minPosition: -_kPistonTravel,
      maxPosition: _kPistonTravel,
      enableMotor: true,
      motorSpeed: 60,
      motorMaxForce: 4000,
    );
    _pistonTransform = _spawn(
      at: Offset(railX, railY),
      rigid: RigidBody2D(mass: 2, friction: 0.2),
      collider: _box(34, 22),
      look: RectangleRenderable(
        size: const Size(34, 22),
        fillColor: const Color(0xFF4DB6AC),
        strokeColor: Colors.white.withValues(alpha: 0.5),
        strokeWidth: 1.2,
        layer: 6,
      ),
      name: 'Piston',
      extra: [_slider!],
    ).getComponent<TransformComponent>();

    _statusMessage =
        'Left: DistanceJoint2D rope   Right: FixedJoint2D beam + '
        'SliderJoint2D piston';
  }

  /// Where the piston is along its rail, from the rail's centre.
  double get _pistonOffset => (_pistonTransform?.position.x ?? _railX) - _railX;

  /// Runs the piston's motor the other way. A changed setting makes the
  /// joint again from where the bodies are, so its limits are moved by the
  /// piston's offset to stay at ±[_kPistonTravel] around the rail.
  void _reversePiston() {
    final slider = _slider;
    if (slider == null) return;
    final d = _pistonOffset;
    slider
      ..motorSpeed = -slider.motorSpeed
      ..minPosition = -_kPistonTravel - d
      ..maxPosition = _kPistonTravel - d;
  }

  /// The piston turns round at the ends of its travel.
  void _drivePiston() {
    final slider = _slider;
    if (slider == null) return;
    final d = _pistonOffset;
    if ((slider.motorSpeed > 0 && d >= _kPistonTravel - 2) ||
        (slider.motorSpeed < 0 && d <= -_kPistonTravel + 2)) {
      _reversePiston();
    }
  }

  Widget _buildSpringChainControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton('Shake', const Color(0xFFCE93D8), () {
          for (final body in _dynamicBodies) {
            body.addImpulse(Offset((_random.nextDouble() * 2 - 1) * 80, -60));
          }
        }),
        _actionButton(
          'Reverse Piston',
          const Color(0xFF4DB6AC),
          () => setState(_reversePiston),
        ),
        _actionButton(
          'Reset',
          const Color(0xFF78909C),
          () => _buildDemo(_demo),
        ),
        const Text(
          'distance rope  ·  fixed beam  ·  slider piston',
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
  // Demo: Car Physics (wheel joints + track)
  // ─────────────────────────────────────────────────────────────────────────

  void _buildCarPhysicsDemo() {
    _engine.physics.setGravity(0, 300);

    final groundY = _halfH * 0.30;
    final rampTopY = -_halfH * 0.08;

    // ── Track: flat start → ramp up → flat peak → ramp down → flat end ──
    // (the engine adds the ghost points Box2D's open chains need)
    final trackPoints = [
      Offset(-_halfW * 0.9, groundY),
      Offset(-_halfW * 0.4, groundY),
      Offset(-_halfW * 0.05, rampTopY),
      Offset(_halfW * 0.15, rampTopY),
      Offset(_halfW * 0.5, groundY),
      Offset(_halfW * 0.9, groundY),
    ];
    _spawn(
      at: Offset.zero,
      rigid: _staticBody(friction: 0.75, restitution: 0.05),
      collider: Collider2D(
        shape: ColliderShape2D.chain,
        points: trackPoints,
        thickness: 4.0,
      ),
      look: CustomRenderable(
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
      name: 'Track',
    );

    // ── End-stop walls so the car can't leave either edge ──
    for (final x in [-_halfW * 0.92, _halfW * 0.92]) {
      _spawn(
        at: Offset(x, groundY - 20),
        rigid: _staticBody(friction: 0.5, restitution: 0.1),
        collider: _box(8, 40),
        look: RectangleRenderable(
          size: const Size(8, 40),
          fillColor: const Color(0xFF37474F),
          strokeColor: Colors.white24,
          strokeWidth: 1,
          layer: 3,
        ),
        name: 'End Stop',
      );
    }

    // ── Car: chassis + cabin + two wheels, all in collision group -7 ──
    const chassisW = 64.0, chassisH = 18.0;
    const carGroup = -7; // negative: the car's parts never collide
    const wheelR = 12.0;
    const wheelOffsetX = 22.0;
    const wheelOffsetY = chassisH / 2 + wheelR + 3.0;
    final chassisX = -_halfW * 0.65;
    final chassisY = groundY - 40.0;

    WheelJoint2D wheelJoint(String wheel) => WheelJoint2D(
      connectedBody: EntityTarget.name(wheel),
      axis: const Offset(0, 1), // suspension: up/down in the holder's space
      stiffness: 45.0,
      damping: 0.65,
      enableMotor: false,
      motorSpeed: 0,
      motorMaxTorque: _carMaxTorque,
    );

    // The chassis holds the rear wheel's joint.
    _carRearJoint = wheelJoint('Rear Wheel');
    _carChassis = _spawn(
      at: Offset(chassisX, chassisY),
      rigid: RigidBody2D(
        mass: 6.0,
        friction: 0.3,
        restitution: 0.05,
        linearDamping: 0.02,
        groupIndex: carGroup,
      ),
      collider: _box(chassisW, chassisH),
      look: RectangleRenderable(
        size: const Size(chassisW, chassisH),
        fillColor: const Color(0xFF80CBC4),
        strokeColor: Colors.white.withValues(alpha: 0.4),
        strokeWidth: 1.5,
        layer: 6,
      ),
      name: 'Chassis',
      extra: [_carRearJoint!],
    ).getComponent<RigidBody2D>();

    // An entity holds one joint of each kind, so the cabin — welded to the
    // chassis — holds the front wheel's.
    _carFrontJoint = wheelJoint('Front Wheel');
    const cabinW = 30.0, cabinH = 14.0;
    _spawn(
      at: Offset(chassisX + 6, chassisY - chassisH / 2 - cabinH / 2),
      rigid: RigidBody2D(mass: 1.0, friction: 0.3, groupIndex: carGroup),
      collider: _box(cabinW, cabinH),
      look: CustomRenderable(
        layer: 6,
        getBoundsCallback: () => Rect.fromCenter(
          center: Offset.zero,
          width: cabinW + 2,
          height: cabinH + 2,
        ),
        onRender: (canvas, _) {
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: cabinW,
            height: cabinH,
          );
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              rect,
              topLeft: const Radius.circular(6),
              topRight: const Radius.circular(6),
            ),
            Paint()..color = const Color(0xFF4DB6AC),
          );
          canvas.drawRect(
            Rect.fromCenter(
              center: const Offset(3, -1),
              width: cabinW * 0.5,
              height: cabinH * 0.5,
            ),
            Paint()..color = const Color(0xFFB2EBF2),
          );
        },
      ),
      name: 'Cabin',
      extra: [
        FixedJoint2D(connectedBody: const EntityTarget.name('Chassis')),
        _carFrontJoint!,
      ],
    );

    void wheel(String name, double wx, double wy) => _spawn(
      at: Offset(wx, wy),
      rigid: RigidBody2D(
        mass: 1.2,
        friction: 0.9,
        restitution: 0.05,
        linearDamping: 0.01,
        groupIndex: carGroup,
      ),
      collider: _circle(wheelR),
      look: CustomRenderable(
        layer: 7,
        getBoundsCallback: () =>
            Rect.fromCircle(center: Offset.zero, radius: wheelR + 2),
        onRender: (canvas, _) {
          canvas.drawCircle(
            Offset.zero,
            wheelR,
            Paint()..color = const Color(0xFF37474F),
          );
          final spoke = Paint()
            ..color = Colors.white.withValues(alpha: 0.45)
            ..strokeWidth = 2;
          canvas
            ..drawLine(
              const Offset(-wheelR + 2, 0),
              const Offset(wheelR - 2, 0),
              spoke,
            )
            ..drawLine(
              const Offset(0, -wheelR + 2),
              const Offset(0, wheelR - 2),
              spoke,
            );
        },
      ),
      name: name,
    );

    wheel('Rear Wheel', chassisX - wheelOffsetX, chassisY + wheelOffsetY);
    wheel('Front Wheel', chassisX + wheelOffsetX, chassisY + wheelOffsetY);

    _statusMessage =
        '← → (A/D) or buttons to drive  ·  Space to brake  ·  $_backend';
  }

  /// Turns the keys into the wheel joints' motors. Equal values leave the
  /// joints alone; a change makes them again (PhysicsJointBindingSystem).
  void _driveCar() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final left =
        _carLeft ||
        keys.contains(LogicalKeyboardKey.arrowLeft) ||
        keys.contains(LogicalKeyboardKey.keyA);
    final right =
        _carRight ||
        keys.contains(LogicalKeyboardKey.arrowRight) ||
        keys.contains(LogicalKeyboardKey.keyD);
    final brake =
        _carBrake ||
        keys.contains(LogicalKeyboardKey.space) ||
        keys.contains(LogicalKeyboardKey.arrowDown);
    final speed = brake || left == right
        ? 0.0
        : right
        ? _carMotorSpeed
        : -_carMotorSpeed;
    final enable = brake || speed != 0;
    final torque = brake ? _carMaxTorque * 3 : _carMaxTorque;
    for (final joint in [_carRearJoint, _carFrontJoint]) {
      if (joint == null) continue;
      joint
        ..enableMotor = enable
        ..motorSpeed = speed
        ..motorMaxTorque = torque;
    }
  }

  Widget _holdButton({
    required IconData icon,
    required String label,
    required Color color,
    required ValueChanged<bool> onHold,
  }) {
    return Listener(
      onPointerDown: (_) => onHold(true),
      onPointerUp: (_) => onHold(false),
      onPointerCancel: (_) => onHold(false),
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.18),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildCarPhysicsControls() {
    const accent = Color(0xFF80CBC4);
    return Row(
      children: [
        _holdButton(
          icon: Icons.arrow_back,
          label: 'Left',
          color: accent,
          onHold: (v) => _carLeft = v,
        ),
        const SizedBox(width: 8),
        _holdButton(
          icon: Icons.stop,
          label: 'Brake',
          color: Colors.redAccent,
          onHold: (v) => _carBrake = v,
        ),
        const SizedBox(width: 8),
        _holdButton(
          icon: Icons.arrow_forward,
          label: 'Right',
          color: accent,
          onHold: (v) => _carRight = v,
        ),
      ],
    );
  }

  Widget _buildCarPhysicsPanelControls() {
    const accent = Color(0xFF80CBC4);
    final chassisSpeed = _carChassis?.linearVelocity.dx ?? 0;
    final motor = _carRearJoint;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text(
              'Speed ',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            Expanded(
              child: Slider(
                value: _carMotorSpeed,
                min: 50,
                max: 1000,
                divisions: 56,
                label: _carMotorSpeed.round().toString(),
                onChanged: (v) => setState(() => _carMotorSpeed = v),
              ),
            ),
            const Text(
              'Torque ',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            Expanded(
              child: Slider(
                value: _carMaxTorque,
                min: 100,
                max: 12000,
                divisions: 46,
                label: _carMaxTorque.round().toString(),
                onChanged: (v) => setState(() => _carMaxTorque = v),
              ),
            ),
          ],
        ),
        Row(
          children: [
            _actionButton('Reset', accent, () => _buildDemo(_demo)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'chassis vx ${chassisSpeed.toStringAsFixed(0)}  ·  motor '
                '${motor == null || !motor.enableMotor ? 'off' : motor.motorSpeed.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: CharacterBody2D
  // ─────────────────────────────────────────────────────────────────────────

  void _buildCharacterDemo() {
    _engine.physics.setGravity(0, _kHeroGravity);
    _createWalls(restitution: 0, friction: 0.6);
    final hw = _halfW, hh = _halfH;
    const ground = Color(0xFF26415C);
    const groundEdge = Color(0xFF5C8DB8);

    // ── Ramp and plateau: one convex polygon (a slope of up to ~30°) ──
    final rampL = -hw * 0.70;
    final rampW = (hw * 0.30).clamp(80.0, 220.0);
    final plateauW = (hw * 0.12).clamp(40.0, 90.0);
    final rise = (rampW * 0.5).clamp(20.0, math.min(70.0, hh * 0.4));
    final hillW = rampW + plateauW;
    final hillCenter = Offset(rampL + hillW / 2, hh - rise / 2);
    final hill = [
      Offset(-hillW / 2, rise / 2),
      Offset(hillW / 2, rise / 2),
      Offset(hillW / 2, -rise / 2),
      Offset(-hillW / 2 + rampW, -rise / 2),
    ];
    _spawn(
      at: hillCenter,
      rigid: _staticBody(friction: 0.6),
      collider: Collider2D(shape: ColliderShape2D.polygon, points: hill),
      look: CustomRenderable(
        layer: 2,
        getBoundsCallback: () => Rect.fromCenter(
          center: Offset.zero,
          width: hillW + 4,
          height: rise + 4,
        ),
        onRender: (canvas, _) {
          final path = Path()..addPolygon(hill, true);
          canvas
            ..drawPath(path, Paint()..color = ground)
            ..drawPath(
              path,
              Paint()
                ..color = groundEdge
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
        },
      ),
      name: 'Slope',
    );

    // ── Stairs up to the right wall, each step 10 high ──
    const steps = 5;
    const stepH = 10.0;
    final stepD = (hw * 0.07).clamp(18.0, 34.0);
    final stairsX = hw - steps * stepD - stepD;
    for (var i = 0; i < steps; i++) {
      final left = stairsX + i * stepD;
      final w = hw - left;
      final h = (i + 1) * stepH;
      _spawn(
        at: Offset(left + w / 2, hh - h / 2),
        rigid: _staticBody(friction: 0.6),
        collider: _box(w, h),
        look: RectangleRenderable(
          size: Size(w, h),
          fillColor: ground,
          strokeColor: groundEdge,
          strokeWidth: 1,
          layer: 2,
        ),
        name: 'Step ${i + 1}',
      );
    }

    // ── Goal flag on the top step: a static sensor ──
    _goalEntity = _spawn(
      at: Offset(hw - stepD * 0.9, hh - steps * stepH - 24),
      rigid: RigidBody2D(bodyType: BodyType.static, isSensor: true),
      collider: _circle(16),
      look: CustomRenderable(
        layer: 4,
        getBoundsCallback: () =>
            Rect.fromCircle(center: Offset.zero, radius: 20),
        onRender: (canvas, _) {
          canvas
            ..drawCircle(
              Offset.zero,
              16,
              Paint()
                ..color = const Color(0xFFFFD54F).withValues(alpha: 0.15),
            )
            ..drawLine(
              const Offset(-4, 14),
              const Offset(-4, -14),
              Paint()
                ..color = Colors.white70
                ..strokeWidth = 2,
            )
            ..drawPath(
              Path()
                ..moveTo(-4, -14)
                ..lineTo(10, -9)
                ..lineTo(-4, -4)
                ..close(),
              Paint()..color = const Color(0xFFFFD54F),
            );
        },
      ),
      name: 'Goal',
    );

    // ── One-way platform: jump up through it, stand on it ──
    final oneWayW = (hw * 0.34).clamp(90.0, 170.0);
    final oneWayTop = hh - math.min(105.0, hh * 0.6);
    _spawn(
      at: Offset(-hw * 0.12, oneWayTop + 5),
      rigid: _staticBody(friction: 0.6),
      collider: Collider2D(size: Vector2(oneWayW, 10), oneWay: true),
      look: CustomRenderable(
        layer: 3,
        getBoundsCallback: () => Rect.fromCenter(
          center: Offset.zero,
          width: oneWayW + 4,
          height: 24,
        ),
        onRender: (canvas, _) {
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: oneWayW,
            height: 10,
          );
          canvas.drawRect(
            rect,
            Paint()..color = const Color(0xFF7E57C2).withValues(alpha: 0.75),
          );
          // Chevrons: passable from below.
          final chevron = Paint()
            ..color = Colors.white54
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2;
          for (var x = -oneWayW / 2 + 12; x < oneWayW / 2 - 6; x += 22) {
            canvas.drawPath(
              Path()
                ..moveTo(x - 4, 2)
                ..lineTo(x, -2)
                ..lineTo(x + 4, 2),
              chevron,
            );
          }
        },
      ),
      name: 'One-way Platform',
    );

    // ── Moving platform: kinematic, driven by its velocity ──
    const platformW = 100.0;
    final platformTop = oneWayTop - math.min(100.0, hh * 0.55);
    _platformMinX = hw * 0.12;
    _platformMaxX = math.max(hw * 0.5, _platformMinX + 40);
    final platform = _spawn(
      at: Offset(_platformMinX, platformTop + 6),
      rigid: RigidBody2D(bodyType: BodyType.kinematic, friction: 0.8),
      collider: _box(platformW, 12),
      look: RectangleRenderable(
        size: const Size(platformW, 12),
        fillColor: const Color(0xFFFF9800),
        strokeColor: Colors.white.withValues(alpha: 0.5),
        strokeWidth: 1,
        layer: 3,
      ),
      name: 'Moving Platform',
      extra: [VelocityComponent(velocity: Vector3(_kPlatformSpeed, 0, 0))],
    );
    _platformVelocity = platform.getComponent<VelocityComponent>();
    _platformTransform = platform.getComponent<TransformComponent>();

    // ── A crate the character pushes ──
    _spawn(
      at: Offset(math.min(hw * 0.28, stairsX - 30), hh - 17),
      rigid: RigidBody2D(mass: 15, friction: 0.5),
      collider: _box(32, 32),
      look: CustomRenderable(
        layer: 5,
        getBoundsCallback: () =>
            Rect.fromCenter(center: Offset.zero, width: 34, height: 34),
        onRender: (canvas, _) {
          const rect = Rect.fromLTRB(-16, -16, 16, 16);
          final edge = Paint()
            ..color = const Color(0xFF5D4037)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          canvas
            ..drawRect(rect, Paint()..color = const Color(0xFFA1887F))
            ..drawRect(rect, edge)
            ..drawLine(rect.topLeft, rect.bottomRight, edge)
            ..drawLine(rect.topRight, rect.bottomLeft, edge);
        },
      ),
      name: 'Crate',
    );

    // ── The hero ──
    final hero = CharacterBody2D(
      radius: 14,
      height: 44,
      maxSlopeAngle: 50 * math.pi / 180,
      stepHeight: 12,
      stickToFloor: 10,
    );
    _hero = hero;
    _heroFacing = 1;
    const accent = Color(0xFFF5746F);
    _heroEntity = _world.createEntityWithComponents([
      TransformComponent(position: Vector3(-hw * 0.86, hh - 40, 0)),
      hero,
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 8,
          getBoundsCallback: () => const Rect.fromLTRB(-18, -26, 18, 26),
          onRender: (canvas, _) {
            const body = Rect.fromLTRB(-14, -22, 14, 22);
            final shape = RRect.fromRectAndRadius(
              body,
              const Radius.circular(14),
            );
            canvas
              ..drawRRect(
                shape,
                Paint()
                  ..color = hero.isGrounded
                      ? accent
                      : accent.withValues(alpha: 0.7),
              )
              ..drawRRect(
                shape,
                Paint()
                  ..color = Colors.white70
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5,
              );
            final f = _heroFacing;
            canvas
              ..drawCircle(Offset(5 * f, -9), 3.4, Paint()..color = Colors.white)
              ..drawCircle(
                Offset(6.5 * f, -9),
                1.7,
                Paint()..color = Colors.black,
              );
          },
        ),
      ),
    ], name: 'Hero');

    _statusMessage = 'Climb the slope and stairs, ride the orange platform';
  }

  /// Keys and pad buttons → the character, and the platform's patrol.
  void _driveCharacter() {
    final hero = _hero;
    if (hero == null) return;
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final left =
        _padLeft ||
        keys.contains(LogicalKeyboardKey.arrowLeft) ||
        keys.contains(LogicalKeyboardKey.keyA);
    final right =
        _padRight ||
        keys.contains(LogicalKeyboardKey.arrowRight) ||
        keys.contains(LogicalKeyboardKey.keyD);
    final jump =
        _padJump ||
        keys.contains(LogicalKeyboardKey.space) ||
        keys.contains(LogicalKeyboardKey.arrowUp) ||
        keys.contains(LogicalKeyboardKey.keyW);

    final dir = (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0);
    hero.moveVelocity = Offset(dir * _kHeroSpeed, 0);
    if (dir != 0) _heroFacing = dir;
    // Jump on the press, not while held.
    if (jump && !_jumpWasDown && hero.isGrounded) hero.jump(_kHeroJump);
    _jumpWasDown = jump;

    // The platform turns round at the ends of its run.
    final velocity = _platformVelocity;
    final transform = _platformTransform;
    if (velocity == null || transform == null) return;
    final x = transform.position.x;
    if (x >= _platformMaxX && velocity.velocity.x > 0) {
      velocity.velocity.setValues(-_kPlatformSpeed, 0, 0);
    } else if (x <= _platformMinX && velocity.velocity.x < 0) {
      velocity.velocity.setValues(_kPlatformSpeed, 0, 0);
    }
  }

  Widget _buildCharacterPadControls() {
    const accent = Color(0xFFF5746F);
    return Row(
      children: [
        _holdButton(
          icon: Icons.arrow_back,
          label: 'Left',
          color: accent,
          onHold: (v) => _padLeft = v,
        ),
        const SizedBox(width: 8),
        _holdButton(
          icon: Icons.arrow_forward,
          label: 'Right',
          color: accent,
          onHold: (v) => _padRight = v,
        ),
        const Spacer(),
        _holdButton(
          icon: Icons.arrow_upward,
          label: 'Jump',
          color: const Color(0xFFFFD54F),
          onHold: (v) => _padJump = v,
        ),
      ],
    );
  }

  Widget _buildCharacterPanelControls() {
    const accent = Color(0xFFF5746F);
    final hero = _hero;
    final ground = hero?.groundEntity?.name ?? '—';
    final state = hero?.groundState.name ?? '—';
    final v = hero?.velocity ?? Offset.zero;
    return Row(
      children: [
        _actionButton('Reset', accent, () => _buildDemo(_demo)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'groundState: $state  ·  on: $ground',
                style: const TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'velocity (${v.dx.toStringAsFixed(0)}, '
                '${v.dy.toStringAsFixed(0)})  ·  goals: $_goalHits  ·  '
                '←/→ A/D move, Space/W/↑ jump',
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

  // ─────────────────────────────────────────────────────────────────────────
  // Stats line
  // ─────────────────────────────────────────────────────────────────────────

  String get _statsLine {
    final bodies = _engine.physics.bodies;
    var dynamicCount = 0, awake = 0;
    for (final b in bodies) {
      if (!b.isDynamic) continue;
      dynamicCount++;
      if (b.isAwake) awake++;
    }
    final gx = _engine.physics.gravity.x;
    final gy = _engine.physics.gravity.y;
    return 'bodies: ${bodies.length}'
        '  dynamic: $dynamicCount'
        '  awake: $awake'
        '  enters: $_collisionEnters'
        '  gravity (${gx.toStringAsFixed(0)}, ${gy.toStringAsFixed(0)})'
        '  $_backend';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────

  bool get _usesKeys =>
      _demo == _Demo.carPhysics || _demo == _Demo.characterBody;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      // The keys are read from HardwareKeyboard in the fixed step; here
      // they are only kept from moving the focus around.
      onKeyEvent: (_, event) {
        if (!_usesKeys) return KeyEventResult.ignored;
        final key = event.logicalKey;
        final steering =
            key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.space;
        return steering ? KeyEventResult.handled : KeyEventResult.ignored;
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
    final paused = _engine.isPaused;
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
                const CommonTag(
                  label: 'EXPERIMENTAL',
                  textColor: Color(0xFFFFCC80),
                  backgroundColor: Color(0xFFFFB74D),
                  borderColor: Color(0xFFFFB74D),
                  fontSize: 9,
                  horizontalPadding: 8,
                  verticalPadding: 3,
                  letterSpacing: 0.6,
                ),
              ],
              if (_demo.isNew) ...[
                const SizedBox(width: 8),
                const CommonTag(
                  label: 'NEW IN 2.0',
                  textColor: Color(0xFFF5746F),
                  backgroundColor: Color(0xFFF5746F),
                  borderColor: Color(0xFFF5746F),
                  fontSize: 9,
                  horizontalPadding: 8,
                  verticalPadding: 3,
                  letterSpacing: 0.6,
                ),
              ],
              const Spacer(),
              const Flexible(
                child: Text(
                  'PhysicsSystem  ·  RigidBody2D  ·  Collider2D',
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
              _actionButton(
                paused ? '▶ Resume' : '⏸ Pause',
                const Color(0xFF29B6F6),
                () => setState(() {
                  // The shared engine: DemoEngine.reset resumes it when a
                  // demo is built or the screen goes.
                  paused ? _engine.resume() : _engine.pause();
                }),
              ),
              const SizedBox(width: 12),
              const Text(
                'Collider outlines (debug)',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(width: 6),
              Switch(
                value: _showColliderDebug,
                onChanged: (v) {
                  setState(() => _showColliderDebug = v);
                  _applyColliderDebug();
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
    return Stack(
      children: [
        GameCameraControls(
          camera: _engine.cameraSystem.mainCamera,
          enablePan: true,
          enablePinch: true,
          showZoomLevel: true,
          child: GameWidget(key: _canvasKey, engine: _engine, showFPS: true),
        ),
        if (_demo == _Demo.carPhysics)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(top: false, child: _buildCarPhysicsControls()),
          ),
        if (_demo == _Demo.characterBody)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(top: false, child: _buildCharacterPadControls()),
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
      case _Demo.layers:
        return _buildLayersControls();
      case _Demo.forces:
        return _buildForcesControls();
      case _Demo.springChain:
        return _buildSpringChainControls();
      case _Demo.carPhysics:
        return _buildCarPhysicsPanelControls();
      case _Demo.characterBody:
        return _buildCharacterPanelControls();
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
        const Flexible(
          child: Text(
            'restitution:  0.0  0.2  0.4  0.6  0.8  1.0',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
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
          '+ Box',
          const Color(0xFFAB47BC),
          () => setState(() => _addShape(1)),
        ),
        _actionButton(
          '+ Polygon',
          const Color(0xFFAB47BC),
          () => setState(() => _addShape(2)),
        ),
        _actionButton(
          '+ Capsule',
          const Color(0xFF26C6DA),
          () => setState(() => _addNewShape(0)),
        ),
        _actionButton(
          '+ Rounded',
          const Color(0xFF26C6DA),
          () => setState(() => _addNewShape(3)),
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
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton('Drop Ball', const Color(0xFFFFCA28), _dropHeavyBall),
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
            _actionButton(
              'Reset',
              const Color(0xFF78909C),
              () => _buildDemo(_demo),
            ),
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
                    children: [
                      Text(
                        'inside now: ${_insideSensor.length}',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                      for (final e in _sensorLog)
                        Text(
                          e,
                          style: TextStyle(
                            color: e.startsWith('ENTER')
                                ? const Color(0xFF66BB6A)
                                : const Color(0xFFFF7043),
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
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
                    ? 'raycast: no hit'
                    : 'raycast → ${hit.entity == null ? 'body' : _nameOf(hit.entity!)}'
                          ' @ (${hit.point.dx.toStringAsFixed(1)}, '
                          '${hit.point.dy.toStringAsFixed(1)})  '
                          'd=${hit.distance.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Color(0xFFEF9A9A),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'overlapCircle ∩ ${_queryOverlap.length} entities',
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

  Widget _buildLayersControls() {
    String shelfLabel(RigidBody2D? shelf, String name) =>
        '$name shelf: ${shelf?.collidesWith == 0 ? 'off' : 'on'}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final layer in [1, 2, 3])
              _actionButton(
                '+ ${_kLayerNames[layer]} (L$layer)',
                _kLayerColors[layer],
                () => setState(() => _addLayerBall(layer)),
              ),
            _actionButton(
              shelfLabel(_redShelf, 'Red'),
              _kLayerColors[1],
              () => _toggleShelf(_redShelf),
            ),
            _actionButton(
              shelfLabel(_blueShelf, 'Blue'),
              _kLayerColors[2],
              () => _toggleShelf(_blueShelf),
            ),
            _actionButton(
              'Reset',
              const Color(0xFF78909C),
              () => _buildDemo(_demo),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          [
            for (var i = 0; i < _kLayerNames.length; i++)
              'L$i ${_kLayerNames[i]}',
          ].join('  ·  '),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildForcesControls() {
    const accent = Color(0xFFAED581);
    final first = _forceBodies.isEmpty ? null : _forceBodies.first;
    final v = first?.linearVelocity ?? Offset.zero;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _actionButton(
              'Kick (addImpulse)',
              accent,
              () => _forEachForceBody(
                (b) => b.addImpulse(
                  Offset((_random.nextDouble() * 2 - 1) * 200, -700),
                ),
                'addImpulse: an instant change of momentum',
              ),
            ),
            _actionButton(
              _windOn ? 'Wind: on (addForce)' : 'Wind: off (addForce)',
              const Color(0xFF4FC3F7),
              () => setState(() {
                _windOn = !_windOn;
                _statusMessage = 'addForce every fixed step while the wind '
                    'blows';
              }),
            ),
            _actionButton(
              'Launch (setVelocity)',
              const Color(0xFFFFB74D),
              () => _forEachForceBody(
                (b) => b.setVelocity(
                  Offset((_random.nextDouble() * 2 - 1) * 150, -520),
                ),
                'setVelocity: replaces the velocity outright',
              ),
            ),
            _actionButton(
              'Spin (addAngularImpulse)',
              const Color(0xFFCE93D8),
              () => _forEachForceBody(
                (b) => b.addAngularImpulse(_random.nextBool() ? 1500 : -1500),
                'addAngularImpulse: turned by each body\'s inertia',
              ),
            ),
            _actionButton(
              'Stop',
              const Color(0xFF78909C),
              () => _forEachForceBody((b) {
                b
                  ..setVelocity(Offset.zero)
                  ..setAngularVelocity(0);
              }, 'setVelocity(Offset.zero) + setAngularVelocity(0)'),
            ),
            _actionButton(
              'Reset',
              const Color(0xFF78909C),
              () => _buildDemo(_demo),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'first body: linearVelocity (${v.dx.toStringAsFixed(0)}, '
          '${v.dy.toStringAsFixed(0)})  ·  angularVelocity '
          '${(first?.angularVelocity ?? 0).toStringAsFixed(1)}  ·  '
          'grounded ${first?.isGrounded ?? false}',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
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
                  'just_game_engine 2.x · 2-D physics',
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
