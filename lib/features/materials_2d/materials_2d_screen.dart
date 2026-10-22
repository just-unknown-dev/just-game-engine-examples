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
const String _backTreesPath =
    'assets/sprites/environment/parallax/parallax-forest-back-trees.png';
const String _middleTreesPath =
    'assets/sprites/environment/parallax/parallax-forest-middle-trees.png';
const String _frontTreesPath =
    'assets/sprites/environment/parallax/parallax-forest-front-trees.png';
const String _raysPath =
    'assets/sprites/environment/parallax/parallax-forest-lights.png';

const String _m = 'assets/materials/';
const String _waveMat = '${_m}sprite_wave.material2d.json';
const String _scrollMat = '${_m}sprite_scroll.material2d.json';
const String _waterMat = '${_m}sprite_water.material2d.json';
const String _swapMat = '${_m}sprite_palette_swap.material2d.json';
const String _swapRedMat = '${_m}sprite_palette_swap_red.material2d.json';
const String _gradientMat = '${_m}sprite_gradient_map.material2d.json';
const String _greyMat = '${_m}sprite_greyscale_tint.material2d.json';
const String _flashMat = '${_m}sprite_flash.material2d.json';
const String _shineMat = '${_m}sprite_shine.material2d.json';
const String _outlineMat = '${_m}sprite_outline_glow.material2d.json';
const String _shadowMat = '${_m}sprite_drop_shadow.material2d.json';
const String _dissolveMat = '${_m}sprite_dissolve.material2d.json';

/// A grid of equal frames in one image, played in a loop.
class _Strip {
  const _Strip(
    this.path,
    this.frameWidth,
    this.frameHeight,
    this.frames,
    this.fps, {
    this.columns = 0,
  });

  final String path;
  final double frameWidth;
  final double frameHeight;
  final int frames;
  final double fps;

  /// Frames per row; 0 for one row.
  final int columns;

  Rect frame(int i) {
    final n = i % frames;
    final perRow = columns == 0 ? frames : columns;
    return Rect.fromLTWH(
      (n % perRow) * frameWidth,
      (n ~/ perRow) * frameHeight,
      frameWidth,
      frameHeight,
    );
  }
}

const _Strip _heroBlue = _Strip(
  'assets/sprites/characters/character02/character_02_idle.png',
  46,
  55,
  10,
  10,
);
const _Strip _heroWalk = _Strip(
  'assets/sprites/characters/character02/character_02_walk.png',
  45,
  58,
  24,
  16,
  columns: 4,
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
  _backTreesPath,
  _middleTreesPath,
  _frontTreesPath,
  _raysPath,
  'assets/sprites/characters/character02/character_02_idle.png',
  'assets/sprites/characters/character02/character_02_walk.png',
  'assets/sprites/characters/character03/character_03_idle_down.png',
];

// -----------------------------------------------------------------------------
// Live values: sliders that write Material2D / ScreenMaterial overrides
// -----------------------------------------------------------------------------

Object _xPair(double v) => <double>[v, 0.0];
Object _xyPair(double v) => <double>[v, v];

/// A slider for one overridable value (`effect.name`) of the entities drawn
/// with [materials].
class _Knob {
  const _Knob(
    this.key,
    this.label,
    this.min,
    this.max,
    this.initial, {
    this.materials = const [],
    this.digits = 2,
    this.encode,
  });

  final String key;
  final String label;
  final double min;
  final double max;
  final double initial;
  final List<String> materials;
  final int digits;

  /// How the slider's number is saved as an override (a pair, say).
  final Object Function(double v)? encode;

  Object valueOf(double v) => encode?.call(v) ?? v;
}

// -----------------------------------------------------------------------------
// Screen materials
// -----------------------------------------------------------------------------

enum _Effect {
  none,
  pixelate,
  crt,
  grade,
  scanlines,
  vignette,
  nightVision;

  String get label => switch (this) {
    none => 'Off',
    pixelate => 'Pixelate',
    crt => 'CRT',
    grade => 'Colour grade',
    scanlines => 'Scanlines',
    vignette => 'Vignette',
    nightVision => 'Night vision',
  };

  String get path => switch (this) {
    none => '',
    pixelate => '${_m}screen_pixelate.material2d.json',
    crt => '${_m}screen_crt.material2d.json',
    grade => '${_m}screen_grade.material2d.json',
    scanlines => '${_m}screen_scanlines.material2d.json',
    vignette => '${_m}screen_vignette.material2d.json',
    nightVision => '${_m}screen_night_vision.material2d.json',
  };

  List<_Knob> get knobs => switch (this) {
    none => const [],
    pixelate => const [
      _Knob('pixelate.size', 'Pixel size', 1, 32, 6, digits: 0),
    ],
    crt => const [
      _Knob('crt.curvature', 'Curvature', 0, 1, 0.18),
      _Knob('crt.aberration', 'Fringe (px)', 0, 16, 2, digits: 1),
    ],
    grade => const [
      _Knob('grade.saturation', 'Saturation', 0, 2, 1.5),
      _Knob('grade.hue', 'Hue shift', -180, 180, 0, digits: 0),
      _Knob('grade.contrast', 'Contrast', 0, 2, 1.2),
    ],
    scanlines => const [
      _Knob('scanlines.amount', 'Amount', 0, 1, 0.4),
      _Knob('scanlines.size', 'Spacing', 1, 16, 3, digits: 0),
    ],
    vignette => const [
      _Knob('vignette.amount', 'Amount', 0, 1, 0.75),
      _Knob('vignette.softness', 'Softness', 0, 1, 0.45),
    ],
    nightVision => const [
      _Knob('gradientMap.amount', 'Amount', 0, 1, 1),
      _Knob('scanlines.amount', 'Scanlines', 0, 1, 0.25),
    ],
  };
}

// -----------------------------------------------------------------------------
// Batching modes
// -----------------------------------------------------------------------------

