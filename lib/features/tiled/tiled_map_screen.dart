import 'dart:async';
import 'dart:convert' show jsonEncode;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/widgets.dart';
import 'package:just_tiled/just_tiled.dart' as tiled;

import '../../core/engine/demo_engine.dart';

/// A Tiled map with four layers (Ground, Decor that collides, an object
/// layer and a `foreground` Bridge) and a tileset with collision shapes.
const String _outpostPath = 'assets/maps/desert_outpost.tmx';

/// The original single-layer desert map; its tileset has a corner Wang set.
const String _desertPath = 'assets/maps/desert.tmx';

const String _characterRoot = 'assets/sprites/characters/character03';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  tiled,
  collision,
  edit,
  objects,
  code;

  String get label => switch (this) {
    tiled => 'Tiled .tmx',
    collision => 'Map Collision',
    edit => 'Runtime Edits',
    objects => 'Tiled Objects',
    code => 'Built in Code',
  };

  IconData get icon => switch (this) {
    tiled => Icons.map_outlined,
    collision => Icons.sports_baseball_outlined,
    edit => Icons.brush_outlined,
    objects => Icons.place_outlined,
    code => Icons.hexagon_outlined,
  };

  Color get accentColor => switch (this) {
    tiled => const Color(0xFF26C6DA),
    collision => const Color(0xFF9CCC65),
    edit => const Color(0xFFFFCA28),
    objects => const Color(0xFFFF7043),
    code => const Color(0xFFAB47BC),
  };

  String get description => switch (this) {
    tiled =>
      'desert_outpost.tmx read directly: one entity with '
          'LevelMapComponent(mapPath:) holds every layer. LevelMapSystem draws '
          'each layer among the sprites by its own (layer, zOrder) — the '
          'travellers walk on the Ground and under the Bridge, a Tiled layer '
          'with a `foreground` property. Toggle layers below.',
    collision =>
      'An inline map painted with the built-in basicShapes tileset. '
          'MapCollisionSystem turns every `collides` layer into static '
          'RigidBody2D + Collider2D entities, merging runs of tiles. Tap to '
          'drop balls or toggle blocks — the bodies follow within the frame.',
    edit =>
      'desert.tmx edited while the game runs. LevelMaps.primary(world) gives '
          'a LevelMapHandle: setTerrain paints with the tileset\'s Wang set, '
          'setTile stamps and erases, setCellsHidden hides cells. Edits live '
          'in the runtime — the .tmx and its loaded copy are untouched.',
    objects =>
      'TiledInterop.importMap converts the same .tmx and returns its object '
          'layers as TiledImport.objects. Each object becomes a child entity '
          'of the map on its layer (LayerComponent.mapLayer), so it draws and '
          'hides with that layer. Labels are TextRenderables.',
    code =>
      'A LevelMapData built in code with the engine\'s built-in basicShapes '
          'tileset — no files at all — in each of Tiled\'s four orientations. '
          'MapGeometry outlines every cell and finds the one under the pointer; '
          'tap a cell to place or remove a tile.',
  };

  String get codeSnippet => switch (this) {
    tiled =>
      'registerDefaultSystems(world, engine, include: {\n'
          '  DefaultSystem.rendering,\n'
          '  DefaultSystem.levelMaps,\n'
          '  DefaultSystem.mapCollision,\n'
          '  DefaultSystem.physics,\n'
          '});\n\n'
          '// One entity holds the whole Tiled map.\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(),\n'
          "  LevelMapComponent(mapPath: 'assets/maps/desert_outpost.tmx'),\n"
          '], name: LevelMaps.primaryName);\n\n'
          '// Map + tilesets loaded before the first frame.\n'
          'final failures = await LevelMaps.preload(world);\n\n'
          '// Layers sort among sprites by (layer, zOrder); a Tiled\n'
          '// layer with a `foreground` property draws in front.\n'
          'final map = LevelMaps.primary(world)!;\n'
          "final bridge = map.layer('Bridge')!;\n"
          'bridge.visible = !bridge.visible;\n'
          'map.map.touch();',
    collision =>
      'final level = LevelMapData(); // 32 × 32, orthogonal\n'
          'final shapes = level.addTileset(BuiltInTilesets.basicShapes);\n'
          "final ground = level.addLayer(name: 'Level')..collides = true;\n"
          'for (var x = 0; x < 26; x++) {\n'
          '  ground.cells.setCell(x, 15, TileCell.make(shapes, 0)); // block\n'
          '}\n'
          'ground.cells.setCell(4, 8, TileCell.make(shapes, 9)); // 45° slope\n'
          'ground.cells.setCell(10, 11, TileCell.make(shapes, 5)); // one-way\n\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(),\n'
          '  LevelMapComponent(inline: level),\n'
          ']);\n'
          '// MapCollisionSystem: merged static bodies, each an entity\n'
          '// with RigidBody2D + Collider2D + MapBodyComponent.\n\n'
          'world.createEntityWithComponents([\n'
          '  TransformComponent(position: Vector3(320, 0, 0)),\n'
          '  RigidBody2D(restitution: 0.45),\n'
          '  Collider2D(shape: ColliderShape2D.circle, radius: 8),\n'
          '  CircleComponent(radius: 8),\n'
          ']);\n\n'
          'world.getSystem<PhysicsSystem>()!.drawsOutlines = true;',
    edit =>
      'final map = LevelMaps.primary(world)!;\n'
          "final ground = map.layer('Ground')!;\n"
          'final cell = map.cellAt(ground, worldPoint);\n\n'
          "// Terrain brush: the tileset's Wang set picks the tiles.\n"
          'map.setTerrain(ground, [WangTarget.cell(cell)], 2); // Brick\n'
          '// Single tiles (slot 0, tile 30: a cactus) and holes:\n'
          'map.setTile(ground, cell, TileCell.make(0, 30));\n'
          'map.setTile(ground, cell, TileCell.empty);\n'
          '// Not drawn, but still there:\n'
          'map.setCellsHidden(ground, [cell], true);\n\n'
          'world.events.on<TileChangedEvent>((e) => print(e.cells));\n\n'
          "// The game's own changes; the map file is untouched.\n"
          'LevelMaps.release(map.component); // back to the file',
    objects =>
      "// import 'package:just_tiled/just_tiled.dart' as tiled;\n"
          'final text = await world.context.tiles.readText(path);\n'
          'final tmx = await tiled.TileMapParser.parse(text,\n'
          "    tsxProvider: const tiled.DefaultTsxProvider(basePath: 'assets/maps'));\n"
          'final imported = TiledInterop.importMap(\n'
          '  tmx,\n'
          "  tilesetPath: (i, _) => '\$path#\$i',\n"
          "  imagePath: (ts) => 'assets/maps/\${ts.imageSource}',\n"
          ');\n\n'
          'for (final o in imported.objects) {\n'
          '  final at = Vector3(o.position.dx, o.position.dy, 0);\n'
          '  world.createEntityWithComponents([\n'
          '    TransformComponent(position: at),\n'
          '    ParentComponent(parentId: mapEntity.id, localPosition: at),\n'
          '    LayerComponent(mapLayer: o.mapLayerId), // drawn with it\n'
          '    RenderableComponent(\n'
          '      renderable: TextRenderable(text: o.object.name),\n'
          '    ),\n'
          '  ], name: o.object.name);\n'
          '}',
    code =>
      'final map = LevelMapData(\n'
          '  orientation: MapOrientation.hexagonal,\n'
          '  tileWidth: 32,\n'
          '  tileHeight: 32,\n'
          '  hexSideLength: 16,\n'
          '  staggerAxis: TileStaggerAxis.y,\n'
          ');\n'
          'final shapes = map.addTileset(BuiltInTilesets.basicShapes);\n'
          "final floor = map.addLayer(name: 'Floor')..tint = 0xFF2E5266;\n"
          'for (var y = 0; y < 9; y++) {\n'
          '  for (var x = 0; x < 11; x++) {\n'
          '    floor.cells.setCell(x, y, TileCell.make(shapes, 20));\n'
          '  }\n'
          '}\n'
          '// Swap the map: LevelMapSystem builds a new runtime.\n'
          'mapEntity.getComponent<LevelMapComponent>()!.inline = map;\n\n'
          'final hexagon = MapGeometry.of(map).cellPolygon(3, 2);\n'
          'final saved = map.toJson(); // a .map.json document',
  };
}

