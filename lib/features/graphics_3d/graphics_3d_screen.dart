import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/graphics_3d.dart'
    show
        AnimationPlayerComponent,
        Arch3D,
        Capsule3D,
        Cone3D,
        Cube3D,
        Cylinder3D,
        EnvironmentComponent,
        LightComponent,
        LightKind,
        MaterialOverrides3D,
        ModelComponent,
        Plane3D,
        Polygon3D,
        Primitive3D,
        Ramp3D,
        SocketComponent,
        Sphere3D,
        Stairs3D,
        Torus3D;
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/engine/demo_engine.dart';

// 3-D graphics on just_game_engine 2.x: shapes, PBR material files, lights
// and shadows, sky and fog, a glTF model driven by an animator graph, and
// the 3-D camera rigs — drawn by just_graphics_engine on Flutter GPU.
//
// The screen owns its engine (Demo3DEngine.create): Graphics3D draws a full
// GPU frame under every view of its engine, which the shared 2-D engine
// must not pay for. Units are metres and +Y is down (up is -Y).

// -----------------------------------------------------------------------------
// Demo mode
// -----------------------------------------------------------------------------

enum _Demo {
  shapes,
  materials,
  lights,
  environment,
  model,
  cameras;

  String get label => switch (this) {
    shapes => 'Shapes',
    materials => 'PBR Materials',
    lights => 'Lights & Shadows',
    environment => 'Sky & Fog',
    model => 'glTF Model',
    cameras => 'Camera Rigs',
  };

  IconData get icon => switch (this) {
    shapes => Icons.category,
    materials => Icons.texture,
    lights => Icons.lightbulb,
    environment => Icons.wb_twilight,
    model => Icons.directions_run,
    cameras => Icons.videocam,
  };

  Color get accentColor => switch (this) {
    shapes => const Color(0xFF29B6F6),
    materials => const Color(0xFFFFCA28),
    lights => const Color(0xFFFF7043),
    environment => const Color(0xFF66BB6A),
    model => const Color(0xFFAB47BC),
    cameras => const Color(0xFFF5746F),
  };

  String get description => switch (this) {
    shapes =>
      'Every Primitive3D — Cube3D, Sphere3D, Cylinder3D, Capsule3D, Cone3D, '
          'Torus3D, Plane3D, Ramp3D, Stairs3D, Arch3D, Polygon3D — each drawn '
          'with a *.material.json file (gold, chrome, glass, neon, jade…). '
          'Drag to orbit, scroll to zoom, tap a name to fly to it.',
    materials =>
      'Inline PBR values (metallic × roughness) beside shared material files '
          'and a variant (pbr_gold_brushed has pbr_gold as its parent). The '
          'orb on the right takes its own values through MaterialOverrides3D.',
    lights =>
      'LightComponent: the first directional light is the sun and casts the '
          'shadows; coloured point lights orbit and a spot light sweeps. '
          'Up to 8 point/spot lights are used per frame.',
    environment =>
      'EnvironmentComponent: a gradient sky (zenith / horizon / ground), '
          'hemisphere ambient, exposure, distance fog and reflections of the '
          'sky on shiny surfaces. Pick a preset or tweak it live.',
    model =>
      'ModelComponent loads hero.glb. An AnimatorComponent runs '
          'hero.animator.json on its AnimationPlayerComponent (idle → walk → '
          'run blend tree, crouch, jump, punch/kick combos); a SocketComponent '
          'pins a glowing orb to the right hand.',
    cameras =>
      'Virtual cameras and the brain: OrbitFollowComponent, LookAtComponent '
          '(a security cam and a crane), FirstPersonComponent (the hero\'s '
          'eyes). The highest priority is live; the brain blends between them.',
  };

  String get codeSnippet => switch (this) {
    shapes =>
      "import 'package:just_game_engine/graphics_3d.dart';\n\n"
          '// EngineConfig(graphics3D: Graphics3D()) — then shapes are entities:\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(position: Vector3(0, -0.55, 0)), // -Y is up\n'
          '  Cube3D(width: 1.1, height: 1.1, depth: 1.1,\n'
          "      material: 'assets/materials/pbr_gold.material.json'),\n"
          "], name: 'Gold Cube');\n\n"
          'world.createEntityWithComponents([\n'
          '  TransformComponent(position: Vector3(2, -0.65, 0)),\n'
          '  Sphere3D(radius: 0.65, color: Color(0xFFE9ECF1),\n'
          '      metallic: 1, roughness: 0.04), // inline PBR look\n'
          ']);\n'
          '// Cylinder3D, Capsule3D, Cone3D, Torus3D, Plane3D, Ramp3D,\n'
          '// Stairs3D, Arch3D, Polygon3D(points: [Offset(x, z), ...])',
    materials =>
      '// assets/materials/pbr_gold_brushed.material.json — a variant:\n'
          '// { "formatVersion": 1,\n'
          '//   "parent": "assets/materials/pbr_gold.material.json",\n'
          '//   "roughness": 0.6 }\n\n'
          'final orb = world.createEntityWithComponents([\n'
          '  TransformComponent(position: Vector3(0, -1, 0)),\n'
          "  Sphere3D(radius: 1, material: 'assets/materials/pbr_tweak.material.json'),\n"
          '  MaterialOverrides3D(),\n'
          ']);\n'
          'orb.getComponent<MaterialOverrides3D>()!\n'
          "  ..set('roughness', 0.2)\n"
          "  ..set('emissionStrength', 3.0)\n"
          "  ..set('color', 0xFFFF6F61); // ARGB, as a file saves it\n"
          'engine.graphics3D!.renderer.bloom.enabled = true;',
    lights =>
      '// Directional and spot lights shine along the entity\'s +Z.\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(euler: Vector3(-0.9, 0.6, 0)), // pitched down\n'
          '  LightComponent(kind: LightKind.directional,\n'
          '      color: Color(0xFFFFE2B8), intensity: 1.2),\n'
          "], name: 'Sun');\n"
          'world.createEntityWithComponents([\n'
          '  TransformComponent(position: Vector3(3, -1.5, 0)),\n'
          '  LightComponent(kind: LightKind.point,\n'
          '      color: Color(0xFFFF4060), intensity: 14, range: 8),\n'
          ']);\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(position: Vector3(0, -7, 0),\n'
          '      euler: Vector3(-1.3, 0, 0)),\n'
          '  LightComponent(kind: LightKind.spot, intensity: 90, range: 16,\n'
          '      innerConeAngle: 0.18, outerConeAngle: 0.36),\n'
          ']);\n'
          'engine.graphics3D!.renderer.shadows.enabled = true;',
    environment =>
      'world.createEntityWithComponents([\n'
          '  EnvironmentComponent(\n'
          '    sky: true,\n'
          '    zenith: Color(0xFF2B62C0),\n'
          '    horizon: Color(0xFFC9DCEF),\n'
          '    ground: Color(0xFF6E5D4B),\n'
          '    ambientSky: Color(0xFFA9C1E6),\n'
          '    ambientGround: Color(0xFF7A6550),\n'
          '    exposure: 1.05,\n'
          '    fog: true, fogColor: Color(0xFFE6D5C3),\n'
          '    fogDensity: 0.012, fogStart: 20,\n'
          '    reflections: true, reflectionStrength: 1,\n'
          '  ),\n'
          "], name: 'Sky');\n"
          '// Fields are read every frame: change them on the component.',
    model =>
      'final hero = world.createEntityWithComponents([\n'
          '  TransformComponent(),\n'
          "  ModelComponent(model: 'assets/models/hero.glb'),\n"
          "  AnimationPlayerComponent(clip: 'idle'),\n"
          "  AnimatorComponent(graphPath: 'assets/models/hero.animator.json'),\n"
          "], name: 'Hero');\n"
          'hero.getComponent<AnimatorComponent>()!\n'
          "  ..setBool('grounded', true)\n"
          "  ..setFloat('planarSpeed', 2.0) // idle → walk → run blend\n"
          "  ..setTrigger('punch_1');\n"
          '// Material files over the model\'s own, by material name:\n'
          'hero.getComponent<ModelComponent>()!.materials =\n'
          "    {'MAT_Cloth': 'assets/materials/pbr_gold.material.json'};\n"
          '// Held in the right hand:\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(), ParentComponent(parentId: hero.id),\n'
          "  SocketComponent(node: 'Hand.R'),\n"
          '  Sphere3D(radius: 0.06, emission: Color(0xFF19E6FF)),\n'
          ']);',
    cameras =>
      'world.createEntityWithComponents([\n'
          '  TransformComponent(),\n'
          '  VirtualCameraComponent(\n'
          "    follow: EntityTarget.name('Hero'),\n"
          '    projection: CameraProjection.perspective,\n'
          '    fieldOfView: 0.95, nearClip: 0.1, farClip: 300,\n'
          '  ),\n'
          '  OrbitFollowComponent(distance: 6, pitch: -0.3,\n'
          '      pivot: Vector3(0, -1.2, 0)),\n'
          "], name: 'Orbit Cam');\n"
          '// A camera that stays put and aims:  LookAtComponent(offset: ...)\n'
          '// The hero\'s eyes:  FirstPersonComponent(eye: Vector3(0, -1.6, 0))\n\n'
          '// The brain goes live on the highest priority and blends to it:\n'
          'engine.cameraSystem.brain.defaultBlend = CameraBlend(duration: 1.2);\n'
          'securityCam.getComponent<VirtualCameraComponent>()!.priority = 20;',
  };
}