enum _Batch {
  plain,
  one,
  grouped,
  interleaved;

  String get label => switch (this) {
    plain => 'No material',
    one => 'One material',
    grouped => 'Two, by layer',
    interleaved => 'Two, interleaved',
  };

  String get note => switch (this) {
    plain => '72 plain sprites of one sheet: the sprite batcher, one draw.',
    one =>
      '72 sprites, one material, one sheet: one drawVertices call through '
          'shaders/material_2d.frag.',
    grouped =>
      'Two materials, each on its own layer: one draw per material.',
    interleaved =>
      'Two materials alternating in draw order: every change of material '
          'starts a new draw. Group materials by layer.',
  };
}

// -----------------------------------------------------------------------------
// Demo mode
// -----------------------------------------------------------------------------

enum _Demo {
  motion,
  colour,
  flash,
  shine,
  edges,
  dissolve,
  screen,
  batching;

  String get label => switch (this) {
    motion => 'Wave & Scroll',
    colour => 'Palette & Colour',
    flash => 'Hit Flash',
    shine => 'Shine',
    edges => 'Outline, Glow & Shadow',
    dissolve => 'Dissolve',
    screen => 'Screen Materials',
    batching => 'One Draw per Material',
  };

  IconData get icon => switch (this) {
    motion => Icons.waves,
    colour => Icons.palette,
    flash => Icons.flash_on,
    shine => Icons.auto_awesome,
    edges => Icons.border_outer,
    dissolve => Icons.grain,
    screen => Icons.tv,
    batching => Icons.view_module,
  };

  Color get accentColor => switch (this) {
    motion => const Color(0xFF4FC3F7),
    colour => const Color(0xFFBA68C8),
    flash => const Color(0xFFFFF176),
    shine => const Color(0xFFFFCA28),
    edges => const Color(0xFF4DD0E1),
    dissolve => const Color(0xFFFF8A3D),
    screen => const Color(0xFF81C784),
    batching => const Color(0xFFF5746F),
  };

  String get description => switch (this) {
    motion =>
      'Material2D(material: ...) draws a sprite or shape through a 2-D '
          'material file (*.material2d.json). wave sways rows (or columns, '
          '"direction": "vertical"); scroll slides the picture inside its '
          'frame and wraps. The sliders write this entity\'s own overrides.',
    colour =>
      'paletteSwap turns listed colours into others (team colours); a '
          'variant file names a "parent" and changes only what it gives. '
          'gradientMap picks a colour by brightness; greyscale + tint drain '
          'and recolour.',
    flash =>
      'flash fills the sprite with a colour by flash.amount, a value the '
          'game sets per entity (Material2D.set) and fades out. Tap a '
          'character or shape to hit it.',
    shine =>
      'shine sweeps a bright band across now and then: coins, gems, buttons. '
          'Shapes are drawn once into an image (ShapeSheets), then through '
          'the material like a sprite.',
    edges =>
      'outline and glow draw around the outside; dropShadow draws the shape '
          'again, moved aside and softened. Each effect is a switch in the '
          'file; the sliders override its values.',
    dissolve =>
      'dissolve eats the sprite away in a noisy pattern as its amount '
          'rises, with a burning edge. Drive dissolve.amount from code or a '
          'Timeline property track.',
    screen =>
      'ScreenMaterial (on the camera or any entity, highest order wins) '
          'draws the whole view through a material of the "screen" kind: '
          'pixelate, CRT, colour grade, scanlines, vignette, gradient map. '
          'Works on every renderer.',
    batching =>
      'Every sprite sharing a material and a sheet is drawn in ONE '
          'drawVertices call, in the order the layers say; what differs per '
          'sprite (frame, tint, place, overrides) goes in a small image made '
          'each frame. Watch the draw calls.',
  };

  List<_Knob> get knobs => switch (this) {
    motion => const [
      _Knob(
        'wave.amplitude',
        'Amplitude',
        0,
        16,
        3,
        materials: [_waveMat, _waterMat],
        digits: 1,
      ),
      _Knob(
        'wave.wavelength',
        'Wavelength',
        4,
        128,
        40,
        materials: [_waveMat, _waterMat],
        digits: 0,
      ),
      _Knob(
        'wave.speed',
        'Wave speed',
        -8,
        8,
        2,
        materials: [_waveMat, _waterMat],
        digits: 1,
      ),
      _Knob(
        'scroll.speed',
        'Scroll x',
        -200,
        200,
        -40,
        materials: [_scrollMat],
        digits: 0,
        encode: _xPair,
      ),
    ],
    colour => const [
      _Knob(
        'gradientMap.amount',
        'Gradient',
        0,
        1,
        1,
        materials: [_gradientMat],
      ),
      _Knob('greyscale.amount', 'Greyscale', 0, 1, 1, materials: [_greyMat]),
      _Knob(
        'paletteSwap.tolerance',
        'Tolerance',
        0,
        0.5,
        0.02,
        materials: [_swapMat, _swapRedMat],
        digits: 3,
      ),
    ],
    flash => const [],
    shine => const [
      _Knob('shine.width', 'Width', 0, 1, 0.25, materials: [_shineMat]),
      _Knob(
        'shine.angle',
        'Angle',
        -90,
        90,
        25,
        materials: [_shineMat],
        digits: 0,
      ),
      _Knob(
        'shine.duration',
        'Sweep (s)',
        0.05,
        3,
        0.7,
        materials: [_shineMat],
      ),
      _Knob('shine.interval', 'Pause (s)', 0, 5, 1.2, materials: [_shineMat]),
    ],
    edges => const [
      _Knob(
        'outline.width',
        'Outline',
        0,
        8,
        1.5,
        materials: [_outlineMat],
        digits: 1,
      ),
      _Knob(
        'glow.radius',
        'Glow radius',
        0,
        32,
        8,
        materials: [_outlineMat],
        digits: 0,
      ),
      _Knob(
        'glow.strength',
        'Glow strength',
        0,
        4,
        1.5,
        materials: [_outlineMat],
      ),
      _Knob(
        'dropShadow.offset',
        'Shadow offset',
        -16,
        16,
        4,
        materials: [_shadowMat],
        digits: 0,
        encode: _xyPair,
      ),
      _Knob(
        'dropShadow.softness',
        'Shadow soft',
        0,
        16,
        2,
        materials: [_shadowMat],
        digits: 1,
      ),
    ],
    dissolve => const [
      _Knob('dissolve.amount', 'Amount', 0, 1, 0, materials: [_dissolveMat]),
      _Knob(
        'dissolve.edgeWidth',
        'Edge width',
        0,
        0.5,
        0.12,
        materials: [_dissolveMat],
      ),
      _Knob(
        'dissolve.scale',
        'Grain (px)',
        1,
        32,
        6,
        materials: [_dissolveMat],
        digits: 0,
      ),
    ],
    screen => const [],
    batching => const [],
  };

