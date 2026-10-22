import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/engine/demo_engine.dart';
import '../../core/widgets/camera_zoom_controls.dart';

// -----------------------------------------------------------------------------
// Assets
// -----------------------------------------------------------------------------

const _kHouseRoot = 'assets/sprites/environment/house';

/// TexturePacker multi-page atlas: character02's idle sheet (page 0) and
/// walk sheet (page 1).
const _kChar02Atlas =
    'assets/sprites/characters/character02/character02.atlas.json';

/// TexturePacker multi-page atlas: one page per character03 direction.
const _kChar03Atlas =
    'assets/sprites/characters/character03/character03.atlas.json';

// -----------------------------------------------------------------------------
// Demo mode
// -----------------------------------------------------------------------------

enum _SpriteDemo {
  environment,
  atlasInspector,
  characters,
  batching,
  layers;

  String get label => switch (this) {
    environment => 'Environment',
    atlasInspector => 'Atlas Regions',
    characters => 'Multi-Page',
    batching => 'Batching & ySort',
    layers => 'Layers & Tint',
  };

  IconData get icon => switch (this) {
    environment => Icons.landscape_outlined,
    atlasInspector => Icons.grid_on_outlined,
    characters => Icons.people_outline,
    batching => Icons.view_module_outlined,
    layers => Icons.flip_to_front,
  };

  Color get accentColor => switch (this) {
    environment => const Color(0xFF81C784),
    atlasInspector => const Color(0xFF4DD0E1),
    characters => const Color(0xFFFFB74D),
    batching => const Color(0xFF9575CD),
    layers => const Color(0xFFF06292),
  };

  String get description => switch (this) {
    environment =>
      'Three house images loaded with Sprite.fromAsset(path, assets: '
          'engine.assets): the engine\'s asset manager caches each image and '
          'the sprite keeps its own handle, released by sprite.dispose(). '
          'Each sprite is an entity\'s RenderableComponent; the '
          'TransformComponent (scale included) is synced onto it.',
    atlasInspector =>
      'The raw pages of character02.atlas.json (a TexturePacker multi-page '
          'export) with every SpriteRegion outlined. On the right, '
          'SpriteComponent(spritePath:, atlasPath:, region:) shows one frame '
          'of the sheet; the slider changes region and SpriteLoadSystem '
          'swaps the frame.',
    characters =>
      'The first frame of every direction in the character03 atlas: eight '
          'SpriteComponents naming regions on eight different page images. '
          'SpriteLoadSystem loads the atlas once and makes each sprite from '
          'its region.',
    batching =>
      'A crowd of sprites from one atlas page, drawn in batches '
          '(drawRawAtlas): RenderSystem.stats counts the draw calls. Mirrored '
          'sprites cannot share a batch and draw one by one. ySort draws the '
          'ones lower on screen in front, within their layer.',
    layers =>
      'Draw order follows LayerComponent (layer, then zOrder): raise a '
          'house\'s zOrder to bring it to the front. A SpriteComponent tint '
          'multiplies the colour, and since 2.0 its alpha fades the sprite '
          '(use an opaque tint for the old look).',
  };