// -----------------------------------------------------------------------------
// Data
// -----------------------------------------------------------------------------

/// A sky preset for the environment demo.
class _SkyPreset {
  const _SkyPreset({
    required this.name,
    required this.zenith,
    required this.horizon,
    required this.ground,
    required this.ambientSky,
    required this.ambientGround,
    required this.fogColor,
    required this.fogDensity,
    required this.fogStart,
    required this.exposure,
    required this.sunColor,
    required this.sunIntensity,
    required this.sunPitch,
    required this.sunYaw,
  });

  final String name;
  final Color zenith, horizon, ground, ambientSky, ambientGround, fogColor;
  final double fogDensity, fogStart, exposure;
  final Color sunColor;
  final double sunIntensity, sunPitch, sunYaw;
}

const List<_SkyPreset> _skyPresets = [
  _SkyPreset(
    name: 'Day',
    zenith: Color(0xFF2B62C0),
    horizon: Color(0xFFC9DCEF),
    ground: Color(0xFF6E5D4B),
    ambientSky: Color(0xFFA9C1E6),
    ambientGround: Color(0xFF7A6550),
    fogColor: Color(0xFFE6D5C3),
    fogDensity: 0.012,
    fogStart: 20,
    exposure: 1.05,
    sunColor: Color(0xFFFFF4E0),
    sunIntensity: 1.3,
    sunPitch: -0.9,
    sunYaw: 0.6,
  ),
  _SkyPreset(
    name: 'Sunset',
    zenith: Color(0xFF1E2A5A),
    horizon: Color(0xFFFF9A5A),
    ground: Color(0xFF4A3428),
    ambientSky: Color(0xFFC08A70),
    ambientGround: Color(0xFF5A4038),
    fogColor: Color(0xFFF2A774),
    fogDensity: 0.02,
    fogStart: 10,
    exposure: 1.15,
    sunColor: Color(0xFFFFB070),
    sunIntensity: 1.1,
    sunPitch: -0.2,
    sunYaw: math.pi,
  ),
  _SkyPreset(
    name: 'Night',
    zenith: Color(0xFF03060F),
    horizon: Color(0xFF101A33),
    ground: Color(0xFF07080C),
    ambientSky: Color(0xFF2A3550),
    ambientGround: Color(0xFF0E1018),
    fogColor: Color(0xFF0B1020),
    fogDensity: 0.03,
    fogStart: 8,
    exposure: 1.0,
    sunColor: Color(0xFF9DB4FF),
    sunIntensity: 0.35,
    sunPitch: -1.1,
    sunYaw: 0.3,
  ),
  _SkyPreset(
    name: 'Fog',
    zenith: Color(0xFF8C949C),
    horizon: Color(0xFFC4C8CC),
    ground: Color(0xFF6E6E6E),
    ambientSky: Color(0xFFB8BEC4),
    ambientGround: Color(0xFF70706E),
    fogColor: Color(0xFFC9CDD1),
    fogDensity: 0.06,
    fogStart: 2,
    exposure: 1.0,
    sunColor: Color(0xFFE8ECF0),
    sunIntensity: 0.6,
    sunPitch: -1.0,
    sunYaw: 0.8,
  ),
  _SkyPreset(
    name: 'Alien',
    zenith: Color(0xFF2A0A4A),
    horizon: Color(0xFF2EE6A8),
    ground: Color(0xFF3A1A20),
    ambientSky: Color(0xFF8A5CFF),
    ambientGround: Color(0xFF2E8A6A),
    fogColor: Color(0xFF4CFFC0),
    fogDensity: 0.025,
    fogStart: 6,
    exposure: 1.2,
    sunColor: Color(0xFFFF7AF0),
    sunIntensity: 1.0,
    sunPitch: -0.6,
    sunYaw: 2.2,
  ),
];

/// The hero's clips (hero.glb).
const List<String> _heroClips = [
  'idle',
  'walk',
  'run',
  'jump',
  'crouch_idle',
  'crouch_walk',
  'combat_idle',
  'punch_1',
  'punch_2',
  'punch_3',
  'kick_1',
  'kick_2',
  'kick_3',
];

/// The combos of hero.animator.json, with each strike's length
/// (hero.combos.json in the third-person template).
const List<(String, double)> _punchCombo = [
  ('punch_1', 0.4667),
  ('punch_2', 0.6),
  ('punch_3', 0.7333),
];
const List<(String, double)> _kickCombo = [
  ('kick_1', 0.6667),
  ('kick_2', 0.8667),
  ('kick_3', 0.9333),
];

const String _heroModel = 'assets/models/hero.glb';
const String _heroGraph = 'assets/models/hero.animator.json';

String _mat(String name) => 'assets/materials/pbr_$name.material.json';

// -----------------------------------------------------------------------------
// ECS helper
// -----------------------------------------------------------------------------

/// Runs the screen's animation inside the engine: [onUpdate] in the fixed
/// update, before animation (priority 95), and [onFrame] once per rendered
/// frame, before the camera brain follows.
class _UpdateHook extends System implements FrameSystem {
  _UpdateHook(this.onUpdate, {this.onFrame}) {
    priority = 95;
  }

  final void Function(double dt) onUpdate;
  final void Function(double dt)? onFrame;

  @override
  List<Type> get requiredComponents => const [];

  @override
  void update(double deltaTime) => onUpdate(deltaTime);

  @override
  void frame(double deltaTime, double alpha) => onFrame?.call(deltaTime);
}

// -----------------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------------

class Graphics3DScreen extends StatefulWidget {
  const Graphics3DScreen({super.key});

  @override
  State<Graphics3DScreen> createState() => _Graphics3DScreenState();
}