  String get codeSnippet => switch (this) {
    motion => '''
// assets/materials/sprite_wave.material2d.json
// { "formatVersion": 1,
//   "wave": {"amplitude": 3.0, "wavelength": 40.0, "speed": 2.0} }

world.createEntityWithComponents([
  TransformComponent(position: Vector3(-230, -20, 0)),
  RenderableComponent(renderable: Sprite(image: house)),
  Material2D(material: 'assets/materials/sprite_wave.material2d.json'),
]);

// This entity's own values (the file stays as it is):
final m = entity.getComponent<Material2D>()!;
m.set('wave.amplitude', 6.0);
m.set('scroll.speed', [-80.0, 0.0]); // a pair: [x, y]''',
    colour => '''
// sprite_palette_swap.material2d.json: exact colours, swapped
// { "formatVersion": 1, "paletteSwap": {
//     "swaps": [[4278395324, 4280192058], ...], "tolerance": 0.02 } }

// A variant names a parent and changes only what it gives:
// sprite_palette_swap_red.material2d.json
// { "formatVersion": 1,
//   "parent": "assets/materials/sprite_palette_swap.material2d.json",
//   "paletteSwap": {"swaps": [[4278395324, 4290511649], ...]} }

Material2D(material: 'assets/materials/sprite_gradient_map.material2d.json')
  .set('gradientMap.amount', 0.5);
Material2D(material: 'assets/materials/sprite_greyscale_tint.material2d.json')
  .set('tint.colour', const Color(0xFFFFB3C7).toARGB32()); // ARGB int''',
    flash => '''
// sprite_flash.material2d.json
// { "formatVersion": 1, "flash": {"colour": 4294967295, "amount": 0.0} }

final m = enemy.getComponent<Material2D>()!;
m.set('flash.amount', 1.0);               // on a hit

// every tick, fade it out (eased):
final t = left / 0.35;
m.set('flash.amount', t * t);
m.remove('flash.amount');                 // back to the file's value

m.set('flash.colour', Colors.red.toARGB32()); // colours are ARGB ints''',
    shine => '''
// sprite_shine.material2d.json
// { "formatVersion": 1, "shine": {"colour": 3238002687, "width": 0.25,
//   "angle": 25.0, "duration": 0.7, "interval": 1.2} }

world.createEntityWithComponents([
  TransformComponent(position: Vector3(x, y, 0)),
  CircleComponent(
    radius: 26,
    fillStyle: const ShapePaintStyle(color: Color(0xFFFFC107)),
  ),
  // A shape is drawn once into an image, then through the material.
  Material2D(material: 'assets/materials/sprite_shine.material2d.json'),
]);''',
    edges => '''
// sprite_outline_glow.material2d.json
// { "formatVersion": 1,
//   "outline": {"colour": 4294967295, "width": 1.5},
//   "glow": {"colour": 4283417591, "radius": 8.0, "strength": 1.5} }
// sprite_drop_shadow.material2d.json
// { "formatVersion": 1, "dropShadow": {
//     "colour": 2566914048, "offset": [4.0, 4.0], "softness": 2.0 } }

final m = entity.getComponent<Material2D>()!;
m.set('outline.width', 3.0);
m.set('glow.colour', const Color(0xFFFFD54F).toARGB32());
m.set('dropShadow.offset', [8.0, 8.0]);''',
    dissolve => '''
// sprite_dissolve.material2d.json
// { "formatVersion": 1, "dissolve": {"amount": 0.0,
//   "edgeColour": 4294936576, "edgeWidth": 0.12, "scale": 6.0} }

final m = entity.getComponent<Material2D>()!;
// 0 = whole, 1 = gone. Material2D.overrides is a
// MaterialOverridesFieldType, so a Timeline track can key it too.
m.set('dissolve.amount', t);
if (t >= 1) world.destroyEntity(entity);''',
    screen => '''
// screen_crt.material2d.json
// { "formatVersion": 1, "kind": "screen",
//   "crt": {"curvature": 0.18, "aberration": 2.0},
//   "scanlines": {"amount": 0.2, "size": 3.0},
//   "vignette": {"amount": 0.35, "softness": 0.5} }

final screen = ScreenMaterial(
  material: 'assets/materials/screen_crt.material2d.json',
  order: 0, // of several on, the highest order wins
);
world.createEntityWithComponents([screen], name: 'Screen FX');

screen.set('crt.curvature', 0.4); // live
screen.material = 'assets/materials/screen_pixelate.material2d.json';
screen.enabled = false;           // off''',
    batching => '''
// Sprites sharing a material and a sheet: ONE drawVertices call.
for (var i = 0; i < 72; i++) {
  world.createEntityWithComponents([
    TransformComponent(position: Vector3(x(i), y(i), 0)),
    RenderableComponent(
      renderable: Sprite(image: sheet, sourceRect: frame(i)),
    ),
    Material2D(material: 'assets/materials/sprite_shine.material2d.json'),
  ]);
}
// Batches follow draw order (layer, then zOrder): another material in
// between starts a new draw, so give each material its own layer.
final stats = world.systems.whereType<RenderSystem>().first.stats;
print(stats['drawCalls']);''',
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

/// A character walking back and forth.
class _Walker {
  _Walker(this.entity, this.sprite, this.minX, this.maxX, this.speed);

  final Entity entity;
  final Sprite sprite;
  final double minX;
  final double maxX;
  final double speed;
  double direction = 1;
}

// -----------------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------------

/// 2-D materials (just_game_engine 2.0.0-dev.2): [Material2D] on sprites and
/// shapes, one material file per effect, live overrides, one draw per
/// material, and [ScreenMaterial]s over the whole view.
class Materials2DScreen extends StatefulWidget {
  const Materials2DScreen({super.key});

  @override
  State<Materials2DScreen> createState() => _Materials2DScreenState();
}

class _Materials2DScreenState extends State<Materials2DScreen> {
  late final Engine _engine = demoEngine;
  late final World _world = _engine.world;

  _Demo _demo = _Demo.motion;
  Timer? _hudTimer;
  bool _disposed = false;
  final Map<String, ui.Image> _images = {};
  final List<String> _loadErrors = [];
  bool _imagesReady = false;
  Size _viewSize = Size.zero;

  /// Every slider's value, by override key.
  final Map<String, double> _values = {};

  // What the running demo made.
  double _time = 0;
  final List<_Animated> _animated = [];
  final List<_Walker> _walkers = [];
  final List<Entity> _flashables = [];
  final Map<Material2D, double> _flashLeft = Map.identity();
  ScreenMaterial? _screen;

  // Flash.
  static const double _flashFade = 0.35;
  bool _autoHits = true;
  double _nextHit = 0;
  final math.Random _rng = math.Random(3);
  Color _flashColour = const Color(0xFFFFFFFF);
  int _hits = 0;

  // Colour, edges, dissolve swatches.
  Color _tint = const Color(0xFF9FC8FF);
  Color _glowColour = const Color(0xFF4FC3F7);
  Color _edgeColour = const Color(0xFFFF8800);
  bool _dissolveAuto = true;

  // Screen materials and batching.
  _Effect _effect = _Effect.crt;
  _Batch _batch = _Batch.one;

  // Taps (for the flash demo).
  Offset? _downAt;

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
    DemoEngine.reset(_engine);
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Demo construction
  // -------------------------------------------------------------------------

  void _buildDemo(_Demo demo) {
    _demo = demo;
    DemoEngine.reset(_engine, include: {DefaultSystem.rendering});
    _time = 0;
    _animated.clear();
    _walkers.clear();
    _flashables.clear();
    _flashLeft.clear();
    _nextHit = 0;
    _hits = 0;
    _screen = null;
    _world.addSystem(_TickSystem(_tick));

    if (_imagesReady) {
      if (demo != _Demo.screen) _addGrid();
      switch (demo) {
        case _Demo.motion:
          _buildMotion();
        case _Demo.colour:
          _buildColour();
        case _Demo.flash:
          _buildFlash();
        case _Demo.shine:
          _buildShine();
        case _Demo.edges:
          _buildEdges();
        case _Demo.dissolve:
          _buildDissolve();
        case _Demo.screen:
          _buildScreen();
        case _Demo.batching:
          _buildBatching();
      }
      // The sliders' values onto what was just made.
      for (final knob in demo.knobs) {
        _applyKnob(knob, _values[knob.key] ?? knob.initial);
      }
      _applySwatches();
    }
    _fitCamera();
    if (mounted) setState(() {});
  }

  void _fitCamera() {
    final camera = _engine.cameraSystem.mainCamera;
    camera.position = Offset.zero;
    if (_viewSize.isEmpty) return;
    camera.zoom = math
        .min(_viewSize.width / 940, _viewSize.height / 580)
        .clamp(0.3, 1.6);
  }

  /// Writes [v] for [knob] onto every entity drawn with its materials.
  void _applyKnob(_Knob knob, double v) {
    _values[knob.key] = v;
    final value = knob.valueOf(v);
    for (final material in knob.materials) {
      _setAll(material, knob.key, value);
    }
  }

  /// Sets [key] to [value] on every [Material2D] drawing [material].
  void _setAll(String material, String key, Object value) {
    for (final entity in _world.query(const [Material2D])) {
      final m = entity.getComponent<Material2D>()!;
      if (m.material == material) m.set(key, value);
    }
  }

  void _applySwatches() {
    switch (_demo) {
      case _Demo.colour:
        _setAll(_greyMat, 'tint.colour', _tint.toARGB32());
      case _Demo.flash:
        _setAll(_flashMat, 'flash.colour', _flashColour.toARGB32());
      case _Demo.edges:
        _setAll(_outlineMat, 'glow.colour', _glowColour.toARGB32());
      case _Demo.dissolve:
        _setAll(_dissolveMat, 'dissolve.edgeColour', _edgeColour.toARGB32());
      case _Demo.motion:
      case _Demo.shine:
      case _Demo.screen:
      case _Demo.batching:
        break;
    }
  }

  Entity? _addSprite(
    String path,
    Offset at, {
    double scale = 1,
    Rect? frame,
    int layer = 0,
    String? material,
    String? name,
  }) {
    final image = _images[path];
    if (image == null) return null;
    final sprite = Sprite(image: image, sourceRect: frame)
      ..filterQuality = FilterQuality.none;
    return _world.createEntityWithComponents([
      TransformComponent(
        position: Vector3(at.dx, at.dy, 0),
        scale: Vector3(scale, scale, 1),
      ),
      RenderableComponent(renderable: sprite),
      LayerComponent(layer: layer),
      if (material != null) Material2D(material: material),
    ], name: name);
  }

  /// A character centred on [centre], stepping through [strip].
  Entity? _addHero(
    _Strip strip,
    Offset centre, {
    double scale = 3,
    double phase = 0,
    int layer = 0,
    String? material,
  }) {
    final entity = _addSprite(
      strip.path,
      centre,
      scale: scale,
      frame: strip.frame(0),
      layer: layer,
      material: material,
      name: 'Hero',
    );
    final sprite = entity?.getComponent<RenderableComponent>()?.renderable;
    if (sprite is Sprite) _animated.add(_Animated(sprite, strip, phase));
    return entity;
  }

  Entity _addShape(
    Component shape,
    Offset at, {
    int layer = 0,
    double angle = 0,
    String? material,
    String? name,
  }) => _world.createEntityWithComponents([
    TransformComponent(position: Vector3(at.dx, at.dy, 0), angle: angle),
    shape,
    LayerComponent(layer: layer),
    if (material != null) Material2D(material: material),
  ], name: name);

  void _label(String text, Offset at, {Color colour = const Color(0xFFB0C8E0)}) {
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3(at.dx, at.dy, 0)),
      RenderableComponent(
        renderable: TextRenderable(
          text: text,
          textStyle: TextStyle(
            color: colour,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          layer: 30,
        ),
      ),
    ], name: 'Label');
  }