  String get codeSnippet => switch (this) {
    environment =>
      'final sprite = await Sprite.fromAsset(\n'
          '  \'$_kHouseRoot/house_01.png\',\n'
          '  assets: engine.assets, // cached by the engine\n'
          ')..filterQuality = FilterQuality.none;\n\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(\n'
          '    position: Vector3(-420, 0, 0),\n'
          '    scale: Vector3(0.45, 0.45, 1), // synced onto the sprite\n'
          '  ),\n'
          '  RenderableComponent(renderable: sprite),\n'
          '  LayerComponent(layer: 8),\n'
          ']);\n\n'
          '// When the sprite is no longer drawn:\n'
          'sprite.dispose(); // releases its image handle',
    atlasInspector =>
      'final atlas = await SpriteAtlas.fromAsset(\n'
          '  \'$_kChar02Atlas\',\n'
          '  assets: engine.assets,\n'
          ');\n'
          'for (final name in atlas.regionNames) {\n'
          '  final region = atlas.getRegion(name)!;\n'
          '  print(\'\$name: page \${region.pageIndex} \${region.frame}\');\n'
          '}\n\n'
          '// One frame of a sheet (SpriteLoadSystem, DefaultSystem.sprites):\n'
          'final frame = SpriteComponent(\n'
          '  spritePath: \'\', // unused with an atlas\n'
          '  atlasPath: \'$_kChar02Atlas\',\n'
          '  region: \'walk_5\',\n'
          '  pixelArt: true,\n'
          ');\n'
          'frame.region = \'walk_6\'; // shown on the next update',
    characters =>
      '// One TexturePacker atlas, one page per direction image:\n'
          'for (final (i, clip) in clips.indexed) {\n'
          '  world.createEntityWithComponents([\n'
          '    TransformComponent(\n'
          '      position: gridPos(i),\n'
          '      scale: Vector3(2, 2, 1),\n'
          '    ),\n'
          '    SpriteComponent(\n'
          '      spritePath: \'\',\n'
          '      atlasPath: \'$_kChar03Atlas\',\n'
          '      region: \'\${clip}_0\', // a region on that clip\'s page\n'
          '      pixelArt: true,\n'
          '    ),\n'
          '  ]);\n'
          '}',
    batching =>
      'final sprite = atlas.createSprite(\'walk_\$i\')\n'
          '  ..ySort = true   // by world y, within its layer\n'
          '  ..flipX = false; // a mirrored sprite draws unbatched\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(position: pos, scale: Vector3(1.5, 1.5, 1)),\n'
          '  VelocityComponent(velocity: v), // DefaultSystem.movement\n'
          '  RenderableComponent(renderable: sprite),\n'
          ']);\n\n'
          'final stats = world.getSystem<RenderSystem>()!.stats;\n'
          'print(\'\${stats[\'drawCalls\']} draws, \'\n'
          '    \'\${stats[\'batchedSprites\']} sprites batched\');',
    layers =>
      'final house = world.createEntityWithComponents([\n'
          '  TransformComponent(position: pos, scale: Vector3(0.6, 0.6, 1)),\n'
          '  SpriteComponent(\n'
          '    spritePath: \'$_kHouseRoot/house_01.png\',\n'
          '    pixelArt: true,\n'
          '  ),\n'
          '  LayerComponent(layer: 0, zOrder: 1), // higher draws later\n'
          ']);\n\n'
          '// Bring to front:\n'
          'house.getComponent<LayerComponent>()!.zOrder = ++top;\n'
          '// A translucent tint now fades the sprite:\n'
          'house.getComponent<SpriteComponent>()!.tint =\n'
          '    Colors.cyan.withValues(alpha: 0.5);',
  };
}

// -----------------------------------------------------------------------------
// ECS -- the crowd's wandering
// -----------------------------------------------------------------------------

/// Keeps a moving entity inside [bounds], and mirrors its sprite to face
/// the way it walks while [mirror] is on.
class _BounceComponent extends Component {
  _BounceComponent({required this.bounds, required this.mirror});

  final Rect bounds;
  bool mirror;
}

/// Bounces velocities off the walls; `MovementSystem` does the moving.
class _BounceSystem extends System {
  @override
  int get priority => SystemPriorities.playerControl;

  @override
  List<Type> get requiredComponents => const [
    TransformComponent,
    VelocityComponent,
    _BounceComponent,
  ];

  @override
  void update(double deltaTime) {
    forEach((entity) {
      final t = entity.getComponent<TransformComponent>()!;
      final v = entity.getComponent<VelocityComponent>()!;
      final b = entity.getComponent<_BounceComponent>()!;
      final p = t.position;
      final vel = v.velocity;
      if ((p.x < b.bounds.left && vel.x < 0) ||
          (p.x > b.bounds.right && vel.x > 0)) {
        v.velocity = Vector3(-vel.x, vel.y, 0);
      }
      if ((p.y < b.bounds.top && vel.y < 0) ||
          (p.y > b.bounds.bottom && vel.y > 0)) {
        v.velocity = Vector3(v.velocity.x, -vel.y, 0);
      }
      final sprite = entity.getComponent<RenderableComponent>()?.renderable;
      if (sprite is Sprite) sprite.flipX = b.mirror && v.velocity.x < 0;
    });
  }
}

// -----------------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------------

class SpriteSystemScreen extends StatefulWidget {
  const SpriteSystemScreen({super.key});