/// What a tap does in the collision demo.
enum _TapAction { ball, block }

/// The brush of the runtime-edit demo; [pan] drags the camera instead.
enum _Tool { pan, terrain, stamp, erase, hide }

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class TiledMapScreen extends StatefulWidget {
  const TiledMapScreen({super.key});

  @override
  State<TiledMapScreen> createState() => _TiledMapScreenState();
}

class _TiledMapScreenState extends State<TiledMapScreen> {
  // ── Engine ───────────────────────────────────────────────────────────────
  late final Engine _engine = demoEngine;
  late final World _world = _engine.world;
  Camera get _camera => _engine.cameraSystem.mainCamera;

  /// Rebuilds the HUD; the engine runs itself.
  Timer? _hudTimer;

  // ── State ────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.tiled;
  bool _loading = true;
  String _status = 'Initializing…';

  /// Bumped by every demo switch: a build still loading when it changes
  /// leaves the world alone.
  int _build = 0;

  Size _canvasSize = Size.zero;
  final math.Random _rng = math.Random(11);

  /// The demo's map entity (`LevelMaps.primaryName`).
  Entity? _mapEntity;

  /// Summary of the loaded map, for the HUD.
  String _mapSummary = '';

  /// What the last tap or brush stroke found.
  String _lastCell = '';

  // ── Layer visibility (restored: the loaded map is shared) ───────────────
  LevelMapData? _visibilityDoc;
  Map<int, bool> _savedVisibility = const {};

  // ── Tiled + objects ─────────────────────────────────────────────────────
  TiledImport? _import;
  final List<(TiledObjectRecord, Entity)> _objects = [];
  final List<ui.Image> _ownedImages = [];
  int _travellers = 0;
  bool _showOutlines = false;

  // ── Collision ───────────────────────────────────────────────────────────
  static const int _pitCols = 26;
  static const int _pitRows = 16;
  _TapAction _tapAction = _TapAction.ball;

  // ── Runtime edits ───────────────────────────────────────────────────────
  _Tool _tool = _Tool.terrain;
  int _terrain = 2; // Wang colour 2 of desert.tsx: Brick
  EventSubscription? _tileEvents;
  int _tileEventCount = 0;
  int _tilesChanged = 0;
  TileCoord? _lastPainted;
  bool? _hideStroke;

