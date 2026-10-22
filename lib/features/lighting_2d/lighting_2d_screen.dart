import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/widgets.dart' show GameCameraControls;

import '../../core/engine/demo_engine.dart';

// -----------------------------------------------------------------------------
// Assets
// -----------------------------------------------------------------------------

const String _housePath = 'assets/sprites/environment/house/house_01.png';
const String _treesPath =
    'assets/sprites/environment/parallax/parallax-forest-middle-trees.png';
const String _raysPath =
    'assets/sprites/environment/parallax/parallax-forest-lights.png';

/// Emissive + an orange glow: a torch flame, a lamp bulb.
const String _flameMaterial =
    'assets/materials/light_torch_flame.material2d.json';

/// Emissive + a cyan glow: crystals.
const String _crystalMaterial =
    'assets/materials/light_crystal.material2d.json';

/// Emissive only: drawn at full brightness whatever the lights.
const String _emissiveMaterial =
    'assets/materials/light_emissive.material2d.json';

/// A strip of equal frames in one image, played in a loop.
class _Strip {
  const _Strip(
    this.path,
    this.frameWidth,
    this.frameHeight,
    this.frames,
    this.fps,
  );

  final String path;
  final double frameWidth;
  final double frameHeight;
  final int frames;
  final double fps;

  Rect frame(int i) =>
      Rect.fromLTWH((i % frames) * frameWidth, 0, frameWidth, frameHeight);
}

const _Strip _heroBlue = _Strip(
  'assets/sprites/characters/character02/character_02_idle.png',
  46,
  55,
  10,
  10,
);
const _Strip _heroRed = _Strip(
  'assets/sprites/characters/character03/character_03_idle_down.png',
  96,
  80,
  8,
  8,
);

const List<String> _imagePaths = [
  _housePath,
  _treesPath,
  _raysPath,
  'assets/sprites/characters/character02/character_02_idle.png',
  'assets/sprites/characters/character03/character_03_idle_down.png',
];

// -----------------------------------------------------------------------------
// Demo mode
// -----------------------------------------------------------------------------

enum _Demo {
  ambient,
  point,
  spot,
  shadows,
  emissive;

  String get label => switch (this) {
    ambient => 'Ambient & Day/Night',
    point => 'Point Lights',
    spot => 'Spot Lights',
    shadows => 'Shadows',
    emissive => 'Emissive & Torches',
  };

  IconData get icon => switch (this) {
    ambient => Icons.wb_twilight,
    point => Icons.lightbulb_outline,
    spot => Icons.highlight,
    shadows => Icons.contrast,
    emissive => Icons.local_fire_department,
  };

  Color get accentColor => switch (this) {
    ambient => const Color(0xFF7986CB),
    point => const Color(0xFFFFCA28),
    spot => const Color(0xFF4DD0E1),
    shadows => const Color(0xFFB0BEC5),
    emissive => const Color(0xFFFF7043),
  };

  String get description => switch (this) {
    ambient =>
      'Lighting2D (one per scene) turns 2-D lighting on: the frame is drawn, '
          'then lit by every Light2D over its ambient colour x intensity. '
          'Here the ambient follows a day/night cycle and the house lights '
          'come on as it gets dark.',
    point =>
      'Light2D point lights: colour x intensity, radius (world units), height '
          '(the lower, the more it grazes) and falloff (1 = even, higher = '
          'tighter). Up to 16 lights near the view are drawn. One follows the '
          'pointer; three coloured ones orbit and mix.',
    spot =>
      'Light2DKind.spot shines a cone along its entity\'s angle (0 = +X, '
          'pi/2 = down): coneAngle in degrees, coneSoftness for the edge. Two '
          'searchlights sweep; the middle one aims at the pointer.',
    shadows =>
      'A Light2D that castsShadows is stopped by sprites and shapes with a '
          'ShadowCaster2D. Their faces stay lit `depth` units in; '
          'Lighting2D.shadowSoftness blurs the edges. Move the light with the '
          'pointer.',
    emissive =>
      'A 2-D material with `emissive` is drawn at full brightness whatever '
          'the lights: flames, crystals, light shafts. Torch lights flicker '
          '(intensity + radius each tick) and cast shadows of the characters.',
  };

  String get codeSnippet => switch (this) {
    ambient => '''
// One per scene: turns 2-D lighting on.
world.createEntityWithComponents([
  Lighting2D(
    ambient: const Color(0xFF26335E), // moonlight
    ambientIntensity: 1.0,
    shadowSoftness: 0.3,
  ),
], name: 'Lighting');

// Day/night: change it as the game runs.
final lighting = world
    .query(const [Lighting2D]).first
    .getComponent<Lighting2D>()!;
lighting.ambient = Color.lerp(night, day, daylight)!;
windowLight.intensity = 1.6 * (1 - daylight);''',
    point => '''
world.createEntityWithComponents([
  TransformComponent(position: Vector3(x, y, 0)),
  Light2D(
    colour: const Color(0xFFFF5252),
    intensity: 1.4,
    radius: 260,  // world units
    height: 48,   // lower = more grazing
    falloff: 1.5, // 1 = even, higher = tighter
    castsShadows: false,
  ),
]);
// Move it like any entity:
entity.getComponent<TransformComponent>()!
    .position.setValues(px, py, 0);''',
    spot => '''
world.createEntityWithComponents([
  // A spot shines along its entity's angle.
  TransformComponent(
    position: Vector3(0, -250, 0),
    angle: math.pi / 2, // down
  ),
  Light2D(
    kind: Light2DKind.spot,
    coneAngle: 40,      // degrees
    coneSoftness: 0.25, // 0 = hard edge
    radius: 620,
    intensity: 2,
  ),
]);
// Aim it at a point:
transform.angle = math.atan2(ty - y, tx - x);''',
    shadows => '''
// A light that castsShadows (the default)...
Light2D(radius: 520, intensity: 1.8, castsShadows: true);

// ...is stopped by sprites and shapes with a ShadowCaster2D.
world.createEntityWithComponents([
  TransformComponent(position: Vector3(-120, 40, 0)),
  RectangleComponent(width: 48, height: 48),
  ShadowCaster2D(depth: 12), // its face stays lit 12 units in
]);

// Soft or hard edges, for the whole scene:
Lighting2D(shadowSoftness: 0.3);''',
    emissive => '''
// assets/materials/light_torch_flame.material2d.json
// { "formatVersion": 1,
//   "emissive": {"amount": 1.0},
//   "glow": {"colour": 4294941244, "radius": 14.0, "strength": 1.8} }

world.createEntityWithComponents([
  TransformComponent(position: Vector3(x, y, 0)),
  CircleComponent(radius: 9),
  Material2D(
    material: 'assets/materials/light_torch_flame.material2d.json',
  ),
]);
// Flicker, every tick:
light.intensity = 1.8 * (1 + 0.35 * noise);
flame.set('glow.strength', 1.8 * (1 + 0.25 * noise));

// An editor's view of the normals the frame is lit by:
engine.rendering.screenPasses
    .whereType<Lighting2DPass>().first.showNormals = true;''',
  };
}