  @override
  State<SpriteSystemScreen> createState() => _SpriteSystemScreenState();
}

class _SpriteSystemScreenState extends State<SpriteSystemScreen>
    with SingleTickerProviderStateMixin {
  // The app's one shared 2-D engine: already started and driven by the
  // GameWidget, so this screen never steps the world itself.
  late final Engine _engine = demoEngine;
  late final World _world = _engine.world;
  late final Ticker _ticker;
  final math.Random _random = math.Random();

  // Demo state
  _SpriteDemo _demo = _SpriteDemo.environment;
  bool _loading = true;
  String? _loadError;
  String _statusMessage = '';

  // Loaded once: house sprites (Sprite.fromAsset — this screen disposes
  // them) and the two atlases (cached in engine.assets, shared with the
  // sprite systems).
  final Map<String, Sprite> _houses = {};
  final Map<String, Size> _houseSizes = {};
  SpriteAtlas? _char02Atlas;
  SpriteAtlas? _char03Atlas;

  // Credit info from house info.json
  String _houseArtist = '';
  String _houseSource = '';

  // Environment
  double _envScale = 0.45;

  // Atlas Regions
  int _inspectorPage = 1;
  double _inspectorScale = 0.9;
  int _regionIndex = 5;
  Entity? _regionPreview;
  Entity? _regionLabel;

  // Multi-Page
  double _charScale = 2.0;

  // Batching & ySort
  int _crowdCount = 120;
  bool _ySort = true;
  bool _mirror = false;
  final List<Entity> _crowd = [];

  // Layers & Tint
  final List<Entity> _layerHouses = [];
  final List<Entity> _layerLabels = [];
  int _topZ = 2;
  Color? _tintColor;
  double _tintAlpha = 1.0;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _ticker.dispose();
    // Clears the shared world and leaves the engine running; then the house
    // sprites, no longer drawn, let go of their images.
    DemoEngine.reset(_engine);
    for (final sprite in _houses.values) {
      sprite.dispose();
    }
    _houses.clear();
    super.dispose();
  }

  void _onTick(Duration _) {
    if (!mounted) return;
    _syncLayerLabels();
    setState(() {});
  }

  // -------------------------------------------------------------------------
  // Loading
  // -------------------------------------------------------------------------

  Future<void> _initialize() async {
    try {
      await _loadAssets();
    } catch (error) {
      _loadError = '$error';
    }
    if (!mounted) {
      for (final sprite in _houses.values) {
        sprite.dispose();
      }
      return;
    }
    setState(() => _loading = false);
    _buildDemo(_demo);
  }

  Future<void> _loadAssets() async {
    final assets = _engine.assets;

    // -- Houses: one image each, through the engine's asset manager --------
    final houseJson =
        (await assets.loadJson('$_kHouseRoot/info.json')).data
            as Map<String, dynamic>;
    final credits = houseJson['credits'] as Map<String, dynamic>?;
    _houseArtist = (credits?['artist'] as String?) ?? '';
    _houseSource = (credits?['source'] as String?) ?? '';

    final spritesMap =
        (houseJson['sprites'] as Map<String, dynamic>?) ?? const {};
    final houseNames = spritesMap.keys.toList()..sort();
    for (final name in houseNames) {
      final info = spritesMap[name] as Map<String, dynamic>;
      final sprite = await Sprite.fromAsset(
        '$_kHouseRoot/${info['imagePath']}',
        assets: assets,
      );
      // Pixel art: keep the pixels square when scaled.
      sprite.filterQuality = FilterQuality.none;
      _houses[name] = sprite;
      _houseSizes[name] = Size(
        (info['width'] as num).toDouble(),
        (info['height'] as num).toDouble(),
      );
    }

    // -- Atlases: TexturePacker multi-page files ----------------------------
    _char02Atlas = await SpriteAtlas.fromAsset(_kChar02Atlas, assets: assets);
    _char03Atlas = await SpriteAtlas.fromAsset(_kChar03Atlas, assets: assets);
  }

  // -------------------------------------------------------------------------
  // Demo construction
  // -------------------------------------------------------------------------

  void _buildDemo(_SpriteDemo demo) {
    if (!mounted) return;
    _demo = demo;
    _statusMessage = '';
    _regionPreview = null;
    _regionLabel = null;
    _crowd.clear();
    _layerHouses.clear();
    _layerLabels.clear();

    // A clean world: the standard renderer, the sprite systems
    // (SpriteLoadSystem shows SpriteComponents) and MovementSystem.
    DemoEngine.reset(
      _engine,
      include: {
        DefaultSystem.rendering,
        DefaultSystem.sprites,
        DefaultSystem.movement,
      },
    );
    _world.addSystem(_BounceSystem());

    if (_char02Atlas == null || _char03Atlas == null || _houses.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    switch (demo) {
      case _SpriteDemo.environment:
        _buildEnvironmentDemo();
      case _SpriteDemo.atlasInspector:
        _buildAtlasInspectorDemo();
      case _SpriteDemo.characters:
        _buildCharactersDemo();
      case _SpriteDemo.batching:
        _buildBatchingDemo();
      case _SpriteDemo.layers:
        _buildLayersDemo();
    }

    if (mounted) setState(() {});
  }

  Entity _spawnText(
    Offset at,
    String text, {
    Color color = const Color(0xFFF0F5E9),
    double size = 12,
  }) {
    return _world.createEntityWithComponents([
      TransformComponent(position: Vector3.fromOffset(at)),
      RenderableComponent(
        renderable: TextRenderable(
          text: text,
          textStyle: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      LayerComponent(layer: 30),
    ], name: 'label');
  }

  void _spawnGrid({
    Color color = const Color(0xFF1A2E40),
    double step = 72,
    Rect? band,
  }) {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          getBoundsCallback: () => const Rect.fromLTRB(-1000, -700, 1000, 700),
          onRender: (canvas, _) {
            final gridPaint = Paint()
              ..color = color.withValues(alpha: 0.35)
              ..strokeWidth = 1;
            for (double x = -1000; x <= 1000; x += step) {
              canvas.drawLine(Offset(x, -700), Offset(x, 700), gridPaint);
            }
            for (double y = -700; y <= 700; y += step) {
              canvas.drawLine(Offset(-1000, y), Offset(1000, y), gridPaint);
            }
            if (band != null) {
              canvas.drawRect(
                band,
                Paint()..color = const Color(0xFF2B3D2E).withValues(alpha: 0.4),
              );
            }
          },
        ),
      ),
      // Behind everything else.
      LayerComponent(layer: -20),
    ], name: 'backdrop');
  }

  // -- Environment -----------------------------------------------------------

  void _buildEnvironmentDemo() {
    _spawnGrid(
      color: const Color(0xFF1E2A1F),
      step: 80,
      band: const Rect.fromLTRB(-1000, 60, 1000, 280),
    );

    const spacing = 420.0;
    final names = _houses.keys.toList();
    final startX = -((names.length - 1) * spacing) / 2;

    for (int i = 0; i < names.length; i++) {
      final name = names[i];
      final size = _houseSizes[name]!;
      final renderH = size.height * _envScale;
      final pos = Offset(startX + i * spacing, 0);

      _world.createEntityWithComponents([
        TransformComponent(
          position: Vector3.fromOffset(pos),
          // RenderableComponent syncs position, angle and scale onto the
          // sprite, so the size is the transform's business.
          scale: Vector3(_envScale, _envScale, 1),
        ),
        RenderableComponent(renderable: _houses[name]!),
        LayerComponent(layer: 8),
      ], name: name);

      _spawnText(
        Offset(pos.dx, pos.dy + renderH / 2 + 20),
        '$name  •  ${size.width.toInt()}x${size.height.toInt()}',
        size: 13,
      );
    }

    _spawnText(
      const Offset(0, -220),
      'artist: $_houseArtist  •  source: $_houseSource',
      color: const Color(0xFF9DD9D2),
    );

    _statusMessage =
        '${names.length} Sprite.fromAsset sprites  |  '
        'scale: ${_envScale.toStringAsFixed(2)}x (TransformComponent.scale)';
  }

  // -- Atlas Regions ---------------------------------------------------------

  List<String> _pageRegions(SpriteAtlas atlas, int page) => [
    for (final name in atlas.regionNames)
      if (atlas.getRegion(name)!.pageIndex == page) name,
  ];

  void _buildAtlasInspectorDemo() {
    final atlas = _char02Atlas!;
    final page = atlas.pages[_inspectorPage];
    final img = page.image!;
    final scale = _inspectorScale;
    final regions = _pageRegions(atlas, _inspectorPage);
    _regionIndex = _regionIndex.clamp(0, regions.length - 1);
    const sheetCenter = Offset(-160, 0);

    _spawnGrid();

    const colors = [
      Color(0xFF00E5FF),
      Color(0xFFFFEA00),
      Color(0xFF69FF47),
      Color(0xFFFF6D00),
    ];

    // The page texture with every region outlined.
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          getBoundsCallback: () => Rect.fromCenter(
            center: sheetCenter,
            width: img.width * scale + 40,
            height: img.height * scale + 40,
          ),
          onRender: (canvas, _) {
            final drawW = img.width * scale;
            final drawH = img.height * scale;
            final drawLeft = sheetCenter.dx - drawW / 2;
            final drawTop = sheetCenter.dy - drawH / 2;

            canvas.drawImageRect(
              img,
              Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
              Rect.fromLTWH(drawLeft, drawTop, drawW, drawH),
              Paint()..filterQuality = FilterQuality.none,
            );

            for (int idx = 0; idx < regions.length; idx++) {
              final region = atlas.getRegion(regions[idx])!;
              final color = colors[idx % colors.length];
              final selected = idx == _regionIndex;
              final rect = Rect.fromLTWH(
                drawLeft + region.frame.left * scale,
                drawTop + region.frame.top * scale,
                region.frame.width * scale,
                region.frame.height * scale,
              );
              canvas.drawRect(
                rect,
                Paint()
                  ..color = color.withValues(alpha: selected ? 0.25 : 0.06),
              );
              canvas.drawRect(
                rect,
                Paint()
                  ..color = selected
                      ? Colors.white
                      : color.withValues(alpha: 0.8)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = selected ? 2.5 : 1.0,
              );
              final tp = TextPainter(
                text: TextSpan(
                  text: '$idx',
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout();
              tp.paint(canvas, Offset(rect.left + 2, rect.top + 1));
            }
          },
        ),
      ),
      LayerComponent(layer: 6),
    ], name: 'inspector');

    // One region of the sheet, as a component.
    _regionPreview = _world.createEntityWithComponents([
      TransformComponent(
        position: Vector3(260, -10, 0),
        scale: Vector3(3, 3, 1),
      ),
      SpriteComponent(
        spritePath: '',
        atlasPath: _kChar02Atlas,
        region: regions[_regionIndex],
        pixelArt: true,
      ),
      LayerComponent(layer: 8),
    ], name: 'region-preview');
    _regionLabel = _spawnText(
      const Offset(260, 110),
      _regionCaption(atlas, regions[_regionIndex]),
      color: const Color(0xFF4DD0E1),
    );

    _statusMessage =
        'page $_inspectorPage "${page.imagePath.split('/').last}": '
        '${img.width}x${img.height}px  |  ${regions.length} of '
        '${atlas.regionCount} regions  |  ${atlas.pages.length} pages';
  }

  String _regionCaption(SpriteAtlas atlas, String name) {
    final r = atlas.getRegion(name)!;
    return 'region "$name"\npage ${r.pageIndex} · '
        '${r.frame.left.toInt()},${r.frame.top.toInt()} '
        '${r.frame.width.toInt()}x${r.frame.height.toInt()}';
  }

  void _selectRegion(int index) {
    final atlas = _char02Atlas;
    if (atlas == null) return;
    final regions = _pageRegions(atlas, _inspectorPage);
    final name = regions[index.clamp(0, regions.length - 1)];
    setState(() => _regionIndex = index);
    // SpriteLoadSystem notices the new region and swaps the frame.
    _regionPreview?.getComponent<SpriteComponent>()?.region = name;
    final label = _regionLabel?.getComponent<RenderableComponent>()?.renderable;
    if (label is TextRenderable) label.text = _regionCaption(atlas, name);
  }

  // -- Multi-Page ------------------------------------------------------------

  void _buildCharactersDemo() {
    final atlas = _char03Atlas!;
    // The first region of each page, in page order.
    final firstRegions = <String>[];
    final seenPages = <int>{};
    for (final name in atlas.regionNames) {
      if (seenPages.add(atlas.getRegion(name)!.pageIndex)) {
        firstRegions.add(name);
      }
    }

    _spawnGrid();

    const cols = 4;
    const sx = 180.0;
    const sy = 170.0;
    const rows = 2;
    final startX = -(cols - 1) * sx / 2;
    final startY = -(rows - 1) * sy / 2 - 20;

    for (int i = 0; i < firstRegions.length && i < cols * rows; i++) {
      final regionName = firstRegions[i];
      final region = atlas.getRegion(regionName)!;
      final col = i % cols;
      final row = i ~/ cols;
      final pos = Offset(startX + col * sx, startY + row * sy);

      _world.createEntityWithComponents([
        TransformComponent(
          position: Vector3.fromOffset(pos),
          scale: Vector3(_charScale, _charScale, 1),
        ),
        SpriteComponent(
          spritePath: '',
          atlasPath: _kChar03Atlas,
          region: regionName,
          pixelArt: true,
        ),
        LayerComponent(layer: 8),
      ], name: 'char-$regionName');

      _spawnText(
        Offset(pos.dx, pos.dy + region.sourceSize.height * _charScale / 2 + 6),
        '$regionName · page ${region.pageIndex}',
        color: const Color(0xFFFFB74D),
        size: 11,
      );
    }

    _statusMessage =
        'char03 atlas: ${atlas.pages.length} pages · '
        '${atlas.regionCount} regions  |  first region of each page';
  }

  // -- Batching & ySort ------------------------------------------------------

  static const _kCrowdBounds = Rect.fromLTRB(-420, -170, 420, 170);

  void _buildBatchingDemo() {
    final atlas = _char02Atlas!;
    // Every walk frame is on page 1: one image, so one batch.
    final frames = _pageRegions(atlas, 1);

    _spawnGrid(color: const Color(0xFF2A2140));

    for (var i = 0; i < _crowdCount; i++) {
      final pos = Offset(
        _kCrowdBounds.left + _random.nextDouble() * _kCrowdBounds.width,
        _kCrowdBounds.top + _random.nextDouble() * _kCrowdBounds.height,
      );
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 30 + _random.nextDouble() * 50;
      final sprite = atlas.createSprite(frames[i % frames.length])
        ..ySort = _ySort
        ..filterQuality = FilterQuality.none;
      _crowd.add(
        _world.createEntityWithComponents([
          TransformComponent(
            position: Vector3.fromOffset(pos),
            scale: Vector3(1.5, 1.5, 1),
          ),
          VelocityComponent(
            velocity: Vector3(
              math.cos(angle) * speed,
              math.sin(angle) * speed,
              0,
            ),
          ),
          RenderableComponent(renderable: sprite),
          _BounceComponent(bounds: _kCrowdBounds, mirror: _mirror),
        ], name: 'walker-$i'),
      );
    }
    _statusMessage =
        '$_crowdCount sprites from page 1 of character02.atlas.json  |  '
        'ySort ${_ySort ? 'on' : 'off'} · mirroring ${_mirror ? 'on' : 'off'}';
  }

  void _setYSort(bool on) {
    setState(() => _ySort = on);
    for (final e in _crowd) {
      e.getComponent<RenderableComponent>()?.renderable.ySort = on;
    }
  }

  void _setMirror(bool on) {
    setState(() => _mirror = on);
    for (final e in _crowd) {
      e.getComponent<_BounceComponent>()?.mirror = on;
    }
  }

  // -- Layers & Tint ---------------------------------------------------------

  static const _kLayerSpots = [
    Offset(-150, -50),
    Offset(0, 10),
    Offset(150, 70),
  ];

  void _buildLayersDemo() {
    _spawnGrid(color: const Color(0xFF40213A));
    final names = _houses.keys.toList();
    _topZ = names.length - 1;
    for (var i = 0; i < names.length && i < _kLayerSpots.length; i++) {
      final house = _world.createEntityWithComponents([
        TransformComponent(
          position: Vector3.fromOffset(_kLayerSpots[i]),
          scale: Vector3(0.6, 0.6, 1),
        ),
        // A whole image as a component: SpriteLoadSystem loads and shows it.
        SpriteComponent(
          spritePath: '$_kHouseRoot/${names[i]}.png',
          pixelArt: true,
          tint: _currentTint,
        ),
        LayerComponent(layer: 0, zOrder: i),
      ], name: names[i]);
      _layerHouses.add(house);
      _layerLabels.add(
        _spawnText(
          _kLayerSpots[i] + const Offset(0, -95),
          '',
          color: const Color(0xFFF06292),
          size: 11,
        ),
      );
    }
    _syncLayerLabels();
    _statusMessage =
        '${names.length} SpriteComponent(spritePath:) houses · '
        'LayerComponent(layer: 0, zOrder: n)';
  }

  Color? get _currentTint {
    final color = _tintColor;
    if (color == null && _tintAlpha >= 1.0) return null;
    // White multiplies nothing: a white tint with alpha only fades.
    return (color ?? Colors.white).withValues(alpha: _tintAlpha);
  }

  void _applyTint() {
    final tint = _currentTint;
    for (final house in _layerHouses) {
      house.getComponent<SpriteComponent>()?.tint = tint;
    }
  }

  void _bringToFront(int index) {
    if (index >= _layerHouses.length) return;
    final layer = _layerHouses[index].getComponent<LayerComponent>();
    if (layer == null) return;
    // RenderSystem reads the keys every frame: no rebuild needed.
    layer.zOrder = ++_topZ;
    _syncLayerLabels();
  }

  void _syncLayerLabels() {
    if (_demo != _SpriteDemo.layers) return;
    for (var i = 0; i < _layerHouses.length && i < _layerLabels.length; i++) {
      final layer = _layerHouses[i].getComponent<LayerComponent>();
      final text = _layerLabels[i]
          .getComponent<RenderableComponent>()
          ?.renderable;
      if (layer == null || text is! TextRenderable) continue;
      text.text =
          '${_layerHouses[i].name}  ·  layer ${layer.layer}, zOrder ${layer.zOrder}';
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  String get _statsLine {
    if (_loading) return 'loading...';
    if (_loadError != null) return 'could not load the sprites';
    final render = _world.getSystem<RenderSystem>()?.stats;
    final draws = render == null
        ? ''
        : '  |  draw calls ${render['drawCalls']} · '
              'drawn ${render['renderedObjects']} · '
              'batched ${render['batchedSprites']}';
    final c2 = _char02Atlas;
    final c3 = _char03Atlas;
    return 'houses ${_houses.length} · char02 ${c2?.regionCount ?? 0} regions / '
        '${c2?.pages.length ?? 0} pages · char03 ${c3?.regionCount ?? 0} '
        'regions / ${c3?.pages.length ?? 0} pages$draws';
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
              const Flexible(
                child: Text(
                  'Sprite  .  SpriteComponent  .  SpriteAtlas  .  LayerComponent',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF4DD0E1), fontSize: 10),
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
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              'Loading sprites and atlases...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load the sprites:\n$_loadError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFF7043), fontSize: 12),
          ),
        ),
      );
    }
    return CameraZoomControls(
      camera: _engine.cameraSystem.mainCamera,
      child: GameWidget(engine: _engine, showFPS: true, showDebug: true),
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
              itemCount: _SpriteDemo.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final d = _SpriteDemo.values[i];
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
                  onSelected: _loading ? null : (_) => _buildDemo(d),
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
    return switch (_demo) {
      _SpriteDemo.environment => _buildEnvControls(),
      _SpriteDemo.atlasInspector => _buildInspectorControls(),
      _SpriteDemo.characters => _buildCharacterControls(),
      _SpriteDemo.batching => _buildBatchingControls(),
      _SpriteDemo.layers => _buildLayersControls(),
    };
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12));

  Widget _buildEnvControls() {
    return Row(
      children: [
        _label('Scale:'),
        Expanded(
          child: Slider(
            value: _envScale,
            min: 0.25,
            max: 1.0,
            divisions: 15,
            label: '${_envScale.toStringAsFixed(2)}x',
            onChanged: (v) => setState(() => _envScale = v),
            onChangeEnd: (_) => _buildDemo(_demo),
          ),
        ),
        _actionButton(
          'Respawn',
          const Color(0xFF81C784),
          () => _buildDemo(_demo),
        ),
        const SizedBox(width: 12),
        Text(
          '${_houses.length} sprites  •  Sprite.fromAsset',
          style: const TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildInspectorControls() {
    final atlas = _char02Atlas;
    final count = atlas == null
        ? 1
        : _pageRegions(atlas, _inspectorPage).length;
    const accent = Color(0xFF4DD0E1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _label('Page:'),
            const SizedBox(width: 8),
            for (final (page, text) in const [(0, '0 · idle'), (1, '1 · walk')])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _actionButton(
                  text,
                  accent,
                  _inspectorPage == page
                      ? null
                      : () {
                          setState(() {
                            _inspectorPage = page;
                            _regionIndex = 0;
                            _inspectorScale = page == 0 ? 1.4 : 0.9;
                          });
                          _buildDemo(_demo);
                        },
                ),
              ),
            const SizedBox(width: 8),
            _label('Zoom:'),
            Expanded(
              child: Slider(
                value: _inspectorScale,
                min: 0.5,
                max: 4.0,
                divisions: 35,
                label: '${_inspectorScale.toStringAsFixed(1)}x',
                onChanged: (v) => setState(() => _inspectorScale = v),
                onChangeEnd: (_) => _buildDemo(_demo),
              ),
            ),
          ],
        ),
        Row(
          children: [
            _label('Region:'),
            Expanded(
              child: Slider(
                value: _regionIndex.clamp(0, count - 1).toDouble(),
                min: 0,
                max: math.max(1, count - 1).toDouble(),
                divisions: math.max(1, count - 1),
                label: '$_regionIndex',
                onChanged: (v) => _selectRegion(v.round()),
              ),
            ),
            Text(
              'SpriteComponent.region  •  $count regions on this page',
              style: const TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCharacterControls() {
    return Row(
      children: [
        _label('Scale:'),
        Expanded(
          child: Slider(
            value: _charScale,
            min: 1.0,
            max: 4.0,
            divisions: 12,
            label: '${_charScale.toStringAsFixed(1)}x',
            onChanged: (v) => setState(() => _charScale = v),
            onChangeEnd: (_) => _buildDemo(_demo),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_char03Atlas?.pages.length ?? 0} pages  •  '
          '${_char03Atlas?.regionCount ?? 0} regions',
          style: const TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildBatchingControls() {
    const accent = Color(0xFF9575CD);
    return Row(
      children: [
        _label('Sprites:'),
        Expanded(
          child: Slider(
            value: _crowdCount.toDouble(),
            min: 10,
            max: 400,
            divisions: 39,
            label: '$_crowdCount',
            onChanged: (v) => setState(() => _crowdCount = v.round()),
            onChangeEnd: (_) => _buildDemo(_demo),
          ),
        ),
        _actionButton(
          _ySort ? 'ySort: on' : 'ySort: off',
          accent,
          () => _setYSort(!_ySort),
        ),
        const SizedBox(width: 6),
        _actionButton(
          _mirror ? 'Mirror: on' : 'Mirror: off',
          const Color(0xFFFF8A65),
          () => _setMirror(!_mirror),
        ),
      ],
    );
  }

  Widget _buildLayersControls() {
    const accent = Color(0xFFF06292);
    final names = _houses.keys.toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _label('To front:'),
            for (var i = 0; i < names.length && i < _kLayerSpots.length; i++)
              _actionButton(names[i], accent, () => _bringToFront(i)),
            const SizedBox(width: 8),
            _label('Tint:'),
            for (final (color, text) in const [
              (null, 'none'),
              (Color(0xFFFFB74D), 'warm'),
              (Color(0xFF4DD0E1), 'cyan'),
            ])
              _actionButton(
                text,
                _tintColor == color ? accent : const Color(0xFF2A4060),
                () {
                  setState(() => _tintColor = color);
                  _applyTint();
                },
              ),
          ],
        ),
        Row(
          children: [
            _label('Tint alpha:'),
            Expanded(
              child: Slider(
                value: _tintAlpha,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                label: _tintAlpha.toStringAsFixed(2),
                onChanged: (v) {
                  setState(() => _tintAlpha = v);
                  _applyTint();
                },
              ),
            ),
            const Text(
              'alpha < 1 fades the sprite',
              style: TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
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
                  'just_game_engine  .  Sprite API',
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