  // ── Built in code ───────────────────────────────────────────────────────
  MapOrientation _orientation = MapOrientation.isometric;
  TileRange _showcaseRange = const TileRange(0, 0, 0, 0);
  TileCoord? _pickedCell;
  int _savedBytes = 0;
  final Paint _gridPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0x33FFFFFF);
  final Paint _pickFill = Paint()
    ..color = _Demo.code.accentColor.withValues(alpha: 0.35);
  final Paint _pickStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = _Demo.code.accentColor;

  // ── Pointer ─────────────────────────────────────────────────────────────
  final Map<int, Offset> _pointers = {};
  Offset? _tapStart;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _hudTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _switchTo(_demo);
    });
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _build++;
    _clearWorld(const {});
    super.dispose();
  }

  bool _isCurrent(int build) => mounted && build == _build;

  /// Takes down what the last demo added outside the world, then gives the
  /// next one a clean world with the standard systems in [include].
  void _clearWorld(Set<DefaultSystem> include) {
    _tileEvents?.cancel();
    _tileEvents = null;
    _restoreVisibility();
    DemoEngine.reset(_engine, include: include);
    // The travellers' sprites are gone with the world: their images can go.
    for (final image in _ownedImages) {
      image.dispose();
    }
    _ownedImages.clear();
    _mapEntity = null;
    _import = null;
    _objects.clear();
    _travellers = 0;
    _mapSummary = '';
    _lastCell = '';
    _pickedCell = null;
  }

  Future<void> _switchTo(_Demo demo) async {
    final build = ++_build;
    setState(() {
      _demo = demo;
      _loading = true;
      _status = 'Loading ${demo.label}…';
    });
    try {
      switch (demo) {
        case _Demo.tiled:
          await _buildTiled(build);
        case _Demo.collision:
          await _buildCollision(build);
        case _Demo.edit:
          await _buildEdit(build);
        case _Demo.objects:
          await _buildObjects(build);
        case _Demo.code:
          await _buildCode(build);
      }
      if (_isCurrent(build)) setState(() => _status = '');
    } catch (error) {
      if (_isCurrent(build)) setState(() => _status = 'Error: $error');
    } finally {
      if (_isCurrent(build)) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Adds the level's map entity, loading the map from [path] or keeping
  /// [inline] in the scene.
  Entity _addMap({String path = '', LevelMapData? inline}) {
    return _mapEntity = _world.createEntityWithComponents([
      TransformComponent(),
      LevelMapComponent(mapPath: path, inline: inline),
    ], name: LevelMaps.primaryName);
  }

  /// Loads every map in the world; throws the first failure.
  Future<void> _preload() async {
    final failures = await LevelMaps.preload(_world);
    if (failures.isNotEmpty) throw failures.first.error;
  }

  /// Reads [path] again with just_tiled and converts it, objects included:
  /// `TileAssets` keeps only the map, not its objects.
  Future<TiledImport> _importTiled(String path) async {
    final dir = TileAssets.directoryOf(path);
    final text = await _world.context.tiles.readText(path);
    final tmx = await tiled.TileMapParser.parse(
      text,
      tsxProvider: tiled.DefaultTsxProvider(basePath: dir),
    );
    return TiledInterop.importMap(
      tmx,
      // The names TileAssets gives a .tmx's tilesets, so the layers and
      // slots match the map LevelMapComponent loaded.
      tilesetPath: (i, _) => '$path#$i',
      imagePath: (ts) => TileAssets.join(dir, ts.imageSource ?? ''),
    );
  }

  /// The cells any layer of [map] uses.
  TileRange? _usedRange(LevelMapHandle map) {
    Rect? used;
    for (final layer in map.map.layers) {
      final bounds = map.runtime.cellsOf(layer).usedBounds;
      if (bounds == null) continue;
      used = used == null ? bounds : used.expandToInclude(bounds);
    }
    if (used == null) return null;
    return TileRange(
      used.left.toInt(),
      used.top.toInt(),
      used.right.toInt(),
      used.bottom.toInt(),
    );
  }

  /// [map]'s used area in the world.
  Rect _worldBounds(LevelMapHandle map) {
    final range = _usedRange(map);
    if (range == null) return Rect.zero;
    return map.geometry.boundsOf(range).shift(map.origin);
  }

  /// Points the camera at [area], zoomed to fit the canvas.
  void _frame(Rect area, {double padding = 24}) {
    if (area.isEmpty) return;
    final size = _canvasSize.isEmpty ? const Size(800, 480) : _canvasSize;
    final zoom = math.min(
      (size.width - padding * 2) / area.width,
      (size.height - padding * 2) / area.height,
    );
    _camera
      ..setPosition(area.center)
      ..setZoom(zoom.clamp(0.25, 3.0));
  }

  void _rememberVisibility(LevelMapHandle map) {
    _restoreVisibility();
    _visibilityDoc = map.map;
    _savedVisibility = {for (final l in map.map.layers) l.id: l.visible};
  }

  /// Puts the loaded map's layers back as they were: the document is the
  /// one `TileAssets` shares with every later load of the file.
  void _restoreVisibility() {
    final doc = _visibilityDoc;
    if (doc == null) return;
    var changed = false;
    for (final layer in doc.layers) {
      final was = _savedVisibility[layer.id];
      if (was != null && layer.visible != was) {
        layer.visible = was;
        changed = true;
      }
    }
    if (changed) doc.touch();
    _visibilityDoc = null;
    _savedVisibility = const {};
  }

  void _toggleLayer(MapLayerData layer) {
    final map = LevelMaps.primary(_world);
    if (map == null) return;
    setState(() => layer.visible = !layer.visible);
    map.map.touch();
  }

  void _setOutlines(bool on) {
    setState(() => _showOutlines = on);
    _world.getSystem<PhysicsSystem>()?.drawsOutlines = on;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Tiled .tmx
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _buildTiled(int build) async {
    _clearWorld(const {
      DefaultSystem.rendering,
      DefaultSystem.levelMaps,
      DefaultSystem.mapCollision,
      DefaultSystem.physics,
    });
    _world
      ..addSystem(_MapOutlineSystem(() => _showOutlines))
      ..addSystem(_TravellerSystem());
    _world.getSystem<PhysicsSystem>()?.drawsOutlines = _showOutlines;
    _addMap(path: _outpostPath);

    await _preload();
    if (!_isCurrent(build)) return;
    final map = LevelMaps.primary(_world)!;
    _rememberVisibility(map);
    _describeMap(map, 'desert_outpost.tmx');
    _frame(_worldBounds(map));

    // The caravan follows the route drawn in the map's object layer.
    final imported = await _importTiled(_outpostPath);
    final sheets = await _loadTravellerSheets();
    if (!_isCurrent(build)) {
      for (final image in sheets.values) {
        image.dispose();
      }
      return;
    }
    _ownedImages.addAll(sheets.values);
    _import = imported;
    final route = _routeOf(imported, map);
    if (route.length < 2) return;
    const count = 3;
    final length = _Traveller.lengthOf(route);
    for (var i = 0; i < count; i++) {
      _world.createEntityWithComponents([
        TransformComponent(position: Vector3.fromOffset(route.first)),
        RenderableComponent(
          renderable: Sprite(
            image: sheets['right'],
            sourceRect: const Rect.fromLTWH(0, 0, 96, 80),
            renderSize: const Size(96, 80),
          ),
        ),
        _Traveller(
          route: route,
          sheets: sheets,
          distance: length * i / count,
          speed: 70 + 15.0 * i,
        ),
      ], name: 'Traveller ${i + 1}');
    }
    _travellers = count;
  }

  /// The polyline of the first `route` object, in the world.
  List<Offset> _routeOf(TiledImport imported, LevelMapHandle map) {
    for (final record in imported.objects) {
      final o = record.object;
      final points = o.polyline ?? o.polygon;
      if (o.type != 'route' || points == null) continue;
      final at = map.origin + record.position;
      return [
        for (final p in points) at + p,
        if (o.polygon != null) at + points.first,
      ];
    }
    return const [];
  }

  Future<Map<String, ui.Image>> _loadTravellerSheets() async {
    final sheets = <String, ui.Image>{};
    for (final dir in const ['up', 'down', 'left', 'right']) {
      sheets[dir] = await Sprite.loadImageFromAsset(
        '$_characterRoot/character_03_run_$dir.png',
        assets: _engine.assets,
      );
    }
    return sheets;
  }

  void _describeMap(LevelMapHandle map, String file) {
    final range = _usedRange(map);
    final size = range == null ? '?' : '${range.width}×${range.height}';
    final tilesets = map.map.tilesets.length;
    _mapSummary =
        '$file · $size tiles of ${map.map.tileWidth}×${map.map.tileHeight}'
        ' · ${map.map.layers.length} layers · $tilesets tileset'
        '${tilesets == 1 ? '' : 's'}';
  }

  /// What every layer holds at [world].
  void _inspectAt(Offset world) {
    final map = LevelMaps.primary(_world);
    if (map == null) return;
    final parts = <String>[];
    TileCoord? cell;
    for (final layer in map.map.layers) {
      cell ??= map.cellAt(layer, world);
      final info = map.tileAtPoint(layer, world);
      if (info == null) continue;
      final cls = info.className.isEmpty ? '' : ' (${info.className})';
      parts.add('${layer.name} #${info.localId}$cls');
    }
    setState(() {
      _lastCell = cell == null
          ? ''
          : 'cell (${cell.x}, ${cell.y}): '
                '${parts.isEmpty ? 'empty' : parts.join(' · ')}';
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: map collision
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _buildCollision(int build) async {
    _clearWorld(const {
      DefaultSystem.rendering,
      DefaultSystem.physics,
      DefaultSystem.levelMaps,
      DefaultSystem.mapCollision,
    });
    _world
      ..addSystem(_MapOutlineSystem(() => _showOutlines))
      ..addSystem(_BallCleanupSystem(killY: _pitRows * 32.0 + 400));
    _world.getSystem<PhysicsSystem>()?.drawsOutlines = _showOutlines;
    _addMap(inline: _buildBallPit());

    await _preload();
    if (!_isCurrent(build)) return;
    final map = LevelMaps.primary(_world)!;
    _frame(_worldBounds(map));
    _dropBalls(10);
  }

  /// A side-on level of the built-in shapes: every tile collides as it
  /// looks.
  static LevelMapData _buildBallPit() {
    final map = LevelMapData(); // 32 × 32 pixel cells, orthogonal
    final shapes = map.addTileset(BuiltInTilesets.basicShapes);
    final level = map.addLayer(name: 'Level')..collides = true;
    void put(int x, int y, int tile) =>
        level.cells.setCell(x, y, TileCell.make(shapes, tile));

    const floor = _pitRows - 1;
    // Floor and walls: full blocks (tile 0), merged into a few bodies.
    for (var x = 0; x < _pitCols; x++) {
      put(x, floor, 0);
    }
    for (var y = 3; y < floor; y++) {
      put(0, y, 0);
      put(_pitCols - 1, y, 0);
    }
    // Funnels: 45° slopes (tiles 9 and 8) running down to the middle.
    for (var i = 0; i < 4; i++) {
      put(1 + i, 5 + i, 9);
      put(_pitCols - 2 - i, 5 + i, 8);
    }
    // Round bumpers (tile 20) and a shelf of half blocks (tile 1).
    put(7, 4, 20);
    put(12, 3, 20);
    put(18, 4, 20);
    for (var x = 11; x < 15; x++) {
      put(x, 7, 1);
    }
    // One-way planks (tile 5): solid only from above.
    for (var x = 8; x < 18; x++) {
      put(x, 11, 5);
    }
    // 22.5° ramps into the corners (tiles 14/15 and 12/13), floor spikes.
    put(1, floor - 1, 14);
    put(2, floor - 1, 15);
    put(_pitCols - 3, floor - 1, 12);
    put(_pitCols - 2, floor - 1, 13);
    put(12, floor - 1, 21);
    put(13, floor - 1, 21);
    return map;
  }

  static const List<Color> _ballColors = [
    Color(0xFFF5746F),
    Color(0xFF26C6DA),
    Color(0xFFFFCA28),
    Color(0xFF9CCC65),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
  ];

  int get _ballCount => _world.query(const [_Ball]).length;

  void _dropBalls(int count) {
    for (var i = 0; i < count; i++) {
      _spawnBall(
        Offset(
          (3 + _rng.nextDouble() * (_pitCols - 6)) * 32,
          24 + _rng.nextDouble() * 48,
        ),
      );
    }
  }

  void _spawnBall(Offset at) {
    if (_ballCount >= 160) return;
    final radius = 6 + _rng.nextDouble() * 7;
    final color = _ballColors[_rng.nextInt(_ballColors.length)];
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3(at.dx, at.dy, 0)),
      RigidBody2D(restitution: 0.45, friction: 0.3),
      Collider2D(shape: ColliderShape2D.circle, radius: radius),
      CircleComponent(
        radius: radius,
        fillStyle: ShapePaintStyle(color: color),
        strokeStyle: const ShapePaintStyle(color: Color(0x66FFFFFF)),
      ),
      // In front of the map's layer, which shares the default (0, 0).
      LayerComponent(zOrder: 10),
      _Ball(),
    ], name: 'Ball');
  }

  void _clearBalls() {
    for (final ball in _world.query(const [_Ball]).toList()) {
      _world.destroyEntity(ball);
    }
  }

  void _toggleBlock(Offset world) {
    final map = LevelMaps.primary(_world);
    final level = map?.layer('Level');
    if (map == null || level == null) return;
    final cell = map.cellAt(level, world);
    final filled = !TileCell.isEmpty(map.rawAt(level, cell));
    map.setTile(level, cell, filled ? TileCell.empty : TileCell.make(0, 0));
    _lastCell =
        '${filled ? 'removed' : 'placed'} a block at (${cell.x}, ${cell.y})';
  }

  void _rebuildPit() {
    _mapEntity?.getComponent<LevelMapComponent>()?.inline = _buildBallPit();
    _clearBalls();
    _dropBalls(10);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: runtime edits
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _buildEdit(int build) async {
    _clearWorld(const {DefaultSystem.rendering, DefaultSystem.levelMaps});
    _addMap(path: _desertPath);
    _tileEventCount = 0;
    _tilesChanged = 0;
    _tileEvents = _world.events.on<TileChangedEvent>((event) {
      _tileEventCount++;
      _tilesChanged += event.cells.length;
    });

    await _preload();
    if (!_isCurrent(build)) return;
    final map = LevelMaps.primary(_world)!;
    _describeMap(map, 'desert.tmx');
    _frame(_worldBounds(map), padding: 8);
  }

  /// The terrains of the map's first tileset, from its Wang set.
  List<WangColorData> get _terrains {
    final ts = LevelMaps.primary(_world)?.runtime.tilesetAt(0);
    if (ts == null || ts.wangSets.isEmpty) return const [];
    return ts.wangSets.first.colors;
  }

  void _paintAt(Offset screen) {
    if (_tool == _Tool.pan) return;
    final map = LevelMaps.primary(_world);
    final ground = map?.layer('Ground');
    if (map == null || ground == null) return;
    final cell = map.cellAt(ground, _camera.screenToWorld(screen));
    if (cell == _lastPainted) return;
    _lastPainted = cell;

    switch (_tool) {
      case _Tool.pan:
        return;
      case _Tool.terrain:
        map.setTerrain(ground, [
          WangTarget.cell(map.geometry.toLattice(cell)),
        ], _terrain);
      case _Tool.stamp:
        map.setTile(ground, cell, TileCell.make(0, 30));
      case _Tool.erase:
        map.setTile(ground, cell, TileCell.empty);
      case _Tool.hide:
        final hidden =
            map.runtime.hiddenCellsOf(ground.id)?.contains(cell) ?? false;
        // The first cell of a stroke decides: hide or show them all.
        final hide = _hideStroke ??= !hidden;
        map.setCellsHidden(ground, [cell], hide);
    }
    final info = map.tileAt(ground, cell);
    final hidden =
        map.runtime.hiddenCellsOf(ground.id)?.contains(cell) ?? false;
    setState(() {
      _lastCell =
          'cell (${cell.x}, ${cell.y}) → '
          '${info == null ? 'empty' : 'tile #${info.localId}'}'
          '${hidden ? ' (hidden)' : ''}';
    });
  }

  void _resetEdits() {
    final c = _mapEntity?.getComponent<LevelMapComponent>();
    // LevelMapSystem makes a fresh runtime from the file next frame.
    if (c != null) LevelMaps.release(c);
    setState(() {
      _tileEventCount = 0;
      _tilesChanged = 0;
      _lastCell = 'edits dropped: the map is the file again';
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: Tiled objects
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _buildObjects(int build) async {
    _clearWorld(const {DefaultSystem.rendering, DefaultSystem.levelMaps});
    final mapEntity = _addMap(path: _outpostPath);

    await _preload();
    final imported = await _importTiled(_outpostPath);
    if (!_isCurrent(build)) return;
    final map = LevelMaps.primary(_world)!;
    _rememberVisibility(map);
    _describeMap(map, 'desert_outpost.tmx');
    _import = imported;
    _frame(_worldBounds(map));

    for (final record in imported.objects) {
      _objects.add((record, _spawnObject(mapEntity, record)));
    }
  }

  static Color _colorOfType(String type) => switch (type) {
    'spawn' => const Color(0xFF9CCC65),
    'sign' => const Color(0xFFFFCA28),
    'zone' => const Color(0xFF26C6DA),
    'landmark' => const Color(0xFF42A5F5),
    'chest' => const Color(0xFFFF7043),
    'route' => const Color(0xFFF06292),
    _ => Colors.white70,
  };

  static String _labelOf(tiled.TiledObject o) {
    final p = o.properties;
    return switch (o.type) {
      'sign' => '"${p.getString('text') ?? o.name}"',
      'zone' => p.getString('label') ?? o.name,
      'chest' => '${o.name}: ${p.getInt('gold') ?? 0} gold',
      _ => o.name.isEmpty ? o.type : o.name,
    };
  }

  /// One Tiled object as an entity on its object layer: a child of the map
  /// with `LayerComponent.mapLayer`, so it draws just above that layer's
  /// tiles and hides with it. Its label is a second child.
  Entity _spawnObject(Entity mapEntity, TiledObjectRecord record) {
    final o = record.object;
    final color = _colorOfType(o.type);
    final at = record.position;
    final shape = _ObjectShape.of(o, color);
    final entity = _world.createEntityWithComponents([
      TransformComponent(position: Vector3(at.dx, at.dy, 0)),
      ParentComponent(
        parentId: mapEntity.id,
        localPosition: Vector3(at.dx, at.dy, 0),
      ),
      LayerComponent(mapLayer: record.mapLayerId),
      RenderableComponent(
        renderable: shape.renderable..opacity = record.opacity,
      ),
    ], name: o.name.isEmpty ? o.type : o.name);

    final labelAt = at + shape.labelAnchor;
    _world.createEntityWithComponents([
      TransformComponent(position: Vector3(labelAt.dx, labelAt.dy, 0)),
      ParentComponent(
        parentId: mapEntity.id,
        localPosition: Vector3(labelAt.dx, labelAt.dy, 0),
      ),
      LayerComponent(mapLayer: record.mapLayerId),
      RenderableComponent(
        renderable: TextRenderable(
          text: _labelOf(o),
          textStyle: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(blurRadius: 3)],
          ),
        ),
      ),
    ], name: '${entity.name} label');
    return entity;
  }

  void _focusObject(TiledObjectRecord record) {
    final map = LevelMaps.primary(_world);
    if (map == null) return;
    final o = record.object;
    final centre = o.width > 0 && o.height > 0
        ? Offset(o.width / 2, o.height / 2)
        : Offset.zero;
    _camera
      ..setPosition(map.origin + record.position + centre)
      ..setZoom(2.0);
    setState(() {
      final p = record.position;
      _lastCell =
          '${o.name} · type "${o.type}" · layer ${record.layerName}'
          ' · at (${p.dx.toStringAsFixed(0)}, ${p.dy.toStringAsFixed(0)})';
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo: built in code
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _buildCode(int build) async {
    _clearWorld(const {DefaultSystem.rendering, DefaultSystem.levelMaps});
    _addMap(inline: _buildShowcase(_orientation));
    // The cells' outlines, from the map's geometry, over every layer.
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        renderable: CustomRenderable(
          onRender: _paintShowcaseGrid,
          getBoundsCallback: _showcaseBounds,
        ),
      ),
      LayerComponent(layer: LevelLayers.foreground),
    ], name: 'Grid overlay');

    await _preload();
    if (!_isCurrent(build)) return;
    _frameShowcase();
  }

  static (int, int) _showcaseSize(MapOrientation o) => switch (o) {
    MapOrientation.orthogonal => (12, 8),
    MapOrientation.isometric => (8, 8),
    MapOrientation.staggered => (10, 15),
    MapOrientation.hexagonal => (11, 9),
  };

  LevelMapData _buildShowcase(MapOrientation o) {
    final hexagonal = o == MapOrientation.hexagonal;
    final map = LevelMapData(
      orientation: o,
      tileWidth: 32,
      tileHeight: 32,
      hexSideLength: hexagonal ? 16 : 0,
      staggerAxis: TileStaggerAxis.y,
      staggerIndex: TileStaggerIndex.odd,
    );
    final shapes = map.addTileset(BuiltInTilesets.basicShapes);
    final floor = map.addLayer(name: 'Floor')..tint = 0xFF2E5266;
    final props = map.addLayer(name: 'Props')..tint = 0xFFFFCA28;
    // Block, diamond (fills an isometric cell exactly) or circle.
    final floorTile = switch (o) {
      MapOrientation.orthogonal => 0,
      MapOrientation.isometric || MapOrientation.staggered => 22,
      MapOrientation.hexagonal => 20,
    };
    const propTiles = [20, 21, 22, 8];
    final (cols, rows) = _showcaseSize(o);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        floor.cells.setCell(x, y, TileCell.make(shapes, floorTile));
        if ((x * 7 + y * 3) % 5 == 0) {
          final tile = o == MapOrientation.orthogonal
              ? propTiles[(x + y) % propTiles.length]
              : 20;
          props.cells.setCell(x, y, TileCell.make(shapes, tile));
        }
      }
    }
    _showcaseRange = TileRange(0, 0, cols, rows);
    _savedBytes = jsonEncode(map.toJson()).length;
    return map;
  }

  void _setOrientation(MapOrientation o) {
    final c = _mapEntity?.getComponent<LevelMapComponent>();
    if (c == null) return;
    setState(() {
      _orientation = o;
      _pickedCell = null;
      _lastCell = '';
      // A new inline map: LevelMapSystem builds a new runtime for it.
      c.inline = _buildShowcase(o);
    });
    _frameShowcase();
  }

  void _frameShowcase() {
    final data = _mapEntity?.getComponent<LevelMapComponent>()?.inline;
    if (data == null) return;
    _frame(MapGeometry.of(data).boundsOf(_showcaseRange), padding: 32);
  }

  Rect? _showcaseBounds() {
    final data = _mapEntity?.getComponent<LevelMapComponent>()?.inline;
    if (data == null) return null;
    return MapGeometry.of(data).boundsOf(_showcaseRange).inflate(4);
  }

  void _paintShowcaseGrid(Canvas canvas, Size size) {
    final map = LevelMaps.primary(_world);
    if (map == null) return;
    final geometry = map.geometry;
    for (final c in _showcaseRange.coords) {
      canvas.drawPath(
        Path()..addPolygon(geometry.cellPolygon(c.x, c.y), true),
        _gridPaint,
      );
    }
    final picked = _pickedCell;
    if (picked != null) {
      final outline = Path()
        ..addPolygon(geometry.cellPolygon(picked.x, picked.y), true);
      canvas
        ..drawPath(outline, _pickFill)
        ..drawPath(outline, _pickStroke);
    }
  }

  void _pickCell(Offset world) {
    final map = LevelMaps.primary(_world);
    final props = map?.layer('Props');
    if (map == null || props == null) return;
    final cell = map.cellAt(props, world);
    if (!_showcaseRange.contains(cell.x, cell.y)) {
      setState(() {
        _pickedCell = null;
        _lastCell = 'outside the map';
      });
      return;
    }
    final had = !TileCell.isEmpty(map.rawAt(props, cell));
    map.setTile(props, cell, had ? TileCell.empty : TileCell.make(0, 20));
    final centre = map.cellCenter(props, cell);
    setState(() {
      _pickedCell = cell;
      _lastCell =
          'cell (${cell.x}, ${cell.y}) · centre '
          '(${centre.dx.toStringAsFixed(0)}, ${centre.dy.toStringAsFixed(0)})'
          ' · ${had ? 'removed' : 'placed'} a prop';
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pointer
  // ─────────────────────────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length > 1) {
      _tapStart = null; // a pinch, not a tap or a stroke
      return;
    }
    _tapStart = event.localPosition;
    if (_demo == _Demo.edit && !_loading) {
      _lastPainted = null;
      _hideStroke = null;
      _paintAt(event.localPosition);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 1 && _demo == _Demo.edit && !_loading) {
      _paintAt(event.localPosition);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final start = _tapStart;
    final single = _pointers.length == 1;
    _pointers.remove(event.pointer);
    if (_pointers.isEmpty) _tapStart = null;
    if (!single || start == null || _loading) return;
    if ((event.localPosition - start).distance > 8) return;
    _onTap(_camera.screenToWorld(event.localPosition));
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    _tapStart = null;
  }

  void _onTap(Offset world) {
    switch (_demo) {
      case _Demo.tiled:
        _inspectAt(world);
      case _Demo.collision:
        if (_tapAction == _TapAction.ball) {
          _spawnBall(world);
        } else {
          setState(() => _toggleBlock(world));
        }
      case _Demo.code:
        _pickCell(world);
      case _Demo.edit:
      case _Demo.objects:
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stats
  // ─────────────────────────────────────────────────────────────────────────

  String get _statsLine {
    if (_loading) return _status;
    final map = LevelMaps.primary(_world);
    final bodies = _world.getSystem<MapCollisionSystem>()?.bodyCount ?? 0;
    switch (_demo) {
      case _Demo.tiled:
        return '$_mapSummary · $bodies map bodies · '
            '$_travellers travellers';
      case _Demo.collision:
        var tiles = 0;
        for (final layer in map?.map.layers ?? const <MapLayerData>[]) {
          tiles += map!.runtime.cellsOf(layer).cells.length;
        }
        return 'tiles: $tiles  ·  merged bodies: $bodies  ·  '
            'balls: $_ballCount  ·  outlines: ${_showOutlines ? 'on' : 'off'}';
      case _Demo.edit:
        final ground = map?.layer('Ground');
        final hidden = ground == null
            ? 0
            : map!.runtime.hiddenCellsOf(ground.id)?.length ?? 0;
        return '$_mapSummary · TileChangedEvents: $_tileEventCount '
            '($_tilesChanged cells) · hidden: $hidden';
      case _Demo.objects:
        final warnings = _import?.warnings.length ?? 0;
        return '$_mapSummary · ${_objects.length} objects · '
            '$warnings import warning${warnings == 1 ? '' : 's'}';
      case _Demo.code:
        final data = map?.map;
        final cells = _showcaseRange.width * _showcaseRange.height;
        final grid = data == null
            ? ''
            : '${data.tileWidth}×${data.tileHeight}'
                  '${data.hexSideLength > 0 ? ', sides ${data.hexSideLength}' : ''}';
        return 'MapOrientation.${_orientation.name} · grid $grid · '
            '$cells cells · toJson: ${(_savedBytes / 1024).toStringAsFixed(1)} kB';
    }
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
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'LevelMapComponent  ·  LevelMapSystem  ·  MapCollisionSystem',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
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
          if (_lastCell.isNotEmpty && !_loading) ...[
            const SizedBox(height: 3),
            Text(
              _lastCell,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _canvasHint => switch (_demo) {
    _Demo.tiled => 'Tap a tile to inspect every layer · drag to pan',
    _Demo.collision =>
      _tapAction == _TapAction.ball
          ? 'Tap to drop a ball'
          : 'Tap to place or remove a block',
    _Demo.edit =>
      _tool == _Tool.pan
          ? 'Drag to pan · scroll or pinch to zoom'
          : 'Drag to paint · pick Pan to move the view',
    _Demo.objects => 'Pick an object below to fly to it',
    _Demo.code => 'Tap a cell',
  };

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasSize = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xFF07070F),
                child: GameCameraControls(
                  camera: _camera,
                  // Dragging paints in the edit demo, unless panning.
                  enablePan: _demo != _Demo.edit || _tool == _Tool.pan,
                  enablePinch: true,
                  showZoomLevel: true,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerCancel,
                    child: GameWidget(engine: _engine, showFPS: true),
                  ),
                ),
              ),
            ),
            if (!_loading)
              Positioned(
                left: 10,
                bottom: 10,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC060D18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _canvasHint,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            if (_loading || _status.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: _loading
                        ? const Color(0xAA060D18)
                        : Colors.transparent,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_loading)
                          CircularProgressIndicator(
                            color: _demo.accentColor,
                            strokeWidth: 2,
                          ),
                        const SizedBox(height: 14),
                        Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _loading
                                ? Colors.white54
                                : const Color(0xFFF5746F),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
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
                  onSelected: (_) {
                    if (d != _demo || _status.startsWith('Error')) {
                      _switchTo(d);
                    }
                  },
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
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: _loading
          ? const SizedBox(height: 36)
          : switch (_demo) {
              _Demo.tiled => _buildTiledControls(),
              _Demo.collision => _buildCollisionControls(),
              _Demo.edit => _buildEditControls(),
              _Demo.objects => _buildObjectControls(),
              _Demo.code => _buildCodeControls(),
            },
    );
  }

  Widget _buildTiledControls() {
    final layers = LevelMaps.primary(_world)?.map.layers ?? const [];
    return _chipRow([
      for (final layer in layers)
        _toggleChip(
          label: _layerLabel(layer),
          selected: layer.visible,
          icon: layer.visible
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          onTap: () => _toggleLayer(layer),
        ),
      _outlineChip(),
    ]);
  }

  static String _layerLabel(MapLayerData layer) {
    final notes = [
      if (layer.cells.isEmpty) 'objects',
      if (layer.collides) 'collides',
      if (layer.sortLayerId != 'main') layer.sortLayerId,
    ];
    return notes.isEmpty ? layer.name : '${layer.name} · ${notes.join(', ')}';
  }

  Widget _outlineChip() {
    return _toggleChip(
      label: kDebugMode ? 'Collider outlines' : 'Outlines (debug builds)',
      selected: _showOutlines,
      icon: Icons.crop_square,
      onTap: () => _setOutlines(!_showOutlines),
    );
  }

  Widget _buildCollisionControls() {
    return _chipRow([
      _actionButton('Drop 10 balls', _demo.accentColor, () => _dropBalls(10)),
      _actionButton('Clear balls', Colors.white54, _clearBalls),
      _actionButton('Rebuild level', Colors.white54, _rebuildPit),
      _toggleChip(
        label: 'Tap: ball',
        selected: _tapAction == _TapAction.ball,
        icon: Icons.circle_outlined,
        onTap: () => setState(() => _tapAction = _TapAction.ball),
      ),
      _toggleChip(
        label: 'Tap: block',
        selected: _tapAction == _TapAction.block,
        icon: Icons.check_box_outline_blank,
        onTap: () => setState(() => _tapAction = _TapAction.block),
      ),
      _outlineChip(),
    ]);
  }

  Widget _buildEditControls() {
    final terrains = _terrains;
    return _chipRow([
      _toggleChip(
        label: 'Pan',
        selected: _tool == _Tool.pan,
        icon: Icons.open_with,
        onTap: () => setState(() => _tool = _Tool.pan),
      ),
      for (var i = 0; i < terrains.length; i++)
        _toggleChip(
          label: terrains[i].name,
          selected: _tool == _Tool.terrain && _terrain == i + 1,
          dot: Color(terrains[i].color),
          onTap: () => setState(() {
            _tool = _Tool.terrain;
            _terrain = i + 1; // Wang colours count from 1
          }),
        ),
      _toggleChip(
        label: 'Cactus',
        selected: _tool == _Tool.stamp,
        icon: Icons.local_florist_outlined,
        onTap: () => setState(() => _tool = _Tool.stamp),
      ),
      _toggleChip(
        label: 'Erase',
        selected: _tool == _Tool.erase,
        icon: Icons.backspace_outlined,
        onTap: () => setState(() => _tool = _Tool.erase),
      ),
      _toggleChip(
        label: 'Hide / show',
        selected: _tool == _Tool.hide,
        icon: Icons.visibility_off_outlined,
        onTap: () => setState(() => _tool = _Tool.hide),
      ),
      _actionButton('Reset edits', Colors.white54, _resetEdits),
    ]);
  }

  Widget _buildObjectControls() {
    final objectsLayer = LevelMaps.primary(_world)?.layer('Objects');
    return _chipRow([
      if (objectsLayer != null)
        _toggleChip(
          label: 'Objects layer',
          selected: objectsLayer.visible,
          icon: objectsLayer.visible
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          onTap: () => _toggleLayer(objectsLayer),
        ),
      for (final (record, _) in _objects)
        _toggleChip(
          label: record.object.name.isEmpty
              ? record.object.type
              : record.object.name,
          selected: false,
          dot: _colorOfType(record.object.type),
          onTap: () => _focusObject(record),
        ),
    ]);
  }

  Widget _buildCodeControls() {
    return _chipRow([
      for (final o in MapOrientation.values)
        _toggleChip(
          label: o.name,
          selected: _orientation == o,
          icon: switch (o) {
            MapOrientation.orthogonal => Icons.grid_on,
            MapOrientation.isometric => Icons.change_history,
            MapOrientation.staggered => Icons.view_module_outlined,
            MapOrientation.hexagonal => Icons.hexagon_outlined,
          },
          onTap: () => _setOrientation(o),
        ),
    ]);
  }

  Widget _chipRow(List<Widget> children) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) => Center(child: children[i]),
      ),
    );
  }

  Widget _toggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    Color? dot,
  }) {
    final accent = _demo.accentColor;
    return FilterChip(
      avatar: dot != null
          ? CircleAvatar(radius: 5, backgroundColor: dot)
          : icon == null
          ? null
          : Icon(icon, size: 13, color: selected ? accent : Colors.white38),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: selected ? Colors.white : Colors.white54,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: accent.withValues(alpha: 0.18),
      backgroundColor: const Color(0xFF0E1A2A),
      side: BorderSide(
        color: selected
            ? accent.withValues(alpha: 0.7)
            : const Color(0xFF1E2E40),
      ),
      onSelected: (_) => onTap(),
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
                  'just_game_engine 2.x · level maps',
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

// ═══════════════════════════════════════════════════════════════════════════
// Private components
// ═══════════════════════════════════════════════════════════════════════════

/// Marks the collision demo's balls.
class _Ball extends Component {}

/// Walks its entity round a closed [route], picking the run sheet that faces
/// the way it goes and stepping through the sheet's eight frames.
class _Traveller extends Component {
  _Traveller({
    required this.route,
    required this.sheets,
    required this.distance,
    required this.speed,
  }) : length = lengthOf(route);

  /// World points, the last joining the first.
  final List<Offset> route;

  /// The run sheets by direction: `up`, `down`, `left`, `right`.
  final Map<String, ui.Image> sheets;

  /// How far along the route it is.
  double distance;

  /// World units a second.
  final double speed;

  final double length;
  double clock = 0;

  static double lengthOf(List<Offset> route) {
    var total = 0.0;
    for (var i = 1; i < route.length; i++) {
      total += (route[i] - route[i - 1]).distance;
    }
    return total;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private systems (run by the engine's own loop)
// ═══════════════════════════════════════════════════════════════════════════

/// Moves and animates the travellers of the Tiled demo.
class _TravellerSystem extends System {
  /// The run sheets' frames: eight of 96 × 80 in a row.
  static const int _frames = 8;
  static const double _frameWidth = 96;
  static const double _frameHeight = 80;

  /// From the sprite's centre down to the character's feet.
  static const double _feet = 18;

  @override
  List<Type> get requiredComponents => const [
    TransformComponent,
    RenderableComponent,
    _Traveller,
  ];

  @override
  void update(double deltaTime) {
    forEach((entity) {
      final t = entity.getComponent<_Traveller>()!;
      if (t.length <= 0) return;
      t
        ..distance = (t.distance + t.speed * deltaTime) % t.length
        ..clock += deltaTime;

      var left = t.distance;
      var at = t.route.first;
      var heading = Offset.zero;
      for (var i = 1; i < t.route.length; i++) {
        final a = t.route[i - 1], b = t.route[i];
        final segment = (b - a).distance;
        if (left <= segment && segment > 0) {
          heading = (b - a) / segment;
          at = a + heading * left;
          break;
        }
        left -= segment;
      }
      entity.getComponent<TransformComponent>()!.position.setValues(
        at.dx,
        at.dy - _feet,
        0,
      );

      final sprite = entity.getComponent<RenderableComponent>()!.renderable;
      if (sprite is! Sprite) return;
      final facing = heading.dx.abs() >= heading.dy.abs()
          ? (heading.dx >= 0 ? 'right' : 'left')
          : (heading.dy >= 0 ? 'down' : 'up');
      sprite.image = t.sheets[facing] ?? sprite.image;
      final frame = (t.clock * 12).floor() % _frames;
      sprite.sourceRect = Rect.fromLTWH(
        frame * _frameWidth,
        0,
        _frameWidth,
        _frameHeight,
      );
    });
  }
}

/// Lets `PhysicsSystem.drawsOutlines` show the map's own bodies too:
/// `MapCollisionSystem` builds them with `showDebugOutline` off, and builds
/// them again whenever their tiles change.
class _MapOutlineSystem extends System {
  _MapOutlineSystem(this.enabled);

  final bool Function() enabled;

  @override
  List<Type> get requiredComponents => const [MapBodyComponent, Collider2D];

  @override
  void update(double deltaTime) {
    final on = enabled();
    forEach((entity) {
      entity.getComponent<Collider2D>()!.showDebugOutline = on;
    });
  }
}

/// Removes balls that fell out of the level.
class _BallCleanupSystem extends System {
  _BallCleanupSystem({required this.killY});

  final double killY;

  @override
  List<Type> get requiredComponents => const [TransformComponent, _Ball];

  @override
  void update(double deltaTime) {
    final gone = [
      for (final e in entities)
        if (e.getComponent<TransformComponent>()!.position.y > killY) e,
    ];
    for (final e in gone) {
      world.destroyEntity(e);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Drawing a Tiled object
// ═══════════════════════════════════════════════════════════════════════════

/// A Tiled object's shape as a renderable drawn from the object's origin,
/// and where its label goes.
class _ObjectShape {
  _ObjectShape(this.renderable, this.labelAnchor);

  final CustomRenderable renderable;

  /// From the object's origin to its label's centre.
  final Offset labelAnchor;

  static _ObjectShape of(tiled.TiledObject o, Color color) {
    final fill = Paint()..color = color.withValues(alpha: 0.22);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Path path;
    var open = false;
    if (o.isPoint) {
      path = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 5));
    } else if (o.polygon != null) {
      path = Path()..addPolygon(o.polygon!, true);
    } else if (o.polyline != null) {
      path = Path()..addPolygon(o.polyline!, false);
      open = true;
    } else if (o.isEllipse) {
      path = Path()..addOval(Rect.fromLTWH(0, 0, o.width, o.height));
    } else {
      path = Path()..addRect(Rect.fromLTWH(0, 0, o.width, o.height));
    }
    final bounds = path.getBounds();
    final renderable = CustomRenderable(
      onRender: (canvas, _) {
        if (!open) canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        if (o.isPoint) {
          canvas.drawCircle(Offset.zero, 1.5, stroke);
        }
      },
      getBoundsCallback: () => bounds.inflate(4),
    );
    // Above a point, under a line's first point, at the top of an area.
    final anchor = o.isPoint
        ? const Offset(0, -12)
        : open
        ? const Offset(0, 14)
        : Offset(
            bounds.center.dx,
            bounds.top + math.min(10.0, bounds.height / 2),
          );
    return _ObjectShape(renderable, anchor);
  }
}