// -----------------------------------------------------------------------------
// ECS helpers
// -----------------------------------------------------------------------------

/// Runs [onTick] every fixed update of the world the engine drives.
class _TickSystem extends System {
  _TickSystem(this.onTick);

  final void Function(double dt) onTick;

  @override
  List<Type> get requiredComponents => const [];

  @override
  void update(double deltaTime) => onTick(deltaTime);
}

/// A sprite stepping through a strip's frames.
class _Animated {
  _Animated(this.sprite, this.strip, this.phase);

  final Sprite sprite;
  final _Strip strip;
  final double phase;
  int _shown = -1;

  void step(double time) {
    final i = ((time + phase) * strip.fps).floor() % strip.frames;
    if (i == _shown) return;
    _shown = i;
    sprite.sourceRect = strip.frame(i);
  }
}

/// A light that orbits a centre.
class _Orbit {
  _Orbit(this.entity, this.centre, this.radius, this.speed, this.phase);

  final Entity entity;
  final Offset centre;
  final double radius;
  final double speed;
  final double phase;
}

/// A flickering torch: its light and the flame drawn through a material.
class _Torch {
  _Torch(this.light, this.flame, this.seed, this.intensity, this.radius);

  final Light2D light;
  final Material2D flame;
  final double seed;
  final double intensity;
  final double radius;
}

/// A searchlight sweeping around [baseAngle].
class _Sweep {
  _Sweep(this.entity, this.baseAngle, this.swing, this.speed);

  final Entity entity;
  final double baseAngle;
  final double swing;
  final double speed;
}

// -----------------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------------

/// 2-D lighting and shadows (just_game_engine 2.0.0-dev.2): [Lighting2D],
/// [Light2D] (point and spot), [ShadowCaster2D], emissive 2-D materials and
/// [Lighting2DPass.showNormals].
class Lighting2DScreen extends StatefulWidget {
  const Lighting2DScreen({super.key});

  @override
  State<Lighting2DScreen> createState() => _Lighting2DScreenState();
}

class _Lighting2DScreenState extends State<Lighting2DScreen> {
  late final Engine _engine = demoEngine;
  late final World _world = _engine.world;

  _Demo _demo = _Demo.ambient;
  Timer? _hudTimer;
  bool _disposed = false;
  final Map<String, ui.Image> _images = {};
  final List<String> _loadErrors = [];
  bool _imagesReady = false;
  Size _viewSize = Size.zero;

  // What the running demo made.
  double _time = 0;
  final List<_Animated> _animated = [];
  final List<_Orbit> _orbits = [];
  final List<_Torch> _torches = [];
  final List<_Sweep> _sweeps = [];
  final List<ShadowCaster2D> _casters = [];
  final List<Light2D> _nightLights = [];
  Lighting2D? _lighting;
  Entity? _cursorLight;
  Entity? _aimedSpot;
  Entity? _sun;
  Entity? _moon;

  // Pointer, in world units; null until the pointer is over the canvas.
  Offset? _pointer;
  double _pointerSeenAt = -100;

  // Ambient & day/night.
  bool _cycle = true;
  double _timeOfDay = 0.30; // 0 midnight, 0.25 sunrise, 0.5 noon, 0.75 dusk
  double _cycleSeconds = 24;
  double _ambientIntensity = 1.0;
  Color? _ambientPreset;

  // Point lights.
  double _pointIntensity = 1.6;
  double _pointRadius = 300;
  double _pointHeight = 60;
  double _pointFalloff = 1.5;
  Color _pointColour = const Color(0xFFFFFFFF);
  bool _orbiting = true;

  // Spot lights.
  double _coneAngle = 40;
  double _coneSoftness = 0.25;
  double _spotRadius = 620;
  double _spotIntensity = 2.0;
  bool _sweeping = true;

  // Shadows.
  bool _castShadows = true;
  bool _secondLight = true;
  double _softness = 0.3;
  double _casterDepth = 12;

  // Emissive & torches.
  bool _flicker = true;
  double _flickerAmount = 0.6;
  double _glowStrength = 1.8;
  double _caveAmbient = 1.0;

  bool _showNormals = false;

  static const Map<String, Color> _ambientPresets = {
    'Day': Color(0xFFFFFFFF),
    'Dusk': Color(0xFFE08A5A),
    'Moonlight': Color(0xFF26335E),
    'Cave': Color(0xFF0A0A10),
  };

  static const List<Color> _lightColours = [
    Color(0xFFFFFFFF),
    Color(0xFFFFC46B),
    Color(0xFF6FD8FF),
    Color(0xFFFF6EC7),
    Color(0xFF8BFF8B),
  ];

  @override
  void initState() {
    super.initState();
    DemoEngine.reset(_engine, include: {DefaultSystem.rendering});
    _hudTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
    unawaited(_loadImages());
  }