class _Graphics3DScreenState extends State<Graphics3DScreen>
    with SingleTickerProviderStateMixin {
  Engine? _engine;
  Object? _startError;
  bool _disposed = false;
  _Demo _demo = _Demo.shapes;

  late final Ticker _hud;
  Duration _lastHud = Duration.zero;

  // ── Per-demo state ─────────────────────────────────────────────────────
  double _time = 0;
  OrbitFollowComponent? _orbit;
  VirtualCameraComponent? _orbitCam;
  void Function(double dt)? _step;
  double _frameTime = 0;
  void Function(double dt)? _frameStep;

  /// Transforms moved by [_step] each update: their previous pose is
  /// captured first, so the renderer draws them between updates.
  final List<TransformComponent> _moving = [];
  final List<(TransformComponent, double)> _spinners = [];

  // Shapes
  final List<String> _galleryNames = [];
  String _focus = 'Overview';

  // Materials
  MaterialOverrides3D? _overrides;
  double _tweakRoughness = 0.35;
  double _tweakMetallic = 0.5;
  double _tweakGlow = 0;
  double _tweakHue = 215;
  bool _bloom = false;

  // Lights
  Entity? _sunEntity, _spotEntity;
  final List<Entity> _pointLights = [];
  bool _sunOn = true, _pointsOn = true, _spotOn = true, _shadows = true;
  bool _autoSun = true;
  double _sunYaw = 0.6;
  double _pointIntensity = 14;

  // Environment
  EnvironmentComponent? _env;
  LightComponent? _envSun;
  TransformComponent? _envSunTransform;
  int _preset = 0;

  // Model
  Entity? _hero;
  bool _graphMode = true;
  double _heroSpeed = 0;
  double _clipSpeed = 1;
  bool _walkCircle = false;
  bool _crouch = false;
  bool _goldOutfit = false;
  bool _handLight = true;
  Entity? _handOrb;
  double _heroAngle = 0;
  double _jumpTime = -1;
  double _strikeLeft = 0, _guardLeft = 0;
  int _comboStep = 0;
  bool _comboKick = false;
  String _clip = 'idle';

  // Cameras
  final Map<String, Entity> _rigs = {};
  String _liveRig = 'Orbit Cam';
  double _blendSeconds = 1.2;

  // Pointer
  Offset? _lastPointer;

  @override
  void initState() {
    super.initState();
    _hud = createTicker(_onHud);
    unawaited(_start());
  }

  Future<void> _start() async {
    final Engine engine;
    try {
      engine = await Demo3DEngine.create(physics: false);
    } on Object catch (e) {
      if (!_disposed) setState(() => _startError = e);
      return;
    }
    if (_disposed) {
      // The screen went while the engine was starting.
      unawaited(engine.dispose());
      return;
    }
    engine.world.addSystem(_UpdateHook(_onUpdate, onFrame: _onFrame));
    _engine = engine;
    _buildDemo(_demo);
    _hud.start();
  }

  @override
  void dispose() {
    _disposed = true;
    _hud.dispose();
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

  void _onUpdate(double dt) {
    _time += dt;
    for (final t in _moving) {
      t.capturePrevious();
    }
    for (final (t, speed) in _spinners) {
      t.eulerY = t.eulerY + speed * dt;
    }
    _step?.call(dt);
  }

  void _onFrame(double dt) {
    _frameTime += dt;
    _frameStep?.call(dt);
  }

  World get _world => _engine!.world;

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

  /// A transform the update step moves: captured each update.
  TransformComponent _animated(Entity entity) {
    final t = entity.getComponent<TransformComponent>()!;
    _moving.add(t);
    return t;
  }

  void _spin(Entity entity, double speed) {
    _spinners.add((_animated(entity), speed));
  }

  EnvironmentComponent _skyOf(_SkyPreset p) => EnvironmentComponent(
    zenith: p.zenith,
    horizon: p.horizon,
    ground: p.ground,
    ambientSky: p.ambientSky,
    ambientGround: p.ambientGround,
    exposure: p.exposure,
    background: const Color(0xFF1A1A2E),
    fog: true,
    fogColor: p.fogColor,
    fogDensity: p.fogDensity,
    fogStart: p.fogStart,
    reflections: true,
  );

  Entity _sun({
    double pitch = -0.9,
    double yaw = 0.6,
    double intensity = 1.3,
    Color color = const Color(0xFFFFF4E0),
  }) => _spawn('Sun', Vector3(0, -12, 0), [
    LightComponent(
      kind: LightKind.directional,
      color: color,
      intensity: intensity,
    ),
  ], euler: Vector3(pitch, yaw, 0));

  /// A floor slab whose top is at y = 0.
  Entity _floor(double size, {double depth = 0, double z = 0}) =>
      _spawn('Floor', Vector3(0, 0.5, z), [
        Cube3D(
          width: size,
          height: 1,
          depth: depth > 0 ? depth : size,
          material: _mat('stone'),
          color: const Color(0xFF5F5A55),
          roughness: 0.92,
        ),
      ]);

  /// An orbit camera following the entity named [target]; drag and the
  /// mouse wheel turn and move it.
  Entity _orbitCamera(
    String target, {
    double distance = 10,
    double yaw = 0.5,
    double pitch = -0.35,
    Vector3? pivot,
    double minDistance = 2,
    double maxDistance = 30,
    String name = 'Orbit Cam',
    int priority = 10,
  }) {
    final orbit = OrbitFollowComponent(
      distance: distance,
      minDistance: minDistance,
      maxDistance: maxDistance,
      yaw: yaw,
      pitch: pitch,
      minPitch: -1.35,
      maxPitch: -0.05,
      pivot: pivot ?? Vector3.zero(),
      damping: 0.12,
    );
    final vcam = VirtualCameraComponent(
      priority: priority,
      follow: EntityTarget.name(target),
      projection: CameraProjection.perspective,
      fieldOfView: 0.95,
      nearClip: 0.1,
      farClip: 400,
    );
    _orbit = orbit;
    _orbitCam = vcam;
    return _spawn(name, Vector3.zero(), [vcam, orbit]);
  }

  // ---------------------------------------------------------------------------
  // Demo builders
  // ---------------------------------------------------------------------------

  void _buildDemo(_Demo demo) {
    final engine = _engine;
    if (engine == null) return;
    engine.world.destroyAllEntities();
    // The new shots start where they are, not blended from the last demo's.
    final brain = engine.cameraSystem.brain
      ..reset()
      ..defaultBlend = const CameraBlend();
    brain.updateMode = CameraUpdateMode.frame;
    _orbit = null;
    _orbitCam = null;
    _step = null;
    _frameStep = null;
    _frameTime = 0;
    _moving.clear();
    _spinners.clear();
    _galleryNames.clear();
    _overrides = null;
    _sunEntity = null;
    _spotEntity = null;
    _pointLights.clear();
    _env = null;
    _envSun = null;
    _envSunTransform = null;
    _hero = null;
    _handOrb = null;
    _rigs.clear();
    _time = 0;
    final graphics = engine.graphics3D;
    if (graphics != null && graphics.isStarted) {
      graphics.renderer.shadows.enabled = true;
      graphics.renderer.bloom.enabled = false;
    }
    _bloom = false;
    _shadows = true;

    switch (demo) {
      case _Demo.shapes:
        _buildShapes();
      case _Demo.materials:
        _buildMaterials();
      case _Demo.lights:
        _buildLights();
      case _Demo.environment:
        _buildEnvironment();
      case _Demo.model:
        _buildModel();
      case _Demo.cameras:
        _buildCameras();
    }
    if (mounted) setState(() => _demo = demo);
  }

  // ── Shapes ─────────────────────────────────────────────────────────────

  static List<Offset> _star(int points, double outer, double inner) => [
    for (var i = 0; i < points * 2; i++)
      Offset(
        (i.isEven ? outer : inner) * math.cos(math.pi * i / points),
        (i.isEven ? outer : inner) * math.sin(math.pi * i / points),
      ),
  ];

  void _buildShapes() {
    _world.createEntityWithComponents([_skyOf(_skyPresets[0])], name: 'Sky');
    _sun();
    _spawn('Stage', Vector3(0, 0.25, 0), [
      Cylinder3D(
        radius: 8,
        height: 0.5,
        segments: 64,
        material: _mat('marble'),
        color: const Color(0xFFF1ECE4),
        roughness: 0.18,
      ),
    ]);
    _spawn('Pivot', Vector3.zero(), const []);
    // A glowing orb in the middle, lighting the shapes from inside the ring.
    final orb = _spawn('Orb', Vector3(0, -1.6, 0), [
      Sphere3D(
        radius: 0.35,
        material: _mat('neon'),
        color: const Color(0xFF0E1220),
        emission: const Color(0xFF19E6FF),
        emissionStrength: 4,
        castShadows: false,
      ),
      LightComponent(color: const Color(0xFF7FEFFF), intensity: 10, range: 9),
    ]);
    final orbT = _animated(orb);

    final gallery = <(String, Primitive3D, double, Vector3?)>[
      (
        'Gold Cube',
        Cube3D(
          width: 1.1,
          height: 1.1,
          depth: 1.1,
          material: _mat('gold'),
          color: const Color(0xFFFFC356),
          metallic: 1,
          roughness: 0.22,
        ),
        0.55,
        null,
      ),
      (
        'Chrome Sphere',
        Sphere3D(
          radius: 0.65,
          segments: 48,
          rings: 24,
          material: _mat('chrome'),
          color: const Color(0xFFE9ECF1),
          metallic: 1,
          roughness: 0.04,
        ),
        0.65,
        null,
      ),
      (
        'Copper Cylinder',
        Cylinder3D(
          radius: 0.5,
          height: 1.3,
          segments: 40,
          material: _mat('copper'),
          color: const Color(0xFFE59A6E),
          metallic: 1,
          roughness: 0.32,
        ),
        0.65,
        null,
      ),
      (
        'Jade Capsule',
        Capsule3D(
          radius: 0.4,
          height: 1.5,
          material: _mat('jade'),
          color: const Color(0xFF3FA27A),
          roughness: 0.28,
        ),
        0.75,
        null,
      ),
      (
        'Ruby Cone',
        Cone3D(
          radius: 0.6,
          height: 1.3,
          segments: 40,
          material: _mat('ruby'),
          color: const Color(0xFFC3172F),
          roughness: 0.14,
        ),
        0.65,
        null,
      ),
      (
        'Neon Torus',
        Torus3D(
          radius: 0.55,
          tubeRadius: 0.18,
          material: _mat('neon'),
          color: const Color(0xFF0E1220),
          emission: const Color(0xFF19E6FF),
          emissionStrength: 4,
        ),
        0.75,
        Vector3(math.pi / 2, 0, 0), // stood up: a ring lies flat
      ),
      (
        'Glass Pane',
        Plane3D(
          width: 1.3,
          depth: 1.5,
          material: _mat('glass'),
          color: const Color(0xFFC8ECFF),
          roughness: 0.04,
          opacity: 0.32,
        ),
        0.75,
        Vector3(math.pi / 2, 0, 0), // stood up: a plane lies on the ground
      ),
      (
        'Marble Stairs',
        Stairs3D(
          width: 1,
          height: 1,
          depth: 1.4,
          steps: 5,
          material: _mat('marble'),
          color: const Color(0xFFF1ECE4),
          roughness: 0.18,
        ),
        0.5,
        null,
      ),
      (
        'Rubber Ramp',
        Ramp3D(
          width: 1,
          height: 0.8,
          depth: 1.5,
          material: _mat('rubber'),
          color: const Color(0xFF24272D),
          roughness: 0.95,
        ),
        0.4,
        null,
      ),
      (
        'Obsidian Arch',
        Arch3D(
          radius: 0.85,
          thickness: 0.24,
          depth: 0.4,
          material: _mat('obsidian'),
          color: const Color(0xFF17131F),
          metallic: 0.3,
          roughness: 0.07,
        ),
        0.425,
        null,
      ),
      (
        'Lava Star',
        Polygon3D(
          points: _star(5, 0.75, 0.34),
          height: 0.4,
          material: _mat('lava'),
          color: const Color(0xFF2A0A05),
          emission: const Color(0xFFFF5A1F),
          emissionStrength: 3,
        ),
        0.2,
        null,
      ),
    ];
    for (var i = 0; i < gallery.length; i++) {
      final (name, shape, lift, euler) = gallery[i];
      final a = 2 * math.pi * i / gallery.length;
      final e = _spawn(
        name,
        Vector3(5.2 * math.sin(a), -lift, 5.2 * math.cos(a)),
        [shape],
        euler: euler,
      );
      _spin(e, 0.35 + 0.05 * (i % 3));
      _galleryNames.add(name);
    }
    _focus = 'Overview';
    _orbitCamera(
      'Pivot',
      distance: 14,
      yaw: math.pi,
      pitch: -0.42,
    ).getComponent<OrbitFollowComponent>()!.pivot.setValues(0, -0.8, 0);

    _step = (dt) {
      // The orb bobs and the whole ring of shapes keeps spinning.
      orbT.position.y = -1.6 - 0.25 * math.sin(_time * 1.3);
    };
  }

  void _focusOn(String name) {
    final orbit = _orbit, vcam = _orbitCam;
    if (orbit == null || vcam == null) return;
    setState(() => _focus = name);
    if (name == 'Overview') {
      vcam.follow = const EntityTarget.name('Pivot');
      orbit
        ..distance = 14
        ..pitch = -0.42;
      orbit.pivot.setValues(0, -0.8, 0);
    } else {
      vcam.follow = EntityTarget.name(name);
      orbit
        ..distance = 3.4
        ..pitch = -0.3;
      orbit.pivot.setValues(0, 0, 0);
    }
  }

  // ── Materials ──────────────────────────────────────────────────────────

  void _buildMaterials() {
    _world.createEntityWithComponents([_skyOf(_skyPresets[0])], name: 'Sky');
    _sun(pitch: -0.75, yaw: 0.5);
    _floor(30);
    _spawn('Pivot', Vector3(1, 0, 1.4), const []);

    // Risers for the two rows of inline values.
    for (var row = 1; row <= 2; row++) {
      final h = 0.45 * row;
      _spawn('Riser $row', Vector3(0, -h / 2, 0.6 + 1.2 * row), [
        Cube3D(
          width: 9.6,
          height: h,
          depth: 1.1,
          material: _mat('stone'),
          color: const Color(0xFF5F5A55),
        ),
      ]);
    }
    // Back rows: inline metallic × roughness, no file.
    const roughness = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];
    for (var row = 1; row <= 2; row++) {
      final metal = row == 2;
      for (var i = 0; i < roughness.length; i++) {
        _spawn(
          '${metal ? 'Metal' : 'Plastic'} r${roughness[i]}',
          Vector3(-3.75 + i * 1.5, -0.45 * row - 0.4, 0.6 + 1.2 * row),
          [
            Sphere3D(
              radius: 0.4,
              segments: 40,
              rings: 20,
              color: metal ? const Color(0xFFE0E4EA) : const Color(0xFFD23C3C),
              metallic: metal ? 1 : 0,
              roughness: roughness[i],
            ),
          ],
        );
      }
    }
    // Front row: shared material files (a variant beside its parent).
    const files = [
      ('gold', Color(0xFFFFC356)),
      ('gold_brushed', Color(0xFFE8B860)),
      ('copper', Color(0xFFE59A6E)),
      ('chrome', Color(0xFFE9ECF1)),
      ('obsidian', Color(0xFF17131F)),
      ('jade', Color(0xFF3FA27A)),
      ('ruby', Color(0xFFC3172F)),
      ('marble', Color(0xFFF1ECE4)),
      ('glass', Color(0xFFC8ECFF)),
      ('neon', Color(0xFF0E1220)),
    ];
    for (var i = 0; i < files.length; i++) {
      final (name, color) = files[i];
      final e = _spawn('pbr_$name', Vector3(-4.275 + i * 0.95, -0.38, 0.4), [
        Sphere3D(
          radius: 0.38,
          segments: 40,
          rings: 20,
          material: _mat(name),
          color: color,
        ),
      ]);
      _spin(e, 0.5);
    }
    // The orb with its own values on top of its material file.
    final overrides = MaterialOverrides3D();
    _overrides = overrides;
    _spawn('Tweak Orb', Vector3(6.3, -1.0, 1.0), [
      Sphere3D(
        radius: 1.0,
        segments: 56,
        rings: 28,
        material: _mat('tweak'),
        color: const Color(0xFF6FA8FF),
      ),
      overrides,
    ]);
    _applyOverrides();
    _orbitCamera(
      'Pivot',
      distance: 11,
      yaw: 0,
      pitch: -0.34,
      pivot: Vector3(0, -0.9, 0),
    );
  }

  void _applyOverrides() {
    final overrides = _overrides;
    if (overrides == null) return;
    final color = HSVColor.fromAHSV(1, _tweakHue, 0.62, 1).toColor();
    overrides
      ..set('roughness', _tweakRoughness)
      ..set('metallic', _tweakMetallic)
      ..set('color', color.toARGB32())
      ..set('emission', color.toARGB32())
      ..set('emissionStrength', _tweakGlow);
  }

  void _setBloom(bool on) {
    final graphics = _engine?.graphics3D;
    if (graphics != null && graphics.isStarted) {
      graphics.renderer.bloom.enabled = on;
    }
    setState(() => _bloom = on);
  }

  void _setShadows(bool on) {
    final graphics = _engine?.graphics3D;
    if (graphics != null && graphics.isStarted) {
      graphics.renderer.shadows.enabled = on;
    }
    setState(() => _shadows = on);
  }

  // ── Lights ─────────────────────────────────────────────────────────────

  void _buildLights() {
    // A dark room: no sky, faint ambient, so each light reads clearly.
    _world.createEntityWithComponents([
      EnvironmentComponent(
        sky: false,
        background: const Color(0xFF05060A),
        zenith: const Color(0xFF0A0F1E),
        horizon: const Color(0xFF151A28),
        ground: const Color(0xFF08080A),
        ambientSky: const Color(0xFF1A2030),
        ambientGround: const Color(0xFF0D0D12),
        exposure: 1.1,
        reflections: false,
      ),
    ], name: 'Night');
    _floor(26);
    _spawn('Pivot', Vector3.zero(), const []);
    _spawn('Pedestal', Vector3(0, -0.3, 0), [
      Cylinder3D(radius: 0.9, height: 0.6, material: _mat('obsidian')),
    ]);
    final center = _spawn('Centerpiece', Vector3(0, -1.45, 0), [
      Torus3D(
        radius: 0.6,
        tubeRadius: 0.22,
        segments: 48,
        sides: 20,
        material: _mat('chrome'),
        color: const Color(0xFFE9ECF1),
        metallic: 1,
        roughness: 0.05,
      ),
    ], euler: Vector3(math.pi / 2, 0, 0));
    _spin(center, 0.6);
    for (var i = 0; i < 6; i++) {
      final a = 2 * math.pi * i / 6;
      _spawn('Pillar $i', Vector3(3.4 * math.sin(a), -1.5, 3.4 * math.cos(a)), [
        Cylinder3D(radius: 0.32, height: 3, material: _mat('marble')),
      ]);
      _spawn(
        'Block $i',
        Vector3(5.6 * math.sin(a + 0.5), -0.4, 5.6 * math.cos(a + 0.5)),
        [Cube3D(width: 0.8, height: 0.8, depth: 0.8, material: _mat('copper'))],
        euler: Vector3(0, a, 0),
      );
    }

    _sunEntity = _sun(
      pitch: -0.7,
      yaw: _sunYaw,
      intensity: 0.7,
      color: const Color(0xFFAFC4FF),
    );
    final sunT = _sunEntity!.getComponent<TransformComponent>()!;

    const colors = [Color(0xFFFF3B5C), Color(0xFF3BFF8A), Color(0xFF4A7BFF)];
    final points = <TransformComponent>[];
    for (var i = 0; i < colors.length; i++) {
      final light = _spawn('Point ${i + 1}', Vector3(0, -1.2, 0), [
        LightComponent(color: colors[i], intensity: _pointIntensity, range: 8),
        // A marker: unlit, so it shows the light's colour as it is.
        Sphere3D(
          radius: 0.1,
          color: colors[i],
          unlit: true,
          castShadows: false,
        ),
      ]);
      _pointLights.add(light);
      points.add(_animated(light));
    }

    _spotEntity = _spawn('Spot', Vector3(0, -7, 0), [
      LightComponent(
        kind: LightKind.spot,
        color: const Color(0xFFFFE6B0),
        intensity: 90,
        range: 16,
        innerConeAngle: 0.18,
        outerConeAngle: 0.36,
      ),
      Sphere3D(
        radius: 0.18,
        color: const Color(0xFFFFE6B0),
        unlit: true,
        castShadows: false,
      ),
    ], euler: Vector3(-1.3, 0, 0));
    final spotT = _animated(_spotEntity!);
    _applyLightToggles();

    _orbitCamera(
      'Pivot',
      distance: 11,
      yaw: 0.4,
      pitch: -0.5,
      pivot: Vector3(0, -1, 0),
    );

    _step = (dt) {
      for (var i = 0; i < points.length; i++) {
        final a = _time * (0.7 + 0.15 * i) + 2 * math.pi * i / points.length;
        points[i].position.setValues(
          2.3 * math.sin(a),
          -1.0 - 0.6 * math.sin(_time * 1.1 + i),
          2.3 * math.cos(a),
        );
      }
      // The spot sweeps a circle round the centre from above.
      final sweep = _time * 0.6;
      spotT.setEuler(-1.25 + 0.12 * math.sin(_time * 0.9), sweep, 0);
      if (_autoSun) {
        _sunYaw = (_sunYaw + dt * 0.25) % (2 * math.pi);
      }
      sunT.setEuler(-0.7, _sunYaw, 0);
    };
  }

  void _applyLightToggles() {
    _sunEntity?.isActive = _sunOn;
    _spotEntity?.isActive = _spotOn;
    for (final p in _pointLights) {
      p.isActive = _pointsOn;
      p.getComponent<LightComponent>()?.intensity = _pointIntensity;
    }
  }

  // ── Environment ────────────────────────────────────────────────────────

  void _buildEnvironment() {
    final env = _skyOf(_skyPresets[_preset]);
    _env = env;
    _world.createEntityWithComponents([env], name: 'Sky');
    final sun = _sun();
    _envSun = sun.getComponent<LightComponent>();
    _envSunTransform = sun.getComponent<TransformComponent>();
    _floor(80, depth: 220, z: 70);
    _spawn('Pivot', Vector3(0, 0, 4), const []);
    // A colonnade running into the distance, to show the fog.
    for (var i = 0; i < 18; i++) {
      for (final x in const [-3.6, 3.6]) {
        _spawn('Column ${i}_$x', Vector3(x, -2.25, -4 + i * 5.0), [
          Cylinder3D(
            radius: 0.38,
            height: 4.5,
            material: _mat('marble'),
            color: const Color(0xFFF1ECE4),
          ),
        ]);
      }
      _spawn('Lintel $i', Vector3(0, -4.7, -4 + i * 5.0), [
        Cube3D(width: 8.2, height: 0.4, depth: 0.9, material: _mat('marble')),
      ]);
    }
    // Shiny things reflect the sky.
    _spawn('Mirror Ball', Vector3(0, -0.95, 3), [
      Sphere3D(
        radius: 0.95,
        segments: 56,
        rings: 28,
        material: _mat('chrome'),
        color: const Color(0xFFE9ECF1),
        metallic: 1,
        roughness: 0.04,
      ),
    ]);
    final ring = _spawn('Gold Ring', Vector3(-1.9, -0.85, 5.5), [
      Torus3D(radius: 0.6, tubeRadius: 0.2, material: _mat('gold')),
    ], euler: Vector3(math.pi / 2, 0, 0));
    _spin(ring, 0.7);
    final cube = _spawn('Copper Cube', Vector3(1.9, -0.5, 5.5), [
      Cube3D(width: 0.9, height: 0.9, depth: 0.9, material: _mat('copper')),
    ]);
    _spin(cube, -0.5);
    _applyPreset(_preset);
    _orbitCamera(
      'Pivot',
      distance: 9,
      yaw: 0,
      pitch: -0.16,
      maxDistance: 40,
      pivot: Vector3(0, -1.6, 0),
    );
  }

  void _applyPreset(int index) {
    final p = _skyPresets[index];
    final env = _env;
    if (env != null) {
      env
        ..zenith = p.zenith
        ..horizon = p.horizon
        ..ground = p.ground
        ..ambientSky = p.ambientSky
        ..ambientGround = p.ambientGround
        ..exposure = p.exposure
        ..fogColor = p.fogColor
        ..fogDensity = p.fogDensity
        ..fogStart = p.fogStart;
    }
    _envSun
      ?..color = p.sunColor
      ..intensity = p.sunIntensity;
    _envSunTransform?.setEuler(p.sunPitch, p.sunYaw, 0);
    setState(() => _preset = index);
  }

  // ── Model ──────────────────────────────────────────────────────────────

  /// The hero: hero.glb, played by an animator graph through its
  /// animation player, a glowing orb in its right hand.
  Entity _spawnHero(Vector3 at, {bool handOrb = true}) {
    final animator = AnimatorComponent(graphPath: _heroGraph);
    // Parameters the third-person kit would bind; set from code here. Set
    // before the graph loads, they are kept.
    animator
      ..setBool('grounded', true)
      ..setFloat('onGround', 1)
      ..setBool('jumping', false)
      ..setBool('crouching', false)
      ..setBool('striking', false)
      ..setBool('inCombat', false)
      ..setFloat('planarSpeed', 0);
    final hero = _spawn('Hero', at, [
      ModelComponent(model: _heroModel),
      AnimationPlayerComponent(clip: 'idle'),
      animator,
    ]);
    if (handOrb) {
      _handOrb = _world.createEntityWithComponents([
        TransformComponent(),
        ParentComponent(parentId: hero.id),
        SocketComponent(node: 'Hand.R'),
        Sphere3D(
          radius: 0.06,
          color: const Color(0xFF0E1220),
          emission: const Color(0xFF19E6FF),
          emissionStrength: 6,
          castShadows: false,
        ),
        LightComponent(color: const Color(0xFF19E6FF), intensity: 4, range: 3),
      ], name: 'Hand Orb');
      _handOrb!.isActive = _handLight;
    }
    return hero;
  }

  AnimatorComponent? get _animator => _hero?.getComponent<AnimatorComponent>();
  AnimationPlayerComponent? get _player =>
      _hero?.getComponent<AnimationPlayerComponent>();

  void _buildModel() {
    _world.createEntityWithComponents([_skyOf(_skyPresets[0])], name: 'Sky');
    _sun(pitch: -0.85, yaw: 2.4);
    _spawn('Stage', Vector3(0, 0.25, 0), [
      Cylinder3D(
        radius: 7,
        height: 0.5,
        segments: 64,
        material: _mat('stone'),
        color: const Color(0xFF5F5A55),
      ),
    ]);
    _heroAngle = 0;
    _jumpTime = -1;
    _strikeLeft = 0;
    _guardLeft = 0;
    _comboStep = 0;
    final hero = _spawnHero(Vector3.zero());
    _hero = hero;
    final heroT = _animated(hero);
    _applyOutfit();
    _applyGraphMode();

    // Props: other glTF models.
    for (var i = 0; i < 3; i++) {
      _spawn('Crate ${i + 1}', Vector3(3.2 + i * 1.05, -0.5, 1.6), [
        ModelComponent(model: 'assets/models/crate.glb'),
      ], euler: Vector3(0, 0.15 * i, 0));
    }
    _spawn('Crate 4', Vector3(3.7, -1.5, 1.6), [
      ModelComponent(model: 'assets/models/crate.glb'),
    ], euler: Vector3(0, 0.4, 0));
    _spawn('Flag', Vector3(-3.4, -1.0, 2.4), [
      ModelComponent(model: 'assets/models/flag.glb'),
    ]);
    final coins = <TransformComponent>[];
    for (var i = 0; i < 5; i++) {
      final a = -0.9 + i * 0.45;
      final coin = _spawn(
        'Coin ${i + 1}',
        Vector3(5 * math.sin(a), -1.0, -5 * math.cos(a)),
        [ModelComponent(model: 'assets/models/coin.glb', castShadows: false)],
      );
      _spin(coin, 2.0);
      coins.add(coin.getComponent<TransformComponent>()!);
    }

    _orbitCamera(
      'Hero',
      distance: 5.5,
      yaw: 0,
      pitch: -0.22,
      pivot: Vector3(0, -1.0, 0),
      maxDistance: 14,
    );

    _step = (dt) {
      for (var i = 0; i < coins.length; i++) {
        coins[i].position.y = -1.0 - 0.15 * math.sin(_time * 2 + i);
      }
      _stepHero(dt, heroT);
    };
  }

  void _stepHero(double dt, TransformComponent heroT) {
    final animator = _animator;
    if (animator == null) return;
    // Walking round a circle: the hero moves at the speed the blend tree
    // is told, so its feet keep to the ground.
    final speed = _graphMode ? _heroSpeed : 0.0;
    if (_walkCircle && speed > 0.05 && _strikeLeft <= 0) {
      const radius = 3.2;
      _heroAngle += speed / radius * dt;
      heroT.position.x = radius * math.sin(_heroAngle);
      heroT.position.z = radius * -math.cos(_heroAngle);
      // Facing along the circle; the model faces -Z, hence + pi.
      final dx = math.cos(_heroAngle), dz = math.sin(_heroAngle);
      heroT.eulerY = math.atan2(dx, dz) + math.pi;
    }
    if (_graphMode) {
      animator
        ..setFloat('planarSpeed', _strikeLeft > 0 ? 0 : speed)
        ..setBool('crouching', _crouch);
    }
    // A jump, faked: off the ground for 0.7 s on a parabola.
    if (_jumpTime >= 0) {
      _jumpTime += dt;
      const length = 0.7;
      if (_jumpTime >= length) {
        _jumpTime = -1;
        heroT.position.y = 0;
        animator
          ..setBool('grounded', true)
          ..setFloat('onGround', 1)
          ..setBool('jumping', false);
      } else {
        final t = _jumpTime / length;
        heroT.position.y = -3.2 * t * (1 - t);
        animator.setBool('jumping', t < 0.4);
      }
    }
    if (_strikeLeft > 0) {
      _strikeLeft -= dt;
      if (_strikeLeft <= 0) animator.setBool('striking', false);
    }
    if (_guardLeft > 0) {
      _guardLeft -= dt;
      if (_guardLeft <= 0) {
        animator.setBool('inCombat', false);
        _comboStep = 0;
      }
    }
  }

  void _jump() {
    final animator = _animator;
    if (animator == null || _jumpTime >= 0 || !_graphMode) return;
    _jumpTime = 0;
    animator
      ..setBool('jumping', true)
      ..setBool('grounded', false)
      ..setFloat('onGround', 0);
  }

  void _strike({required bool kick}) {
    final animator = _animator;
    if (animator == null || _strikeLeft > 0 || !_graphMode) return;
    if (kick != _comboKick || _guardLeft <= 0) _comboStep = 0;
    _comboKick = kick;
    final chain = kick ? _kickCombo : _punchCombo;
    final (state, length) = chain[_comboStep % chain.length];
    animator
      ..setTrigger(state)
      ..setBool('striking', true)
      ..setBool('inCombat', true);
    _strikeLeft = length;
    _guardLeft = length + 1.5;
    _comboStep++;
  }

  void _applyGraphMode() {
    final animator = _animator, player = _player;
    if (animator == null || player == null) return;
    animator.enabled = _graphMode;
    if (_graphMode) {
      // From the graph's entry again.
      animator.restart();
    } else {
      _playClip(_clip);
    }
  }

  void _playClip(String clip) {
    final player = _player;
    if (player == null) return;
    player.play(clip, restart: true);
    // Set after play(), so what fades out keeps its own speed and looping.
    player
      ..speed = _clipSpeed
      ..loop =
          !(clip.startsWith('punch') ||
              clip.startsWith('kick') ||
              clip == 'jump');
    setState(() => _clip = clip);
  }

  void _applyOutfit() {
    final model = _hero?.getComponent<ModelComponent>();
    if (model == null) return;
    model.materials = _goldOutfit
        ? {'MAT_Cloth': _mat('gold'), 'MAT_Accent': _mat('neon')}
        : {};
  }

  // ── Cameras ────────────────────────────────────────────────────────────

  void _buildCameras() {
    _world.createEntityWithComponents([_skyOf(_skyPresets[0])], name: 'Sky');
    _sun(pitch: -0.8, yaw: 0.9);
    _spawn('Stage', Vector3(0, 0.25, 0), [
      Cylinder3D(
        radius: 13,
        height: 0.5,
        segments: 72,
        material: _mat('stone'),
        color: const Color(0xFF5F5A55),
      ),
    ]);
    for (var i = 0; i < 8; i++) {
      final a = 2 * math.pi * i / 8;
      _spawn('Pillar $i', Vector3(7 * math.sin(a), -1.75, 7 * math.cos(a)), [
        Cylinder3D(radius: 0.35, height: 3.5, material: _mat('marble')),
      ]);
    }
    _spawn('Arch', Vector3(0, -1.25, 5.2), [
      Arch3D(radius: 1.6, thickness: 0.35, depth: 0.6, material: _mat('jade')),
    ]);
    for (var i = 0; i < 3; i++) {
      _spawn('Crate ${i + 1}', Vector3(-2.2 + i * 0.4, -0.5 - i * 1.0, -5.5), [
        ModelComponent(model: 'assets/models/crate.glb'),
      ], euler: Vector3(0, 0.3 * i, 0));
    }

    _heroAngle = 0;
    _graphMode = true;
    final hero = _spawnHero(Vector3(0, 0, -4), handOrb: false);
    _hero = hero;
    final heroT = _animated(hero);
    final heroModel = hero.getComponent<ModelComponent>()!;
    _applyOutfit();
    hero.getComponent<AnimatorComponent>()!.setFloat('planarSpeed', 2.0);

    final brain = _engine!.cameraSystem.brain;
    brain.defaultBlend = CameraBlend(duration: _blendSeconds);

    // 1. Orbit: drag and wheel turn it.
    _rigs['Orbit Cam'] = _orbitCamera(
      'Hero',
      distance: 6.5,
      yaw: 0.6,
      pitch: -0.3,
      pivot: Vector3(0, -1.2, 0),
    );

    VirtualCameraComponent lens(int priority) => VirtualCameraComponent(
      priority: priority,
      follow: const EntityTarget.name('Hero'),
      projection: CameraProjection.perspective,
      fieldOfView: 0.95,
      nearClip: 0.1,
      farClip: 400,
    );

    // 2. A security camera bolted to a pillar, aiming at the hero.
    final securityAt = Vector3(9, -6, -9);
    _rigs['Security Cam'] = _spawn('Security Cam', securityAt, [
      lens(0),
      LookAtComponent(offset: Vector3(0, -1.1, 0), damping: 0.25),
    ]);
    final housing = _spawn('Camera Housing', securityAt, [
      Cube3D(
        width: 0.35,
        height: 0.3,
        depth: 0.6,
        material: _mat('obsidian'),
        castShadows: false,
      ),
    ]);
    final housingT = _animated(housing);
    _spawn('Camera Mast', Vector3(9.3, -3, -9.3), [
      Cylinder3D(radius: 0.08, height: 6, material: _mat('chrome')),
    ]);

    // 3. A crane swinging round the stage, aiming at the hero.
    final crane = _spawn('Crane Cam', Vector3(0, -4, 10), [
      lens(0),
      LookAtComponent(offset: Vector3(0, -1.0, 0), damping: 0.1),
    ]);
    _rigs['Crane Cam'] = crane;
    final craneT = crane.getComponent<TransformComponent>()!;

    // 4. The hero's eyes.
    final eyes = FirstPersonComponent(eye: Vector3(0, -1.62, 0), pitch: -0.08);
    _rigs['Eyes Cam'] = _spawn('Eyes Cam', Vector3.zero(), [lens(0), eyes]);

    _liveRig = 'Orbit Cam';
    _goLive(_liveRig);

    _step = (dt) {
      // The hero walks a circle at the walk clip's own pace.
      const radius = 4.0, speed = 2.0;
      _heroAngle += speed / radius * dt;
      heroT.position.setValues(
        radius * math.sin(_heroAngle),
        0,
        -radius * math.cos(_heroAngle),
      );
      final dx = math.cos(_heroAngle), dz = math.sin(_heroAngle);
      final heading = math.atan2(dx, dz);
      heroT.eulerY = heading + math.pi;
      eyes.yaw = heading;
      // Hidden from inside its own head.
      heroModel.visible = brain.liveCamera != _rigs['Eyes Cam'];
      // The housing turns to where its camera looks.
      final to = heroT.position - securityAt
        ..y -= 1.1;
      final (pitch, yaw) = cameraAnglesOf(to);
      housingT.setEuler(pitch, yaw, 0);
    };
    // The crane swings round, up and down: moved every rendered frame, as
    // the brain reads a camera's own transform where it is.
    _frameStep = (dt) {
      final c = _frameTime * 0.25;
      craneT.position.setValues(
        10 * math.sin(c),
        -3.5 - 1.5 * math.sin(_frameTime * 0.4),
        10 * math.cos(c),
      );
    };
  }

  void _goLive(String name) {
    for (final MapEntry(key: rig, value: entity) in _rigs.entries) {
      entity.getComponent<VirtualCameraComponent>()?.priority = rig == name
          ? 20
          : 0;
    }
    setState(() => _liveRig = name);
  }

  // ---------------------------------------------------------------------------
  // Pointer: orbit and zoom
  // ---------------------------------------------------------------------------

  void _onPointerMove(PointerMoveEvent e) {
    final last = _lastPointer;
    _lastPointer = e.localPosition;
    final orbit = _orbit;
    if (last == null || orbit == null || e.buttons == 0) return;
    final d = e.localPosition - last;
    orbit
      ..yaw += d.dx * 0.008
      ..pitch = (orbit.pitch - d.dy * 0.006).clamp(
        orbit.minPitch,
        orbit.maxPitch,
      );
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

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------

  String get _statsLine {
    final engine = _engine;
    if (engine == null) return 'starting the 3-D engine…';
    final graphics = engine.graphics3D;
    final base = 'entities ${engine.world.entityCount}';
    if (graphics == null || !graphics.isStarted) return base;
    final s = graphics.renderer.stats;
    return '$base  draws ${s.drawCalls}  instances ${s.instances}'
        '  tris ${s.triangles}  lights ${s.lights}'
        '  shadow casters ${s.shadowCasters}';
  }

  String get _statusMessage {
    final engine = _engine;
    if (engine == null) return '';
    switch (_demo) {
      case _Demo.shapes:
        return 'Focus: $_focus  ·  ${_galleryNames.length} shapes, one '
            'Primitive3D each, spinning on a fixed update';
      case _Demo.materials:
        final graphics = engine.graphics3D;
        if (graphics == null || !graphics.isStarted) return '';
        final library = graphics.sceneRenderer.materials;
        final brushed = library.fileOf(_mat('gold_brushed'));
        final gold = library.fileOf(_mat('gold'));
        if (brushed == null || gold == null) {
          return 'Reading material files…';
        }
        return 'pbr_gold roughness ${gold.roughness}  →  variant '
            'pbr_gold_brushed resolves to roughness ${brushed.roughness}, '
            'metallic ${brushed.metallic} (from its parent)';
      case _Demo.lights:
        return 'Sun ${_sunOn ? 'on' : 'off'}  ·  shadows '
            '${_shadows ? 'on' : 'off'}  ·  points ${_pointsOn ? 'on' : 'off'}'
            '  ·  spot ${_spotOn ? 'on' : 'off'}';
      case _Demo.environment:
        final env = _env;
        if (env == null) return '';
        return '${_skyPresets[_preset].name}  ·  fog '
            '${env.fog ? env.fogDensity.toStringAsFixed(3) : 'off'}  ·  '
            'exposure ${env.exposure.toStringAsFixed(2)}  ·  reflections '
            '${env.reflections ? env.reflectionStrength.toStringAsFixed(2) : 'off'}';
      case _Demo.model:
        final animator = _animator, player = _player;
        if (animator == null || player == null) return '';
        final clips = player.isBlending
            ? [
                for (var i = 0; i < player.blendClips.length; i++)
                  '${player.blendClips[i]} '
                      '${(player.blendWeights[i] * 100).round()}%',
              ].join(', ')
            : player.clip;
        return _graphMode
            ? 'Animator state: ${animator.currentState.isEmpty ? '(loading)' : animator.currentState}'
                  '  ·  playing: $clips'
            : 'Clip player: ${player.clip}  ·  '
                  '${player.time.toStringAsFixed(2)} / '
                  '${player.duration.toStringAsFixed(2)} s';
      case _Demo.cameras:
        final brain = engine.cameraSystem.brain;
        final blend = brain.activeBlend;
        return 'Live: ${brain.liveCamera?.name ?? '-'}'
            '${blend != null && !blend.isComplete ? '  ·  blending ${(blend.progress * 100).round()}%' : ''}';
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

  Widget _buildHeader() {
    final reason = _engine?.graphics3D?.unsupportedReason;
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
                  'Graphics3D  *  Primitive3D  *  LightComponent  *  ModelComponent',
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
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          if (reason != null) ...[
            const SizedBox(height: 3),
            Text(
              '3-D is not drawn here: $reason',
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
    final reason = engine.graphics3D?.unsupportedReason;
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerDown: (e) => _lastPointer = e.localPosition,
          onPointerMove: _onPointerMove,
          onPointerUp: (_) => _lastPointer = null,
          onPointerSignal: _onPointerSignal,
          child: GameWidget(engine: engine, showFPS: true),
        ),
        Positioned(
          left: 12,
          bottom: 10,
          child: IgnorePointer(
            child: Text(
              _orbit == null ? '' : 'Drag to orbit  *  Scroll to zoom',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ),
        if (reason != null)
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
                  'Graphics3D.unsupportedReason: $reason',
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
    switch (_demo) {
      case _Demo.shapes:
        return Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _label('Fly to:'),
            for (final name in ['Overview', ..._galleryNames])
              _choice(name, _focus == name, () => _focusOn(name)),
          ],
        );
      case _Demo.materials:
        return Wrap(
          spacing: 12,
          runSpacing: 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _slider('Roughness', _tweakRoughness, 0, 1, (v) {
              setState(() => _tweakRoughness = v);
              _applyOverrides();
            }),
            _slider('Metallic', _tweakMetallic, 0, 1, (v) {
              setState(() => _tweakMetallic = v);
              _applyOverrides();
            }),
            _slider('Glow', _tweakGlow, 0, 8, (v) {
              setState(() => _tweakGlow = v);
              _applyOverrides();
            }),
            _slider('Hue', _tweakHue, 0, 360, (v) {
              setState(() => _tweakHue = v);
              _applyOverrides();
            }, format: (v) => '${v.round()}°'),
            _toggle('Bloom', _bloom, _setBloom),
            _actionButton('File values', _demo.accentColor, () {
              _overrides?.values = const {};
              setState(() {});
            }),
          ],
        );
      case _Demo.lights:
        return Wrap(
          spacing: 8,
          runSpacing: 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _toggle('Sun', _sunOn, (v) {
              setState(() => _sunOn = v);
              _applyLightToggles();
            }),
            _toggle('Shadows', _shadows, _setShadows),
            _toggle('Points', _pointsOn, (v) {
              setState(() => _pointsOn = v);
              _applyLightToggles();
            }),
            _toggle('Spot', _spotOn, (v) {
              setState(() => _spotOn = v);
              _applyLightToggles();
            }),
            _toggle('Sun turns', _autoSun, (v) => setState(() => _autoSun = v)),
            _slider('Sun angle', _sunYaw, 0, 2 * math.pi, (v) {
              setState(() {
                _sunYaw = v;
                _autoSun = false;
              });
            }, format: (v) => '${(v * 180 / math.pi).round()}°'),
            _slider('Point', _pointIntensity, 0, 40, (v) {
              setState(() => _pointIntensity = v);
              _applyLightToggles();
            }, format: (v) => v.toStringAsFixed(0)),
          ],
        );
      case _Demo.environment:
        final env = _env;
        if (env == null) return const SizedBox.shrink();
        return Wrap(
          spacing: 8,
          runSpacing: 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < _skyPresets.length; i++)
              _choice(_skyPresets[i].name, _preset == i, () => _applyPreset(i)),
            _toggle('Sky', env.sky, (v) => setState(() => env.sky = v)),
            _toggle('Fog', env.fog, (v) => setState(() => env.fog = v)),
            _toggle(
              'Reflections',
              env.reflections,
              (v) => setState(() => env.reflections = v),
            ),
            _slider(
              'Fog density',
              env.fogDensity,
              0,
              0.1,
              (v) => setState(() => env.fogDensity = v),
              format: (v) => v.toStringAsFixed(3),
            ),
            _slider(
              'Exposure',
              env.exposure,
              0.3,
              2.0,
              (v) => setState(() => env.exposure = v),
            ),
            _slider(
              'Reflect',
              env.reflectionStrength,
              0,
              1,
              (v) => setState(() => env.reflectionStrength = v),
            ),
          ],
        );
      case _Demo.model:
        return Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _choice('Animator graph', _graphMode, () {
              setState(() => _graphMode = true);
              _applyGraphMode();
            }),
            _choice('Clip player', !_graphMode, () {
              setState(() => _graphMode = false);
              _applyGraphMode();
            }),
            if (_graphMode) ...[
              _slider(
                'planarSpeed',
                _heroSpeed,
                0,
                4.5,
                (v) => setState(() => _heroSpeed = v),
                format: (v) => '${v.toStringAsFixed(1)} m/s',
              ),
              _toggle(
                'Walk a circle',
                _walkCircle,
                (v) => setState(() => _walkCircle = v),
              ),
              _toggle('Crouch', _crouch, (v) => setState(() => _crouch = v)),
              _actionButton('Jump', _demo.accentColor, _jump),
              _actionButton(
                'Punch',
                _demo.accentColor,
                () => _strike(kick: false),
              ),
              _actionButton(
                'Kick',
                _demo.accentColor,
                () => _strike(kick: true),
              ),
            ] else ...[
              for (final clip in _heroClips)
                _choice(clip, _clip == clip, () => _playClip(clip)),
              _slider('Speed', _clipSpeed, 0.1, 2, (v) {
                setState(() => _clipSpeed = v);
                _player?.speed = v;
              }),
            ],
            _toggle('Gold outfit', _goldOutfit, (v) {
              setState(() => _goldOutfit = v);
              _applyOutfit();
            }),
            _toggle('Hand light', _handLight, (v) {
              setState(() => _handLight = v);
              _handOrb?.isActive = v;
            }),
          ],
        );
      case _Demo.cameras:
        return Wrap(
          spacing: 8,
          runSpacing: 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _label('Live camera:'),
            for (final rig in const [
              'Orbit Cam',
              'Security Cam',
              'Crane Cam',
              'Eyes Cam',
            ])
              _choice(rig, _liveRig == rig, () => _goLive(rig)),
            _slider('Blend', _blendSeconds, 0, 3, (v) {
              setState(() => _blendSeconds = v);
              _engine?.cameraSystem.brain.defaultBlend = CameraBlend(
                duration: v,
              );
            }, format: (v) => v < 0.05 ? 'cut' : '${v.toStringAsFixed(1)} s'),
          ],
        );
    }
  }

  // ── Small widgets ──────────────────────────────────────────────────────

  Widget _label(String text) =>
      Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12));

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

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String Function(double v)? format,
  }) {
    return SizedBox(
      width: 270,
      height: 30,
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                activeColor: _demo.accentColor,
                inactiveColor: Colors.white12,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              format?.call(value) ?? value.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
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
                  'just_game_engine  graphics_3d.dart',
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