  List<Offset> _star(int points, double outer, double inner) => [
    for (var i = 0; i < points * 2; i++)
      Offset(
        math.cos(-math.pi / 2 + i * math.pi / points) *
            (i.isEven ? outer : inner),
        math.sin(-math.pi / 2 + i * math.pi / points) *
            (i.isEven ? outer : inner),
      ),
  ];

  void _addGrid() {
    const area = Rect.fromLTWH(-1000, -700, 2000, 1400);
    final path = Path();
    for (double x = area.left; x <= area.right; x += 80) {
      path
        ..moveTo(x, area.top)
        ..lineTo(x, area.bottom);
    }
    for (double y = area.top; y <= area.bottom; y += 80) {
      path
        ..moveTo(area.left, y)
        ..lineTo(area.right, y);
    }
    final paint = Paint()
      ..color = const Color(0xFF1A2535)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -20,
          getBoundsCallback: () => area,
          onRender: (canvas, _) => canvas.drawPath(path, paint),
        ),
      ),
    ], name: 'Grid');
  }

  // -------------------------------------------------------------------------
  // Wave & scroll
  // -------------------------------------------------------------------------

  void _buildMotion() {
    _addSprite(
      _housePath,
      const Offset(-230, -20),
      scale: 1.4,
      material: _waveMat,
      name: 'House (wave)',
    );
    _label('wave', const Offset(-230, 115));

    _addSprite(
      _backTreesPath,
      const Offset(220, -100),
      scale: 1.3,
      material: _scrollMat,
      name: 'Forest (scroll)',
    );
    _label('scroll: slides and wraps', const Offset(220, 20));

    _addShape(
      RectangleComponent(
        width: 360,
        height: 80,
        fillStyle: const ShapePaintStyle(color: Color(0xFF1E88E5)),
        strokeStyle: const ShapePaintStyle(color: Color(0xFFB3E5FC)),
        strokeWidth: 4,
      ),
      const Offset(220, 140),
      material: _waterMat,
      name: 'Water (vertical wave)',
    );
    _label('wave, "direction": "vertical"', const Offset(220, 205));

    _addHero(
      _heroBlue,
      const Offset(-230, 190),
      scale: 2,
      material: _waveMat,
    );
  }

  // -------------------------------------------------------------------------
  // Palette & colour
  // -------------------------------------------------------------------------

  void _buildColour() {
    const row = -95.0;
    final subjects = [
      (null, 'original'),
      (_swapMat, 'paletteSwap'),
      (_swapRedMat, 'variant (parent)'),
      (_gradientMat, 'gradientMap'),
      (_greyMat, 'greyscale + tint'),
    ];
    for (var i = 0; i < subjects.length; i++) {
      final (material, name) = subjects[i];
      final x = -340 + i * 170.0;
      _addHero(_heroBlue, Offset(x, row), material: material, phase: i * 0.13);
      _label(name, Offset(x, row + 100));
    }
    final houses = [
      (null, 'original'),
      (_gradientMat, 'gradientMap'),
      (_greyMat, 'greyscale + tint'),
    ];
    for (var i = 0; i < houses.length; i++) {
      final (material, name) = houses[i];
      final x = -240 + i * 240.0;
      _addSprite(
        _housePath,
        Offset(x, 150),
        scale: 0.75,
        material: material,
        name: 'House',
      );
      _label(name, Offset(x, 225));
    }
  }

  // -------------------------------------------------------------------------
  // Hit flash
  // -------------------------------------------------------------------------

  void _buildFlash() {
    for (var i = 0; i < 6; i++) {
      final blue = i.isEven;
      final entity = _addHero(
        blue ? _heroBlue : _heroRed,
        Offset(-350 + i * 140.0, blue ? -60 : -55),
        scale: blue ? 2.6 : 2.8,
        phase: i * 0.21,
        material: _flashMat,
      );
      if (entity != null) _flashables.add(entity);
    }
    final shapes = <Component>[
      CircleComponent(
        radius: 36,
        fillStyle: const ShapePaintStyle(color: Color(0xFFFFB300)),
        strokeStyle: const ShapePaintStyle(color: Color(0xFFFF6F00)),
        strokeWidth: 4,
      ),
      RectangleComponent(
        width: 90,
        height: 64,
        cornerRadius: 12,
        fillStyle: const ShapePaintStyle(color: Color(0xFF7E57C2)),
        strokeWidth: 3,
      ),
      PolygonComponent(
        vertices: _star(5, 44, 20),
        fillStyle: const ShapePaintStyle(color: Color(0xFF66BB6A)),
        strokeWidth: 3,
      ),
    ];
    for (var i = 0; i < shapes.length; i++) {
      _flashables.add(
        _addShape(
          shapes[i],
          Offset(-200 + i * 200.0, 150),
          material: _flashMat,
          name: 'Flash shape',
        ),
      );
    }
    _label('tap one to hit it', const Offset(0, 235));
  }

  void _hit(Entity entity) {
    final m = entity.getComponent<Material2D>();
    if (m == null) return;
    m.set('flash.amount', 1.0);
    _flashLeft[m] = _flashFade;
    _hits++;
  }

  void _onTap(Offset local) {
    if (_demo != _Demo.flash) return;
    final at = _engine.cameraSystem.mainCamera.screenToWorld(local);
    Entity? nearest;
    var best = 110.0;
    for (final e in _flashables) {
      final p = e.getComponent<TransformComponent>()!.position;
      final d = (Offset(p.x, p.y) - at).distance;
      if (d < best) {
        best = d;
        nearest = e;
      }
    }
    if (nearest != null) {
      _hit(nearest);
    } else {
      _flashables.forEach(_hit);
    }
  }

  // -------------------------------------------------------------------------
  // Shine
  // -------------------------------------------------------------------------

  void _buildShine() {
    for (var i = 0; i < 5; i++) {
      _addShape(
        CircleComponent(
          radius: 26,
          fillStyle: const ShapePaintStyle(color: Color(0xFFFFC107)),
          strokeStyle: const ShapePaintStyle(color: Color(0xFFFF8F00)),
          strokeWidth: 4,
        ),
        Offset(-300 + i * 150.0, -170),
        material: _shineMat,
        name: 'Coin',
      );
    }
    _label('coins (CircleComponent)', const Offset(0, -120));
    const gems = [Color(0xFFE53935), Color(0xFF43A047), Color(0xFF1E88E5)];
    for (var i = 0; i < gems.length; i++) {
      _addShape(
        PolygonComponent(
          vertices: const [
            Offset(0, -34),
            Offset(26, -8),
            Offset(0, 34),
            Offset(-26, -8),
          ],
          fillStyle: ShapePaintStyle(color: gems[i]),
          strokeStyle: const ShapePaintStyle(color: Color(0xCCFFFFFF)),
          strokeWidth: 2,
        ),
        Offset(-160 + i * 160.0, -20),
        material: _shineMat,
        name: 'Gem',
      );
    }
    _label('gems (PolygonComponent)', const Offset(0, 35));
    _addShape(
      RectangleComponent(
        width: 220,
        height: 56,
        cornerRadius: 14,
        fillStyle: const ShapePaintStyle(color: Color(0xFF3949AB)),
        strokeStyle: const ShapePaintStyle(color: Color(0xFF9FA8DA)),
        strokeWidth: 3,
      ),
      const Offset(0, 140),
      material: _shineMat,
      name: 'Button',
    );
    _label('PLAY', const Offset(0, 140), colour: Colors.white);
    _addHero(
      _heroBlue,
      const Offset(-330, 120),
      material: _shineMat,
    );
    _addHero(
      _heroRed,
      const Offset(330, 100),
      phase: 0.4,
      material: _shineMat,
    );
  }

  // -------------------------------------------------------------------------
  // Outline, glow & drop shadow
  // -------------------------------------------------------------------------

  void _buildEdges() {
    // A light panel behind the shadow row: a dark shadow on the dark grid
    // would hardly show.
    _addShape(
      RectangleComponent(
        width: 880,
        height: 200,
        cornerRadius: 16,
        fillStyle: const ShapePaintStyle(color: Color(0xFFD5DBE6)),
        strokeWidth: 0,
      ),
      const Offset(0, 130),
      layer: -5,
      name: 'Panel',
    );
    for (final (row, material, title) in const [
      (-110.0, _outlineMat, 'outline + glow'),
      (130.0, _shadowMat, 'dropShadow'),
    ]) {
      _label(title, Offset(-380, row - 112), colour: _demo.accentColor);
      _addHero(_heroBlue, Offset(-300, row), material: material);
      _addHero(
        _heroRed,
        Offset(-100, row + 5),
        phase: 0.3,
        material: material,
      );
      _addShape(
        PolygonComponent(
          vertices: _star(5, 46, 20),
          fillStyle: const ShapePaintStyle(color: Color(0xFFFFCA28)),
          strokeWidth: 0,
        ),
        Offset(100, row),
        material: material,
        name: 'Star',
      );
      _addSprite(
        _housePath,
        Offset(310, row),
        scale: 0.7,
        material: material,
        name: 'House',
      );
    }
  }

  // -------------------------------------------------------------------------
  // Dissolve
  // -------------------------------------------------------------------------

  void _buildDissolve() {
    _addSprite(
      _housePath,
      const Offset(-200, -20),
      scale: 1.3,
      material: _dissolveMat,
      name: 'House',
    );
    _addHero(_heroBlue, const Offset(110, -30), material: _dissolveMat);
    _addHero(
      _heroRed,
      const Offset(300, -20),
      phase: 0.2,
      material: _dissolveMat,
    );
    _addShape(
      RectangleComponent(
        width: 280,
        height: 70,
        cornerRadius: 10,
        fillStyle: const ShapePaintStyle(color: Color(0xFF26A69A)),
        strokeStyle: const ShapePaintStyle(color: Color(0xFFB2DFDB)),
        strokeWidth: 3,
      ),
      const Offset(200, 170),
      material: _dissolveMat,
      name: 'Card',
    );
    _addShape(
      CircleComponent(
        radius: 44,
        fillStyle: const ShapePaintStyle(color: Color(0xFFEC407A)),
        strokeWidth: 0,
      ),
      const Offset(-200, 170),
      material: _dissolveMat,
      name: 'Orb',
    );
  }

  // -------------------------------------------------------------------------
  // Screen materials
  // -------------------------------------------------------------------------

  void _buildScreen() {
    // A forest in four parallax layers drawn over each other, three wide.
    const scale = 3.8, tile = 272 * scale;
    for (final x in const [-tile, 0.0, tile]) {
      _addSprite(_backTreesPath, Offset(x, 0), scale: scale, layer: -20);
      _addSprite(_middleTreesPath, Offset(x, 0), scale: scale, layer: -18);
      _addSprite(_raysPath, Offset(x, 0), scale: scale, layer: -17);
      _addSprite(_frontTreesPath, Offset(x, 0), scale: scale, layer: -10);
    }
    _addSprite(_housePath, const Offset(330, 142), layer: -15, name: 'House');
    _addHero(_heroRed, const Offset(-120, 145), scale: 2.5, layer: -8);
    final walker = _addHero(
      _heroWalk,
      const Offset(-300, 136),
      scale: 2.2,
      layer: -8,
    );
    final sprite = walker?.getComponent<RenderableComponent>()?.renderable;
    if (walker != null && sprite is Sprite) {
      _walkers.add(_Walker(walker, sprite, -420, 420, 70));
    }
    // Saturated colours, to see a grade or a hue shift.
    const swatches = [
      Color(0xFFE53935),
      Color(0xFFFB8C00),
      Color(0xFFFDD835),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFF8E24AA),
    ];
    for (var i = 0; i < swatches.length; i++) {
      _addShape(
        CircleComponent(
          radius: 20,
          fillStyle: ShapePaintStyle(color: swatches[i]),
          strokeStyle: const ShapePaintStyle(color: Color(0xFFFFFFFF)),
          strokeWidth: 3,
        ),
        Offset(-250 + i * 100.0, -215),
        layer: 5,
        name: 'Swatch',
      );
    }
    final screen = ScreenMaterial(material: _effect.path, order: 0);
    _screen = screen;
    _world.createEntityWithComponents([screen], name: 'Screen FX');
    _selectEffect(_effect);
  }

  void _selectEffect(_Effect effect) {
    _effect = effect;
    final screen = _screen;
    if (screen == null) return;
    screen
      ..enabled = effect != _Effect.none
      ..material = effect.path
      ..overrides = const {};
    for (final knob in effect.knobs) {
      _applyScreenKnob(knob, _values['screen:${knob.key}'] ?? knob.initial);
    }
  }

  void _applyScreenKnob(_Knob knob, double v) {
    _values['screen:${knob.key}'] = v;
    _screen?.set(knob.key, knob.valueOf(v));
  }

  // -------------------------------------------------------------------------
  // One draw per material
  // -------------------------------------------------------------------------

  void _buildBatching() {
    const columns = 12, rows = 6;
    const dx = 74.0, dy = 88.0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        final odd = (r + c).isOdd;
        final material = switch (_batch) {
          _Batch.plain => null,
          _Batch.one => _shineMat,
          _Batch.grouped || _Batch.interleaved =>
            odd ? _outlineMat : _shineMat,
        };
        _addHero(
          _heroBlue,
          Offset(-(columns - 1) * dx / 2 + c * dx, -(rows - 1) * dy / 2 + r * dy),
          scale: 1.5,
          phase: (r * columns + c) * 0.071,
          layer: _batch == _Batch.grouped && odd ? 1 : 0,
          material: material,
        );
      }
    }
  }

  // -------------------------------------------------------------------------
  // Per tick
  // -------------------------------------------------------------------------

  void _tick(double dt) {
    _time += dt;
    for (final a in _animated) {
      a.step(_time);
    }
    for (final w in _walkers) {
      final t = w.entity.getComponent<TransformComponent>()!;
      var x = t.position.x + w.direction * w.speed * dt;
      if (x > w.maxX || x < w.minX) {
        w.direction = -w.direction;
        x = x.clamp(w.minX, w.maxX);
      }
      t.position.setValues(x, t.position.y, 0);
      w.sprite.flipX = w.direction < 0;
    }
    if (_flashLeft.isNotEmpty) {
      for (final m in [..._flashLeft.keys]) {
        final left = _flashLeft[m]! - dt;
        if (left <= 0) {
          m.remove('flash.amount');
          _flashLeft.remove(m);
        } else {
          _flashLeft[m] = left;
          final t = left / _flashFade;
          m.set('flash.amount', t * t);
        }
      }
    }
    if (_demo == _Demo.flash && _autoHits && _flashables.isNotEmpty) {
      if (_time >= _nextHit) {
        _hit(_flashables[_rng.nextInt(_flashables.length)]);
        _nextHit = _time + 0.35 + _rng.nextDouble() * 0.5;
      }
    }
    if (_demo == _Demo.dissolve && _dissolveAuto) {
      final amount = 0.5 - 0.5 * math.cos(_time * 2 * math.pi / 4);
      _applyKnob(_Demo.dissolve.knobs.first, amount);
    }
  }

  // -------------------------------------------------------------------------
  // Stats
  // -------------------------------------------------------------------------

  Map<String, int> get _renderStats {
    for (final s in _world.systems) {
      if (s is RenderSystem) return s.stats;
    }
    return const {};
  }

  String get _statsLine {
    final stats = _renderStats;
    final materials = <String>{};
    var withMaterial = 0;
    for (final e in _world.query(const [Material2D])) {
      withMaterial++;
      materials.add(e.getComponent<Material2D>()!.material);
    }
    final screen = _screen;
    return 'draw calls ${stats['drawCalls'] ?? 0}'
        '  rendered ${stats['renderedObjects'] ?? 0}'
        '  Material2D $withMaterial (${materials.length} files)'
        '${screen != null && screen.enabled ? '  ScreenMaterial ${_effect.label}' : ''}'
        '  entities ${_world.entities.length}';
  }

  String get _statusMessage {
    if (_loadErrors.isNotEmpty) return 'Could not load: ${_loadErrors.first}';
    if (!_imagesReady) return 'Loading sprites...';
    final library = Material2DLibrary.of(_engine.context);
    if (library.programError != null) {
      return 'The 2-D material shader did not load: ${library.programError}';
    }
    final paths = <String>{
      for (final e in _world.query(const [Material2D]))
        e.getComponent<Material2D>()!.material,
      if (_screen case final s? when s.material.isNotEmpty) s.material,
    };
    for (final p in paths) {
      final error = library.errorOf(p);
      if (error != null) return 'Material $p: $error';
      final problems = library.problemsOf(p);
      if (problems.isNotEmpty) return 'Material $p: ${problems.first}';
    }
    final loaded = paths.where((p) => library.fileOf(p) != null).length;
    if (loaded < paths.length || library.program == null) {
      return 'Reading materials ($loaded/${paths.length})...';
    }
    return switch (_demo) {
      _Demo.motion => 'Drag to pan, scroll or pinch to zoom',
      _Demo.colour =>
        'Same sprite sheet, five materials; swaps match exact colours',
      _Demo.flash => 'Hits so far: $_hits',
      _Demo.shine => 'Every subject shares one material file',
      _Demo.edges =>
        'Widths are in the image\'s pixels: a sprite\'s own (scaled x3 here), '
            'a shape\'s as drawn on screen',
      _Demo.dissolve =>
        'dissolve.amount ${(_values['dissolve.amount'] ?? 0).toStringAsFixed(2)}',
      _Demo.screen =>
        'Drawn under the ScreenMaterial: the game; over it: Flutter widgets',
      _Demo.batching => _batch.note,
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
              const Text(
                'Material2D  *  ScreenMaterial  *  *.material2d.json',
                style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10),
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
          enablePan: true,
          enablePinch: true,
          showZoomLevel: true,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _downAt = e.localPosition,
            onPointerUp: (e) {
              final down = _downAt;
              _downAt = null;
              if (down != null && (e.localPosition - down).distance < 8) {
                _onTap(e.localPosition);
              }
            },
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
        children: [
          ..._extraControls(),
          for (final knob in _demo.knobs)
            _slider(
              knob.label,
              _values[knob.key] ?? knob.initial,
              knob.min,
              knob.max,
              knob.digits,
              (v) => setState(() {
                if (knob.key == 'dissolve.amount') _dissolveAuto = false;
                _applyKnob(knob, v);
              }),
            ),
        ],
      ),
    );
  }

  List<Widget> _extraControls() {
    final accent = _demo.accentColor;
    switch (_demo) {
      case _Demo.colour:
        return [
          _caption('tint.colour'),
          for (final c in const [
            Color(0xFF9FC8FF),
            Color(0xFFFFB3C7),
            Color(0xFFFFE082),
            Color(0xFFFFFFFF),
          ])
            _swatch(c, _tint == c, () {
              setState(() => _tint = c);
              _applySwatches();
            }),
        ];
      case _Demo.flash:
        return [
          _button('Hit all', accent, () => _flashables.forEach(_hit)),
          _toggle(
            'Random hits',
            _autoHits,
            accent,
            (v) => setState(() => _autoHits = v),
          ),
          _caption('flash.colour'),
          for (final c in const [
            Color(0xFFFFFFFF),
            Color(0xFFFF3B3B),
            Color(0xFFFFD54F),
            Color(0xFF4DD0E1),
          ])
            _swatch(c, _flashColour == c, () {
              setState(() => _flashColour = c);
              _applySwatches();
            }),
        ];
      case _Demo.edges:
        return [
          _caption('glow.colour'),
          for (final c in const [
            Color(0xFF4FC3F7),
            Color(0xFFFFD54F),
            Color(0xFFFF4081),
            Color(0xFF69F0AE),
          ])
            _swatch(c, _glowColour == c, () {
              setState(() => _glowColour = c);
              _applySwatches();
            }),
        ];
      case _Demo.dissolve:
        return [
          _toggle(
            'Animate',
            _dissolveAuto,
            accent,
            (v) => setState(() => _dissolveAuto = v),
          ),
          _caption('edgeColour'),
          for (final c in const [
            Color(0xFFFF8800),
            Color(0xFF4DD0E1),
            Color(0xFF76FF03),
            Color(0xFFE040FB),
          ])
            _swatch(c, _edgeColour == c, () {
              setState(() => _edgeColour = c);
              _applySwatches();
            }),
        ];
      case _Demo.screen:
        return [
          for (final e in _Effect.values)
            _choice(
              e.label,
              e == _effect,
              accent,
              () => setState(() => _selectEffect(e)),
            ),
          for (final knob in _effect.knobs)
            _slider(
              knob.label,
              _values['screen:${knob.key}'] ?? knob.initial,
              knob.min,
              knob.max,
              knob.digits,
              (v) => setState(() => _applyScreenKnob(knob, v)),
            ),
        ];
      case _Demo.batching:
        return [
          for (final b in _Batch.values)
            _choice(b.label, b == _batch, accent, () {
              _batch = b;
              _buildDemo(_Demo.batching);
            }),
        ];
      case _Demo.motion:
      case _Demo.shine:
        return const [];
    }
  }

  Widget _caption(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white38,
      fontSize: 10,
      fontFamily: 'monospace',
    ),
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    int digits,
    ValueChanged<double> onChanged,
  ) {
    return SizedBox(
      width: 250,
      height: 30,
      child: Row(
        children: [
          SizedBox(
            width: 84,
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
            width: 40,
            child: Text(
              value.toStringAsFixed(digits),
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

  Widget _choice(String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : const Color(0xFF0E1A2A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.7)
                : const Color(0xFF1E2E40),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _button(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _swatch(Color colour, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: colour,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2.5 : 1,
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
                  'just_game_engine 2.0  2-D materials',
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