  Future<void> _loadImages() async {
    for (final path in _imagePaths) {
      try {
        final image = await Sprite.loadImageFromAsset(
          path,
          assets: _engine.assets,
        );
        if (_disposed) {
          image.dispose();
          return;
        }
        _images[path] = image;
      } on Object catch (e) {
        _loadErrors.add('$path: $e');
      }
    }
    if (_disposed) return;
    _imagesReady = true;
    _buildDemo(_demo);
  }

  @override
  void dispose() {
    _disposed = true;
    _hudTimer?.cancel();
    _lightingPass?.showNormals = false;
    DemoEngine.reset(_engine);
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    super.dispose();
  }

  /// The engine's lighting pass (first of its screen passes).
  Lighting2DPass? get _lightingPass {
    for (final pass in _engine.rendering.screenPasses) {
      if (pass is Lighting2DPass) return pass;
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Demo construction
  // -------------------------------------------------------------------------

  void _buildDemo(_Demo demo) {
    _demo = demo;
    DemoEngine.reset(_engine, include: {DefaultSystem.rendering});
    _time = 0;
    _animated.clear();
    _orbits.clear();
    _torches.clear();
    _sweeps.clear();
    _casters.clear();
    _nightLights.clear();
    _lighting = null;
    _cursorLight = null;
    _aimedSpot = null;
    _sun = null;
    _moon = null;
    _world.addSystem(_TickSystem(_tick));
    _lightingPass?.showNormals = _showNormals;

    if (_imagesReady) {
      switch (demo) {
        case _Demo.ambient:
          _buildAmbient();
        case _Demo.point:
          _buildPoint();
        case _Demo.spot:
          _buildSpot();
        case _Demo.shadows:
          _buildShadows();
        case _Demo.emissive:
          _buildEmissive();
      }
    }
    _fitCamera();
    if (mounted) setState(() {});
  }

  void _fitCamera() {
    final camera = _engine.cameraSystem.mainCamera;
    camera.position = Offset.zero;
    if (_viewSize.isEmpty) return;
    camera.zoom = math
        .min(_viewSize.width / 920, _viewSize.height / 560)
        .clamp(0.3, 1.6);
  }

  Entity _addLighting({
    required Color ambient,
    double intensity = 1,
    double softness = 0.3,
  }) {
    final lighting = Lighting2D(
      ambient: ambient,
      ambientIntensity: intensity,
      shadowSoftness: softness,
    );
    _lighting = lighting;
    return _world.createEntityWithComponents([lighting], name: 'Lighting');
  }

  /// A light at [at]; [look] draws something there (a bulb, a housing).
  Entity _addLight(
    Offset at,
    Light2D light, {
    double angle = 0,
    List<Component> look = const [],
    String? name,
  }) => _world.createEntityWithComponents([
    TransformComponent(position: Vector3(at.dx, at.dy, 0), angle: angle),
    light,
    ...look,
  ], name: name);

  Entity _addShape(
    Component shape,
    Offset at, {
    int layer = 0,
    double angle = 0,
    String? material,
    bool caster = false,
    String? name,
  }) {
    final c = caster ? ShadowCaster2D(depth: _casterDepth) : null;
    if (c != null) _casters.add(c);
    return _world.createEntityWithComponents([
      TransformComponent(position: Vector3(at.dx, at.dy, 0), angle: angle),
      shape,
      LayerComponent(layer: layer),
      ?c,
      if (material != null) Material2D(material: material),
    ], name: name);
  }

  Entity? _addSprite(
    String path,
    Offset at, {
    double scale = 1,
    Rect? frame,
    int layer = 0,
    String? material,
    bool caster = false,
    String? name,
  }) {
    final image = _images[path];
    if (image == null) return null;
    final sprite = Sprite(image: image, sourceRect: frame)
      ..filterQuality = FilterQuality.none;
    final c = caster ? ShadowCaster2D(depth: _casterDepth) : null;
    if (c != null) _casters.add(c);
    return _world.createEntityWithComponents([
      TransformComponent(
        position: Vector3(at.dx, at.dy, 0),
        scale: Vector3(scale, scale, 1),
      ),
      RenderableComponent(renderable: sprite),
      LayerComponent(layer: layer),
      ?c,
      if (material != null) Material2D(material: material),
    ], name: name);
  }

  /// An idle character centred on [centre], stepping through [strip].
  void _addHero(
    _Strip strip,
    Offset centre, {
    double scale = 2.5,
    double phase = 0,
    bool caster = false,
    int layer = 5,
  }) {
    final entity = _addSprite(
      strip.path,
      centre,
      scale: scale,
      frame: strip.frame(0),
      layer: layer,
      caster: caster,
      name: 'Hero',
    );
    final sprite = entity?.getComponent<RenderableComponent>()?.renderable;
    if (sprite is Sprite) _animated.add(_Animated(sprite, strip, phase));
  }

  /// A brick wall behind everything, lit by the lights.
  void _addWall({
    required Color stone,
    required Color mortar,
    double brickWidth = 64,
    double brickHeight = 32,
  }) {
    const area = Rect.fromLTWH(-900, -520, 1800, 1040);
    final mortarPath = Path();
    var row = 0;
    for (var y = area.top; y < area.bottom; y += brickHeight, row++) {
      mortarPath
        ..moveTo(area.left, y)
        ..lineTo(area.right, y);
      final shift = row.isEven ? 0.0 : brickWidth / 2;
      for (var x = area.left + shift; x < area.right; x += brickWidth) {
        mortarPath
          ..moveTo(x, y)
          ..lineTo(x, y + brickHeight);
      }
    }
    final fill = Paint()..color = stone;
    final line = Paint()
      ..color = mortar
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -20,
          getBoundsCallback: () => area,
          onRender: (canvas, _) {
            canvas
              ..drawRect(area, fill)
              ..drawPath(mortarPath, line);
          },
        ),
      ),
    ], name: 'Wall');
  }

  // -------------------------------------------------------------------------
  // Ambient & day/night
  // -------------------------------------------------------------------------

  void _buildAmbient() {
    // Sky and ground: plain colours that the ambient light tints.
    const sky = Rect.fromLTWH(-900, -520, 1800, 700);
    const ground = Rect.fromLTWH(-900, 150, 1800, 380);
    final skyPaint = Paint()
      ..shader = ui.Gradient.linear(
        sky.topCenter,
        const Offset(0, 160),
        const [Color(0xFF6FA8DC), Color(0xFFF2D7A6)],
      );
    final groundPaint = Paint()..color = const Color(0xFF3A2A20);
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -20,
          getBoundsCallback: () => sky.expandToInclude(ground),
          onRender: (canvas, _) {
            canvas
              ..drawRect(sky, skyPaint)
              ..drawRect(ground, groundPaint);
          },
        ),
      ),
    ], name: 'Sky');

    // Sun and moon glow (emissive): the ambient light does not dim them.
    _sun = _addShape(
      CircleComponent(
        radius: 30,
        fillStyle: const ShapePaintStyle(color: Color(0xFFFFE27A)),
      ),
      Offset.zero,
      layer: -16,
      material: _emissiveMaterial,
      name: 'Sun',
    );
    _moon = _addShape(
      CircleComponent(
        radius: 22,
        fillStyle: const ShapePaintStyle(color: Color(0xFFE8EEFF)),
      ),
      Offset.zero,
      layer: -16,
      material: _emissiveMaterial,
      name: 'Moon',
    );

    const tile = 272 * 3.3;
    for (final x in const [-tile, 0.0, tile]) {
      _addSprite(_treesPath, Offset(x, 68), scale: 3.3, layer: -12);
    }
    _addSprite(_housePath, const Offset(-40, 78), scale: 1.5, name: 'House');

    // A street lamp: a post, a glowing bulb and its light.
    _addShape(
      RectangleComponent(
        width: 8,
        height: 124,
        fillStyle: const ShapePaintStyle(color: Color(0xFF2B2B33)),
      ),
      const Offset(250, 90),
      layer: 1,
    );
    _addShape(
      CircleComponent(
        radius: 8,
        fillStyle: const ShapePaintStyle(color: Color(0xFFFFE9B0)),
      ),
      const Offset(250, 26),
      layer: 2,
      material: _flameMaterial,
      name: 'Bulb',
    );

    _addHero(_heroBlue, const Offset(-260, 92), scale: 2.2);
    _addHero(_heroRed, const Offset(190, 95), phase: 0.4);

    _addLighting(ambient: const Color(0xFFFFFFFF));
    for (final (at, colour, radius) in const [
      (Offset(-47, 40), Color(0xFFFFC46B), 230.0), // window
      (Offset(78, 70), Color(0xFFFFB050), 160.0), // door lamp
      (Offset(250, 30), Color(0xFFFFE2A0), 300.0), // street lamp
    ]) {
      final light = Light2D(
        colour: colour,
        radius: radius,
        height: 36,
        castsShadows: false,
      );
      _nightLights.add(light);
      _addLight(at, light, name: 'Night light');
    }
    _applyDayNight();
  }

  double _smooth(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// The sun's height for [_timeOfDay]: -1 midnight, 0 at the horizon, 1 noon.
  double get _sunHeight => -math.cos(_timeOfDay * 2 * math.pi);

  void _applyDayNight() {
    final lighting = _lighting;
    if (lighting == null) return;
    const night = Color(0xFF26335E);
    const dusk = Color(0xFFE08A5A);
    const day = Color(0xFFFFFFFF);
    final e = _sunHeight;
    final ambient =
        _ambientPreset ??
        (e < 0
            ? Color.lerp(dusk, night, _smooth(0, 0.35, -e))!
            : Color.lerp(dusk, day, _smooth(0, 0.4, e))!);
    lighting
      ..ambient = ambient
      ..ambientIntensity = _ambientIntensity;
    // The house lights come on as it gets dark.
    final brightness =
        (0.2126 * ambient.r + 0.7152 * ambient.g + 0.0722 * ambient.b) *
        _ambientIntensity;
    final darkness = (1 - brightness * 1.25).clamp(0.0, 1.0);
    for (final light in _nightLights) {
      light
        ..intensity = 1.8 * darkness
        ..enabled = darkness > 0.02;
    }
    if (_ambientPreset != null) {
      // A fixed ambient: the sun by day, the moon by night, high up.
      const high = Offset(-300, -235);
      _moveTo(_sun, high);
      _moveTo(_moon, high);
      _setVisible(_sun, darkness < 0.5);
      _setVisible(_moon, darkness >= 0.5);
      return;
    }
    // Sun and moon along their arcs: sunrise left, sunset right.
    final phi = (_timeOfDay - 0.25) * 2 * math.pi;
    _moveTo(_sun, Offset(-420 * math.cos(phi), 150 - 330 * math.sin(phi)));
    _moveTo(_moon, Offset(420 * math.cos(phi), 150 + 330 * math.sin(phi)));
    _setVisible(_sun, true);
    _setVisible(_moon, true);
  }

  void _setVisible(Entity? entity, bool visible) {
    final renderable = entity?.getComponent<RenderableComponent>()?.renderable;
    if (renderable != null) renderable.visible = visible;
  }

  void _moveTo(Entity? entity, Offset at) {
    entity?.getComponent<TransformComponent>()?.position.setValues(
      at.dx,
      at.dy,
      0,
    );
  }

  String get _clock {
    final minutes = (_timeOfDay * 24 * 60).round() % (24 * 60);
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  // -------------------------------------------------------------------------
  // Point lights
  // -------------------------------------------------------------------------

  void _buildPoint() {
    _addWall(stone: const Color(0xFFB9B2A6), mortar: const Color(0xFF7E776C));
    _addSprite(_housePath, const Offset(0, 60), scale: 1.2, name: 'House');
    _addHero(_heroBlue, const Offset(-300, 120), scale: 2.4);
    _addHero(_heroRed, const Offset(300, 110), phase: 0.3);
    for (var i = 0; i < 4; i++) {
      _addShape(
        CircleComponent(
          radius: 22,
          fillStyle: const ShapePaintStyle(color: Color(0xFF8D6E63)),
          strokeStyle: const ShapePaintStyle(color: Color(0xFF4E342E)),
          strokeWidth: 3,
        ),
        Offset(-330 + i * 220.0, -170),
        name: 'Barrel',
      );
    }
    _addLighting(ambient: const Color(0xFF15151E));

    const colours = [Color(0xFFFF4D4D), Color(0xFF4DFF6A), Color(0xFF4D7BFF)];
    for (var i = 0; i < colours.length; i++) {
      final entity = _addLight(
        Offset.zero,
        Light2D(
          colour: colours[i],
          intensity: 1.4,
          radius: 260,
          castsShadows: false,
        ),
        look: _bulb(colours[i], 7),
        name: 'Orbiting light',
      );
      _orbits.add(_Orbit(entity, Offset.zero, 180, 0.6, i * 2 * math.pi / 3));
    }
    _cursorLight = _addLight(
      const Offset(0, -40),
      Light2D(castsShadows: false),
      look: _bulb(_pointColour, 9),
      name: 'Pointer light',
    );
    _applyPointSettings();
  }

  /// A small glowing marker where a light is.
  List<Component> _bulb(Color colour, double radius) => [
    CircleComponent(
      radius: radius,
      fillStyle: ShapePaintStyle(color: colour),
      strokeStyle: const ShapePaintStyle(color: Color(0xFFFFFFFF)),
      strokeWidth: 2,
    ),
    LayerComponent(layer: 20),
    Material2D(material: _emissiveMaterial),
  ];

  void _applyPointSettings() {
    final entity = _cursorLight;
    final light = entity?.getComponent<Light2D>();
    if (light == null) return;
    light
      ..colour = _pointColour
      ..intensity = _pointIntensity
      ..radius = _pointRadius
      ..height = _pointHeight
      ..falloff = _pointFalloff;
    // Shapes are filed under RenderableComponent.
    final bulb = entity!.getComponent<RenderableComponent>();
    if (bulb is CircleComponent && bulb.fillStyle.color != _pointColour) {
      bulb.fillStyle = ShapePaintStyle(color: _pointColour);
    }
  }

  // -------------------------------------------------------------------------
  // Spot lights
  // -------------------------------------------------------------------------

  void _buildSpot() {
    _addWall(stone: const Color(0xFFA9A39A), mortar: const Color(0xFF6E685F));
    // The stage floor.
    _addShape(
      RectangleComponent(
        width: 1800,
        height: 300,
        fillStyle: const ShapePaintStyle(color: Color(0xFF6D4C41)),
        strokeWidth: 0,
      ),
      const Offset(0, 320),
      layer: -15,
    );
    for (var i = 0; i < 5; i++) {
      final strip = i.isEven ? _heroBlue : _heroRed;
      final x = -320 + i * 160.0;
      _addHero(
        strip,
        Offset(x, strip == _heroBlue ? 112 : 115),
        scale: strip == _heroBlue ? 2.2 : 2.5,
        phase: i * 0.37,
      );
    }
    _addLighting(ambient: const Color(0xFF101018));

    Entity spot(Offset at, double angle, Color colour) => _addLight(
      at,
      Light2D(kind: Light2DKind.spot, colour: colour, castsShadows: false),
      angle: angle,
      look: [
        RectangleComponent(
          width: 34,
          height: 16,
          cornerRadius: 4,
          fillStyle: ShapePaintStyle(color: colour),
          strokeStyle: const ShapePaintStyle(color: Color(0xFF222222)),
          strokeWidth: 3,
        ),
        LayerComponent(layer: 20),
        Material2D(material: _emissiveMaterial),
      ],
      name: 'Spot light',
    );

    _sweeps
      ..add(
        _Sweep(
          spot(const Offset(-400, -240), math.pi / 4, const Color(0xFFFFD27A)),
          math.pi / 4,
          0.45,
          0.7,
        ),
      )
      ..add(
        _Sweep(
          spot(
            const Offset(400, -240),
            3 * math.pi / 4,
            const Color(0xFF6FD8FF),
          ),
          3 * math.pi / 4,
          0.45,
          0.9,
        ),
      );
    _aimedSpot = spot(
      const Offset(0, -260),
      math.pi / 2,
      const Color(0xFFFFFFFF),
    );
    _applySpotSettings();
  }

  void _applySpotSettings() {
    for (final entity in [..._sweeps.map((s) => s.entity), ?_aimedSpot]) {
      final light = entity.getComponent<Light2D>();
      if (light == null) continue;
      light
        ..coneAngle = _coneAngle
        ..coneSoftness = _coneSoftness
        ..radius = _spotRadius
        ..intensity = _spotIntensity;
    }
  }

  // -------------------------------------------------------------------------
  // Shadows
  // -------------------------------------------------------------------------

  void _buildShadows() {
    _addWall(
      stone: const Color(0xFFC8C0B0),
      mortar: const Color(0xFF9A9284),
      brickWidth: 64,
      brickHeight: 64,
    );
    const pillar = ShapePaintStyle(color: Color(0xFF5D5A66));
    const column = ShapePaintStyle(color: Color(0xFF78909C));
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + math.pi / 8;
      final at = Offset(math.cos(a) * 190, math.sin(a) * 140);
      _addShape(
        i.isEven
            ? RectangleComponent(width: 40, height: 40, fillStyle: pillar)
            : CircleComponent(radius: 20, fillStyle: column),
        at,
        angle: a,
        caster: true,
        name: i.isEven ? 'Pillar' : 'Column',
      );
    }
    // A hexagon and an L-shaped wall.
    _addShape(
      PolygonComponent(
        vertices: [
          for (var i = 0; i < 6; i++)
            Offset(
              math.cos(i * math.pi / 3) * 34,
              math.sin(i * math.pi / 3) * 34,
            ),
        ],
        fillStyle: const ShapePaintStyle(color: Color(0xFF8E7CC3)),
      ),
      const Offset(-360, -150),
      caster: true,
      name: 'Hexagon',
    );
    _addShape(
      PolygonComponent(
        vertices: const [
          Offset(-60, -60),
          Offset(60, -60),
          Offset(60, -36),
          Offset(-36, -36),
          Offset(-36, 60),
          Offset(-60, 60),
        ],
        fillStyle: const ShapePaintStyle(color: Color(0xFF6D6875)),
      ),
      const Offset(360, 170),
      caster: true,
      name: 'Wall',
    );
    _addSprite(
      _housePath,
      const Offset(330, -170),
      scale: 0.7,
      caster: true,
      name: 'House',
    );
    _addHero(
      _heroBlue,
      const Offset(-330, 160),
      scale: 2,
      caster: true,
      layer: 0,
    );
    _addHero(
      _heroRed,
      const Offset(-200, 190),
      scale: 2.2,
      phase: 0.5,
      caster: true,
      layer: 0,
    );

    _addLighting(ambient: const Color(0xFF1C1C26), softness: _softness);
    _cursorLight = _addLight(
      const Offset(0, 0),
      Light2D(
        colour: const Color(0xFFFFE2B0),
        intensity: 1.8,
        radius: 520,
        height: 40,
        falloff: 1.2,
      ),
      look: _bulb(const Color(0xFFFFE2B0), 8),
      name: 'Pointer light',
    );
    final second = _addLight(
      Offset.zero,
      Light2D(
        colour: const Color(0xFF6FD8FF),
        intensity: 1.2,
        radius: 420,
        height: 40,
      ),
      look: _bulb(const Color(0xFF6FD8FF), 6),
      name: 'Orbiting light',
    );
    _orbits.add(_Orbit(second, Offset.zero, 300, 0.45, 0));
    _applyShadowSettings();
  }

  void _applyShadowSettings() {
    _lighting?.shadowSoftness = _softness;
    for (final c in _casters) {
      c.depth = _casterDepth;
    }
    _cursorLight?.getComponent<Light2D>()?.castsShadows = _castShadows;
    for (final o in _orbits) {
      final light = o.entity.getComponent<Light2D>();
      light
        ?..castsShadows = _castShadows
        ..enabled = _secondLight;
      o.entity.getComponent<RenderableComponent>()?.renderable.visible =
          _secondLight;
    }
  }

  // -------------------------------------------------------------------------
  // Emissive & torches
  // -------------------------------------------------------------------------

  void _buildEmissive() {
    _addWall(stone: const Color(0xFF8A8078), mortar: const Color(0xFF4A433E));
    // Light shafts: a semi-transparent sprite, emissive, so it glows.
    _addSprite(
      _raysPath,
      const Offset(0, -150),
      scale: 2.6,
      layer: -10,
      material: _emissiveMaterial,
      name: 'Light shafts',
    );
    // The floor.
    _addShape(
      RectangleComponent(
        width: 1800,
        height: 300,
        fillStyle: const ShapePaintStyle(color: Color(0xFF4A403A)),
        strokeWidth: 0,
      ),
      const Offset(0, 330),
      layer: -15,
    );

    final rng = math.Random(7);
    for (var i = 0; i < 4; i++) {
      final x = -330 + i * 220.0;
      const y = -40.0;
      _addShape(
        RectangleComponent(
          width: 8,
          height: 52,
          fillStyle: const ShapePaintStyle(color: Color(0xFF5D4037)),
        ),
        Offset(x, y + 32),
        layer: 1,
      );
      final flame = _addShape(
        CircleComponent(
          radius: 9,
          fillStyle: const ShapePaintStyle(color: Color(0xFFFFB74D)),
          strokeStyle: const ShapePaintStyle(color: Color(0xFFFFF3C4)),
          strokeWidth: 2,
        ),
        Offset(x, y),
        layer: 2,
        material: _flameMaterial,
        name: 'Flame',
      ).getComponent<Material2D>()!;
      final light = Light2D(
        colour: const Color(0xFFFFA347),
        intensity: 1.8,
        radius: 300,
        height: 50,
      );
      _addLight(Offset(x, y), light, name: 'Torch light');
      _torches.add(_Torch(light, flame, rng.nextDouble() * 100, 1.8, 300));
    }

    // Crystals on the floor, glowing cyan.
    for (final x in const [-220.0, 0.0, 220.0]) {
      _addShape(
        PolygonComponent(
          vertices: const [
            Offset(0, -30),
            Offset(14, -6),
            Offset(8, 22),
            Offset(-8, 22),
            Offset(-14, -6),
          ],
          fillStyle: const ShapePaintStyle(color: Color(0xFF7FE9FF)),
        ),
        Offset(x, 168),
        layer: 3,
        material: _crystalMaterial,
        name: 'Crystal',
      );
      _addLight(
        Offset(x, 160),
        Light2D(
          colour: const Color(0xFF4FE3FF),
          intensity: 0.9,
          radius: 170,
          height: 30,
          castsShadows: false,
        ),
        name: 'Crystal light',
      );
    }

    _addHero(
      _heroBlue,
      const Offset(-110, 128),
      scale: 2.2,
      caster: true,
      layer: 4,
    );
    _addHero(
      _heroRed,
      const Offset(110, 131),
      phase: 0.3,
      caster: true,
      layer: 4,
    );
    _addLighting(
      ambient: const Color(0xFF0E0E16),
      intensity: _caveAmbient,
      softness: 0.45,
    );
  }

  double _noise(double t, double seed) =>
      math.sin(t * 13.1 + seed) * 0.5 +
      math.sin(t * 7.3 + seed * 1.7) * 0.3 +
      math.sin(t * 23.7 + seed * 2.3) * 0.2;

  // -------------------------------------------------------------------------
  // Per tick
  // -------------------------------------------------------------------------

  void _tick(double dt) {
    _time += dt;
    for (final a in _animated) {
      a.step(_time);
    }
    for (final o in _orbits) {
      if (_demo == _Demo.point && !_orbiting) continue;
      final a = o.phase + _time * o.speed;
      _moveTo(
        o.entity,
        o.centre + Offset(math.cos(a) * o.radius, math.sin(a) * o.radius),
      );
    }
    switch (_demo) {
      case _Demo.ambient:
        if (_cycle && _ambientPreset == null) {
          _timeOfDay = (_timeOfDay + dt / _cycleSeconds) % 1.0;
        }
        _applyDayNight();
      case _Demo.point:
      case _Demo.shadows:
        _followPointer(_cursorLight, dt);
      case _Demo.spot:
        for (final s in _sweeps) {
          if (!_sweeping) continue;
          s.entity.getComponent<TransformComponent>()?.angle =
              s.baseAngle + math.sin(_time * s.speed) * s.swing;
        }
        _aimAtPointer(dt);
      case _Demo.emissive:
        _lighting?.ambientIntensity = _caveAmbient;
        for (final t in _torches) {
          final n = _flicker ? _noise(_time, t.seed) * _flickerAmount : 0.0;
          t.light
            ..intensity = t.intensity * (1 + 0.35 * n)
            ..radius = t.radius * (1 + 0.08 * n);
          t.flame.set('glow.strength', _glowStrength * (1 + 0.25 * n));
        }
    }
  }

  /// Where the pointer is, or a slow wander when it has not been seen lately.
  Offset get _target {
    final pointer = _pointer;
    if (pointer != null && _time - _pointerSeenAt < 4) return pointer;
    return Offset(
      math.sin(_time * 0.5) * 260,
      math.sin(_time * 0.8) * 140 - 20,
    );
  }

  void _followPointer(Entity? entity, double dt) {
    final t = entity?.getComponent<TransformComponent>();
    if (t == null) return;
    final target = _target;
    final k = (dt * 12).clamp(0.0, 1.0);
    t.position.setValues(
      t.position.x + (target.dx - t.position.x) * k,
      t.position.y + (target.dy - t.position.y) * k,
      0,
    );
  }

  void _aimAtPointer(double dt) {
    final t = _aimedSpot?.getComponent<TransformComponent>();
    if (t == null) return;
    final target = _target;
    final want = math.atan2(target.dy - t.position.y, target.dx - t.position.x);
    // Turn the short way round.
    var delta = want - t.angle;
    while (delta > math.pi) {
      delta -= 2 * math.pi;
    }
    while (delta < -math.pi) {
      delta += 2 * math.pi;
    }
    t.angle += delta * (dt * 10).clamp(0.0, 1.0);
  }

  void _onPointer(Offset local) {
    _pointer = _engine.cameraSystem.mainCamera.screenToWorld(local);
    _pointerSeenAt = _time;
  }

  // -------------------------------------------------------------------------
  // Stats
  // -------------------------------------------------------------------------

  String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  String get _statsLine {
    final pass = _lightingPass;
    final lighting = _lighting;
    final lights = _world
        .query(const [Light2D])
        .where((e) => e.getComponent<Light2D>()!.enabled)
        .length;
    return 'lights drawn ${pass?.lastLights.length ?? 0}/${Lighting2DPass.maxLights}'
        ' (on $lights)'
        '  shadows ${pass?.lastHadShadows ?? false ? 'yes' : 'no'}'
        '  ambient ${lighting == null ? '-' : '${_hex(lighting.ambient)} x ${lighting.ambientIntensity.toStringAsFixed(2)}'}'
        '  entities ${_world.entities.length}';
  }

  String get _statusMessage {
    if (_loadErrors.isNotEmpty) return 'Could not load: ${_loadErrors.first}';
    if (!_imagesReady) return 'Loading sprites...';
    final library = Material2DLibrary.of(_engine.context);
    if (library.lightingProgram == null) {
      return 'Loading the lighting shaders (shaders/lighting_2d.frag)...';
    }
    if (_showNormals) {
      return 'Showing normals: no normal-map images ship with this app, so the '
          'frame reads flat (0.5, 0.5, 1).';
    }
    return switch (_demo) {
      _Demo.ambient =>
        'Time $_clock  ${_ambientPreset == null ? (_cycle ? 'cycling' : 'paused') : 'fixed ambient'}',
      _Demo.point || _Demo.shadows =>
        'Move or drag the pointer over the scene to move the light',
      _Demo.spot => 'The white spot aims at the pointer',
      _Demo.emissive =>
        'Flames, crystals and light shafts are emissive; torches flicker',
    };
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
              Flexible(
                child: Text(
                  _demo.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _demo.accentColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              _toggle(
                'Show normals',
                _showNormals,
                const Color(0xFF9FA8DA),
                (v) => setState(() {
                  _showNormals = v;
                  _lightingPass?.showNormals = v;
                }),
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
          const SizedBox(height: 3),
          Text(
            _statusMessage,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if ((size.width - _viewSize.width).abs() > 1 ||
            (size.height - _viewSize.height).abs() > 1) {
          _viewSize = size;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fitCamera();
          });
        }
        return GameCameraControls(
          camera: _engine.cameraSystem.mainCamera,
          // Dragging moves the light; scroll or pinch to zoom.
          enablePan: false,
          enablePinch: true,
          showZoomLevel: true,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _onPointer(e.localPosition),
            onPointerMove: (e) => _onPointer(e.localPosition),
            onPointerHover: (e) => _onPointer(e.localPosition),
            child: GameWidget(engine: _engine, showFPS: true),
          ),
        );
      },
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: switch (_demo) {
          _Demo.ambient => _ambientControls(),
          _Demo.point => _pointControls(),
          _Demo.spot => _spotControls(),
          _Demo.shadows => _shadowControls(),
          _Demo.emissive => _emissiveControls(),
        },
      ),
    );
  }

  List<Widget> _ambientControls() {
    final accent = _demo.accentColor;
    return [
      _toggle(
        'Day/night cycle',
        _cycle && _ambientPreset == null,
        accent,
        (v) => setState(() {
          _cycle = v;
          if (v) _ambientPreset = null;
        }),
      ),
      _slider(
        'Time',
        _timeOfDay,
        0,
        1,
        (v) => setState(() {
          _timeOfDay = v;
          _applyDayNight();
        }),
        format: (_) => _clock,
      ),
      _slider(
        'Cycle (s)',
        _cycleSeconds,
        4,
        60,
        (v) => setState(() => _cycleSeconds = v),
        format: (v) => v.toStringAsFixed(0),
      ),
      _slider(
        'Intensity',
        _ambientIntensity,
        0,
        2,
        (v) => setState(() {
          _ambientIntensity = v;
          _applyDayNight();
        }),
      ),
      for (final MapEntry(key: name, value: colour) in _ambientPresets.entries)
        _swatch(
          name,
          colour,
          _ambientPreset == colour,
          () => setState(() {
            _ambientPreset = _ambientPreset == colour ? null : colour;
            _applyDayNight();
          }),
        ),
    ];
  }

  List<Widget> _pointControls() {
    void apply(VoidCallback change) => setState(() {
      change();
      _applyPointSettings();
    });
    return [
      _slider(
        'Intensity',
        _pointIntensity,
        0,
        4,
        (v) => apply(() => _pointIntensity = v),
      ),
      _slider(
        'Radius',
        _pointRadius,
        40,
        700,
        (v) => apply(() => _pointRadius = v),
        format: (v) => v.toStringAsFixed(0),
      ),
      _slider(
        'Height',
        _pointHeight,
        4,
        240,
        (v) => apply(() => _pointHeight = v),
        format: (v) => v.toStringAsFixed(0),
      ),
      _slider(
        'Falloff',
        _pointFalloff,
        0.3,
        4,
        (v) => apply(() => _pointFalloff = v),
      ),
      for (final c in _lightColours)
        _swatch(null, c, _pointColour == c, () => apply(() => _pointColour = c)),
      _toggle(
        'Orbiting RGB lights',
        _orbiting,
        _demo.accentColor,
        (v) => setState(() => _orbiting = v),
      ),
    ];
  }

  List<Widget> _spotControls() {
    void apply(VoidCallback change) => setState(() {
      change();
      _applySpotSettings();
    });
    return [
      _slider(
        'Cone',
        _coneAngle,
        5,
        150,
        (v) => apply(() => _coneAngle = v),
        format: (v) => '${v.toStringAsFixed(0)} deg',
      ),
      _slider(
        'Softness',
        _coneSoftness,
        0,
        1,
        (v) => apply(() => _coneSoftness = v),
      ),
      _slider(
        'Radius',
        _spotRadius,
        100,
        900,
        (v) => apply(() => _spotRadius = v),
        format: (v) => v.toStringAsFixed(0),
      ),
      _slider(
        'Intensity',
        _spotIntensity,
        0,
        4,
        (v) => apply(() => _spotIntensity = v),
      ),
      _toggle(
        'Sweep',
        _sweeping,
        _demo.accentColor,
        (v) => setState(() => _sweeping = v),
      ),
    ];
  }

  List<Widget> _shadowControls() {
    void apply(VoidCallback change) => setState(() {
      change();
      _applyShadowSettings();
    });
    return [
      _toggle(
        'castsShadows',
        _castShadows,
        _demo.accentColor,
        (v) => apply(() => _castShadows = v),
      ),
      _toggle(
        'Second light',
        _secondLight,
        const Color(0xFF6FD8FF),
        (v) => apply(() => _secondLight = v),
      ),
      _slider(
        'Softness',
        _softness,
        0,
        1,
        (v) => apply(() => _softness = v),
      ),
      _slider(
        'Caster depth',
        _casterDepth,
        0,
        60,
        (v) => apply(() => _casterDepth = v),
        format: (v) => v.toStringAsFixed(0),
      ),
    ];
  }

  List<Widget> _emissiveControls() {
    return [
      _toggle(
        'Flicker',
        _flicker,
        _demo.accentColor,
        (v) => setState(() => _flicker = v),
      ),
      _slider(
        'Flicker',
        _flickerAmount,
        0,
        1,
        (v) => setState(() => _flickerAmount = v),
      ),
      _slider(
        'Glow strength',
        _glowStrength,
        0,
        4,
        (v) => setState(() => _glowStrength = v),
      ),
      _slider(
        'Ambient',
        _caveAmbient,
        0,
        6,
        (v) => setState(() => _caveAmbient = v),
      ),
    ];
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String Function(double)? format,
  }) {
    return SizedBox(
      width: 250,
      height: 30,
      child: Row(
        children: [
          SizedBox(
            width: 78,
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
                inactiveColor: const Color(0xFF1E2E40),
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
                color: Colors.white70,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle(
    String label,
    bool value,
    Color color,
    ValueChanged<bool> onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: value ? color.withValues(alpha: 0.15) : const Color(0xFF0E1A2A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: value
                ? color.withValues(alpha: 0.6)
                : const Color(0xFF1E2E40),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              size: 13,
              color: value ? color : Colors.white38,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.white : Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(String? label, Color colour, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? colour.withValues(alpha: 0.18)
              : const Color(0xFF0E1A2A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected ? colour : const Color(0xFF1E2E40),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colour,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30),
              ),
            ),
            if (label != null) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ],
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
                  'just_game_engine 2.0  Lighting2D * Light2D * ShadowCaster2D',
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
