import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_tiled/just_tiled.dart';

import '../../core/di/app_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  explore,
  player,
  camera,
  objects;

  String get label => switch (this) {
    explore => 'Map Overview',
    player => 'Player Walk',
    camera => 'Camera Follow',
    objects => 'Object Layer',
  };

  IconData get icon => switch (this) {
    explore => Icons.map_outlined,
    player => Icons.directions_walk,
    camera => Icons.videocam_outlined,
    objects => Icons.layers_outlined,
  };

  Color get accentColor => switch (this) {
    explore => const Color(0xFF26C6DA),
    player => const Color(0xFF9CCC65),
    camera => const Color(0xFFFFCA28),
    objects => const Color(0xFFFF7043),
  };

  String get description => switch (this) {
    explore =>
      'desert.tmx loaded via TileMapParser. TiledMapFactory spawns one entity '
          'per layer with a TileMapLayerComponent and TextureAtlas for rendering.',
    player =>
      'Character03 walks on the Tiled map with WASD / arrow keys (or joystick). '
          '_PlayerAnimationSystem drives directional sprite-sheet animations.',
    camera =>
      'Camera.follow() with dead-zone and smoothing keeps the player centred. '
          'CameraZoomControls lets you pan and pinch-zoom freely.',
    objects =>
      'Object layers parsed to Dart objects. Type-mapped components are created '
          'via componentMapper: collider → RaycastColliderComponent, spawn → TagComponent.',
  };

  String get codeSnippet => switch (this) {
    explore =>
      '// Parse the TMX file:\n'
          'final map = await TileMapParser.parse(\n'
          '  tmxString,\n'
          '  tsxProvider: const DefaultTsxProvider(\n'
          '    basePath: "assets/maps"),\n'
          ');\n\n'
          '// Build + spawn all layers as entities:\n'
          'TiledMapFactory.spawnMap(world, map,\n'
          '  atlasCollection,\n'
          '  componentMapper: _mapper,\n'
          ');',
    player =>
      '// Per-frame in _onTick:\n'
          'final input = entity.getComponent<InputComponent>()!;\n'
          'input.moveDirection = joystick.direction; // mobile\n\n'
          '// _PlayerAnimationSystem selects the correct\n'
          '// directional strip based on velocity:\n'
          "final animName = '\${prefix}_\$facing';\n"
          'if (animName != animComp.currentAnimation) {\n'
          '  animComp.currentAnimation = animName;\n'
          '}',
    camera =>
      '// Smooth camera follow:\n'
          'camera.follow(\n'
          '  transform.position,\n'
          '  deadZone: const Offset(20, 20),\n'
          '  smooth: true,\n'
          ');\n'
          'camera.update(dt);\n\n'
          '// Zoom & pan via widget:\n'
          'CameraZoomControls(\n'
          '  camera: _engine.rendering.camera,\n'
          '  child: GameWidget(...),\n'
          ');',
    objects =>
      '// Map object type → engine component:\n'
          'Component? _mapper(\n'
          '  String className,\n'
          '  TiledProperties props,\n'
          ') {\n'
          '  if (className == "collider") {\n'
          '    return RaycastColliderComponent(\n'
          '      width:  props.getDouble("width"),\n'
          '      height: props.getDouble("height"),\n'
          '      tag: "wall",\n'
          '      isBlocker: true);\n'
          '  }\n'
          '  return null;\n'
          '}',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class TiledMapScreen extends StatefulWidget {
  const TiledMapScreen({super.key});

  @override
  State<TiledMapScreen> createState() => _TiledMapScreenState();
}

class _TiledMapScreenState extends State<TiledMapScreen>
    with SingleTickerProviderStateMixin {
  // ── Engine ───────────────────────────────────────────────────────────────
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  final GlobalKey _gameWidgetKey = GlobalKey();
  Duration _lastTickTime = Duration.zero;

  // ── State ────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.player;
  bool _loading = true;
  String _statusMessage = 'Initializing…';

  // ── Player & map ─────────────────────────────────────────────────────────
  Entity? _playerEntity;
  Offset _playerStartPosition = Offset.zero;
  double _playerSpeed = 120.0;

  // ── Joystick (mobile) ────────────────────────────────────────────────────
  final bool isMobile = getIt<AppConfig>().isMobile;
  JoystickInputComponent? _joystickComponent;

  // ── Character assets ─────────────────────────────────────────────────────
  final Map<String, ui.Image> _characterImages = {};
  final Map<String, List<Rect>> _characterFrames = {};
  final Map<String, SpriteAnimation> _animations = {};
  Sprite? _playerSprite;

  // ── Map metadata ─────────────────────────────────────────────────────────
  int _mapWidth = 0;
  int _mapHeight = 0;
  int _tileWidth = 0;
  int _tileHeight = 0;
  int _tilesetCount = 0;
  int _objectCount = 0;
  int _colliderCount = 0;

  static const String _characterRoot = 'assets/sprites/characters/character03';

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeMap());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clearWorld();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tick
  // ─────────────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      return;
    }
    final dt = (elapsed - _lastTickTime).inMicroseconds / 1_000_000.0;
    _lastTickTime = elapsed;

    if (isMobile && _playerEntity != null && _joystickComponent != null) {
      _playerEntity!.getComponent<InputComponent>()?.moveDirection =
          _joystickComponent!.direction;
    }

    _world.update(dt);

    if (_playerEntity != null) {
      final transform = _playerEntity!.getComponent<TransformComponent>();
      if (transform != null) {
        _engine.rendering.camera.follow(
          transform.position,
          deadZone: const Offset(20, 20),
          smooth: true,
        );
        _engine.rendering.camera.update(dt);
      }
    }

    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initializeMap() async {
    try {
      setState(() => _statusMessage = 'Loading character assets…');
      await _loadCharacterAssets();

      setState(() => _statusMessage = 'Loading desert.tmx…');
      await _loadAndBuildMap();

      if (mounted)
        setState(() {
          _loading = false;
          _statusMessage = '';
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _statusMessage = 'Error: $e';
        });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Character assets
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadCharacterAssets() async {
    final jsonAsset = await _engine.assets.loadJson(
      '$_characterRoot/info.json',
    );
    final parsed = jsonAsset.data as Map<String, dynamic>;
    final spriteSheet = parsed['spriteSheet'] as Map<String, dynamic>? ?? {};

    for (final entry in spriteSheet.entries) {
      final name = entry.key;
      final info = entry.value as Map<String, dynamic>;
      final imagePath = info['imagePath'] as String?;
      final frameWidth = info['frameWidth'] as int?;
      final frameHeight = info['frameHeight'] as int?;
      final frameCount = info['frameCount'] as int?;
      final linear = info['linear'] as bool? ?? true;

      if (imagePath == null ||
          frameWidth == null ||
          frameHeight == null ||
          frameCount == null)
        continue;

      final image = await Sprite.loadImageFromAsset(
        '$_characterRoot/$imagePath',
      );
      _characterImages[name] = image;
      _characterFrames[name] = _buildFrames(
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        frameCount: frameCount,
        linear: linear,
        imageWidth: image.width,
        imageHeight: image.height,
      );
    }
  }

  List<Rect> _buildFrames({
    required int frameWidth,
    required int frameHeight,
    required int frameCount,
    required bool linear,
    required int imageWidth,
    required int imageHeight,
  }) {
    final frames = <Rect>[];
    if (linear) {
      for (int i = 0; i < frameCount; i++) {
        final x = i * frameWidth;
        if (x + frameWidth <= imageWidth) {
          frames.add(
            Rect.fromLTWH(
              x.toDouble(),
              0,
              frameWidth.toDouble(),
              frameHeight.toDouble(),
            ),
          );
        }
      }
    } else {
      final cols = imageWidth ~/ frameWidth;
      for (int i = 0; i < frameCount; i++) {
        final col = i % cols;
        final row = i ~/ cols;
        final x = col * frameWidth;
        final y = row * frameHeight;
        if (x + frameWidth <= imageWidth && y + frameHeight <= imageHeight) {
          frames.add(
            Rect.fromLTWH(
              x.toDouble(),
              y.toDouble(),
              frameWidth.toDouble(),
              frameHeight.toDouble(),
            ),
          );
        }
      }
    }
    return frames;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Map loading
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadAndBuildMap() async {
    final tmxString = await rootBundle.loadString('assets/maps/desert.tmx');
    final map = await TileMapParser.parse(
      tmxString,
      tsxProvider: const DefaultTsxProvider(basePath: 'assets/maps'),
    );

    _mapWidth = map.width;
    _mapHeight = map.height;
    _tileWidth = map.tileWidth;
    _tileHeight = map.tileHeight;
    _tilesetCount = map.tilesets.length;

    final atlases = <TextureAtlas>[];
    for (final tileset in map.tilesets) {
      final imageSource = tileset.imageSource;
      if (imageSource != null) {
        final imageAsset = await _engine.assets.loadImage(
          'assets/maps/$imageSource',
        );
        if (imageAsset.image != null) {
          atlases.add(TextureAtlas(image: imageAsset.image!, tileset: tileset));
        }
      }
    }
    final atlasCollection = TextureAtlasCollection(atlases);

    final camera = _engine.rendering.camera;
    camera.zoom = 1.0;
    camera.smoothing = true;
    camera.smoothingFactor = 0.08;

    _clearWorld();

    if (!isMobile) {
      _world.addSystem(InputSystem(_engine.input)..priority = 100);
    }
    _world.addSystem(_PlayerAnimationSystem()..priority = 90);
    _world.addSystem(MovementSystem()..priority = 80);
    _world.addSystem(_CameraAwareRenderSystem(camera)..priority = 40);

    final spawnedEntities = TiledMapFactory.spawnMap(
      _world,
      map,
      atlasCollection,
      componentMapper: _mapComponentMapper,
    );

    _processMapObjects(spawnedEntities);
    _createPlayer();
  }

  Component? _mapComponentMapper(String className, TiledProperties properties) {
    final lowerClass = className.toLowerCase();
    if (lowerClass == 'collider' ||
        lowerClass == 'wall' ||
        lowerClass == 'obstacle' ||
        lowerClass == 'collision') {
      _colliderCount++;
      return RaycastColliderComponent(
        width: properties.getDouble('width') ?? 32,
        height: properties.getDouble('height') ?? 32,
        tag: 'wall',
        isBlocker: true,
      );
    }
    if (lowerClass == 'spawn' ||
        lowerClass == 'start' ||
        lowerClass == 'player_start') {
      return TagComponent('player_start');
    }
    return null;
  }

  void _processMapObjects(List<Entity> spawnedEntities) {
    _objectCount = 0;
    Offset? foundStart;

    for (final entity in spawnedEntities) {
      final tiledObj = entity.getComponent<TiledObjectComponent>();
      if (tiledObj == null) continue;
      _objectCount++;

      final obj = tiledObj.tiledObject;
      final transform = entity.getComponent<TransformComponent>();
      final objType = obj.type.toLowerCase();
      final objName = obj.name.toLowerCase();

      if (objType == 'spawn' ||
          objType == 'start' ||
          objType == 'player_start' ||
          objName == 'spawn' ||
          objName == 'start' ||
          objName == 'player_start' ||
          objName == 'player') {
        if (transform != null) foundStart = transform.position;
      }

      if ((objType == 'collider' ||
              objType == 'wall' ||
              objType == 'obstacle' ||
              objType == 'collision') &&
          !entity.hasComponent<RaycastColliderComponent>()) {
        entity.addComponent(
          RaycastColliderComponent(
            width: obj.width,
            height: obj.height,
            tag: 'wall',
            isBlocker: true,
          ),
        );
        _colliderCount++;
      }
    }

    _playerStartPosition =
        foundStart ??
        Offset(
          (_mapWidth * _tileWidth) / 2.0,
          (_mapHeight * _tileHeight) / 2.0,
        );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Player
  // ─────────────────────────────────────────────────────────────────────────

  void _createPlayer() {
    final defaultImage = _characterImages['idle_down'];
    final defaultFrames = _characterFrames['idle_down'];
    if (defaultImage == null || defaultFrames == null || defaultFrames.isEmpty)
      return;

    _playerSprite = Sprite(
      image: defaultImage,
      sourceRect: defaultFrames.first,
      renderSize: const Size(96, 80),
      layer: 10,
    );

    for (final entry in _characterImages.entries) {
      final name = entry.key;
      final frames = _characterFrames[name];
      if (frames == null || frames.isEmpty) continue;
      _animations[name] = SpriteAnimation(
        sprite: _playerSprite!,
        frames: frames,
        duration: 0.8,
        loop: true,
      );
    }

    _joystickComponent = JoystickInputComponent(
      layout: JoystickInputLayout.floating,
      axis: JoystickInputAxis.both,
      radius: 64,
    );

    _playerEntity = _world.createEntityWithComponents([
      TransformComponent(position: _playerStartPosition),
      VelocityComponent(maxSpeed: _playerSpeed),
      InputComponent(),
      _joystickComponent!,
      RenderableComponent(renderable: _playerSprite!),
      _PlayerAnimationComponent(
        animations: _animations,
        images: _characterImages,
        currentAnimation: 'idle_down',
      ),
    ], name: 'player');

    _engine.rendering.camera.position = _playerStartPosition;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _clearWorld() {
    for (final s in List<System>.from(_world.systems)) {
      _world.removeSystem(s);
    }
    _world.destroyAllEntities();
    // Reset camera to origin so subsequent screens see their entities.
    _engine.rendering.camera
      ..setPosition(Offset.zero)
      ..setZoom(1.0)
      ..smoothing = false;
  }

  void _resetCamera() {
    _engine.rendering.camera
      ..zoom = 2.0
      ..smoothing = true
      ..smoothingFactor = 0.08;
    if (_playerEntity != null) {
      final pos = _playerEntity!.getComponent<TransformComponent>()?.position;
      if (pos != null) _engine.rendering.camera.position = pos;
    }
    setState(() => _statusMessage = 'Camera reset');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stats
  // ─────────────────────────────────────────────────────────────────────────

  String get _statsLine {
    if (_loading) return _statusMessage;
    final pos = _playerEntity?.getComponent<TransformComponent>()?.position;
    final px = pos?.dx.toStringAsFixed(0) ?? '?';
    final py = pos?.dy.toStringAsFixed(0) ?? '?';
    return 'map: ${_mapWidth}×$_mapHeight tiles (${_tileWidth}×${_tileHeight} px)'
        '  objects: $_objectCount  colliders: $_colliderCount'
        '  player: ($px, $py)';
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
                'TileMapParser  ·  TiledMapFactory  ·  TextureAtlas',
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
          if (_statusMessage.isNotEmpty && !_loading) ...[
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
      return Container(
        color: const Color(0xFF060D18),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: _demo.accentColor,
                strokeWidth: 2,
              ),
              const SizedBox(height: 14),
              Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GameCameraControls(
            camera: _engine.rendering.camera,
            enablePan: true,
            enablePinch: true,
            showZoomLevel: true,
            child: GameWidget(
              key: _gameWidgetKey,
              engine: _engine,
              showFPS: true,
              showDebug: false,
            ),
          ),
        ),
        if (isMobile)
          Positioned.fill(
            child: VirtualJoystick(
              variant: JoystickVariant.floating,
              axis: JoystickAxis.both,
              radius: 64,
              showWhenInactive: false,
              inactiveOpacity: 0,
              onDirectionChanged: (direction) {
                _joystickComponent?.direction = direction;
              },
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
                  onSelected: (_) => setState(() => _demo = d),
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
      case _Demo.explore:
        return _buildExploreControls();
      case _Demo.player:
        return _buildPlayerControls();
      case _Demo.camera:
        return _buildCameraControls();
      case _Demo.objects:
        return _buildObjectsControls();
    }
  }

  Widget _buildExploreControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        _loading
            ? _statusMessage
            : 'desert.tmx  ·  ${_mapWidth}×$_mapHeight tiles  '
                  '·  tile size ${_tileWidth}×${_tileHeight} px  '
                  '·  $_tilesetCount tileset(s) — pinch / scroll to zoom',
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
    );
  }

  Widget _buildPlayerControls() {
    return Row(
      children: [
        const Text(
          'Speed',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _demo.accentColor,
              thumbColor: _demo.accentColor,
              inactiveTrackColor: const Color(0xFF1E2E40),
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: _playerSpeed,
              min: 40,
              max: 400,
              divisions: 18,
              label: '${_playerSpeed.toStringAsFixed(0)} px/s',
              onChanged: _loading
                  ? null
                  : (v) {
                      setState(() => _playerSpeed = v);
                      _playerEntity
                              ?.getComponent<VelocityComponent>()
                              ?.maxSpeed =
                          _playerSpeed;
                    },
            ),
          ),
        ),
        Text(
          '${_playerSpeed.toStringAsFixed(0)} px/s',
          style: TextStyle(
            color: _demo.accentColor,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 12),
        _actionButton(
          isMobile ? 'Joystick  ·  Drag' : 'WASD / Arrows',
          _demo.accentColor,
          null,
        ),
      ],
    );
  }

  Widget _buildCameraControls() {
    return Row(
      children: [
        _actionButton(
          'Reset Camera',
          const Color(0xFFFFCA28),
          _loading ? null : _resetCamera,
        ),
        const SizedBox(width: 12),
        const Text(
          'dead-zone: (20, 20)  ·  smoothingFactor: 0.08  ·  zoom: ×2',
          style: TextStyle(
            color: Colors.white30,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildObjectsControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'objects: $_objectCount',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'colliders: $_colliderCount',
          style: TextStyle(
            color: const Color(0xFFFF7043).withValues(alpha: 0.9),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          '·  componentMapper routes type → RaycastColliderComponent',
          style: TextStyle(color: Colors.white30, fontSize: 11),
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
                  'just_tiled · TiledMapFactory API',
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

// ═══════════════════════════════════════════════════════════════════════════
// Private ECS Components
// ═══════════════════════════════════════════════════════════════════════════

class _PlayerAnimationComponent extends Component {
  _PlayerAnimationComponent({
    required this.animations,
    required this.images,
    required this.currentAnimation,
  });

  final Map<String, SpriteAnimation> animations;
  final Map<String, ui.Image> images;
  String currentAnimation;
}

// ═══════════════════════════════════════════════════════════════════════════
// Private ECS Systems
// ═══════════════════════════════════════════════════════════════════════════

/// Reads InputComponent direction, drives velocity, and switches animation
/// to match the player's facing direction and movement state.
class _PlayerAnimationSystem extends System {
  @override
  List<Type> get requiredComponents => [
    InputComponent,
    VelocityComponent,
    _PlayerAnimationComponent,
  ];

  @override
  void update(double dt) {
    forEach((entity) {
      final input = entity.getComponent<InputComponent>()!;
      final velocity = entity.getComponent<VelocityComponent>()!;
      final animComp = entity.getComponent<_PlayerAnimationComponent>()!;

      final dir = input.moveDirection;
      final isMoving = dir.distance > 0.01;

      // Determine facing direction from input
      String facing;
      if (dir.dy < -0.1) {
        facing = 'up';
      } else if (dir.dy > 0.1) {
        facing = 'down';
      } else if (dir.dx < -0.1) {
        facing = 'left';
      } else if (dir.dx > 0.1) {
        facing = 'right';
      } else {
        // Keep current facing direction
        facing = animComp.currentAnimation
            .replaceAll('idle_', '')
            .replaceAll('run_', '');
      }

      // Apply velocity
      if (isMoving) {
        final normalized = dir.distance > 1.0 ? dir / dir.distance : dir;
        velocity.velocity = Offset(
          normalized.dx * velocity.maxSpeed,
          normalized.dy * velocity.maxSpeed,
        );
      } else {
        velocity.velocity = Offset.zero;
      }

      final prefix = isMoving ? 'run' : 'idle';
      final animName = '${prefix}_$facing';

      // Switch animation when direction/state changes
      if (animName != animComp.currentAnimation &&
          animComp.animations.containsKey(animName)) {
        animComp.currentAnimation = animName;

        // Swap the sprite sheet image for the new direction
        final sprite = entity.getComponent<RenderableComponent>()?.renderable;
        if (sprite is Sprite) {
          final newImage = animComp.images[animName];
          if (newImage != null) sprite.image = newImage;
        }

        // Reset animation clock
        animComp.animations[animName]?.currentTime = 0.0;
      }

      // Advance the active animation
      animComp.animations[animComp.currentAnimation]?.update(dt);
    });
  }
}

/// Applies camera transform and renders all entities with RenderableComponent.
class _CameraAwareRenderSystem extends System {
  _CameraAwareRenderSystem(this.camera);
  final Camera camera;

  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    RenderableComponent,
  ];

  @override
  void render(Canvas canvas, Size size) {
    camera.viewportSize = size;
    canvas.save();
    camera.applyTransform(canvas, size);

    // Render tile map layers first (background)
    final visibleBounds = camera.getVisibleBounds();
    for (final entity in world.query([TileMapLayerComponent])) {
      final tileMapComp = entity.getComponent<TileMapLayerComponent>()!;
      if (!tileMapComp.tileLayer.visible) continue;
      final layerBounds = tileMapComp.renderer.worldBounds;
      if (!layerBounds.overlaps(visibleBounds)) continue;
      tileMapComp.renderer.render(
        canvas,
        Offset(camera.position.dx, camera.position.dy),
        visibleBounds,
      );
    }

    // Render entities (player, etc.)
    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final renderComp = entity.getComponent<RenderableComponent>()!;

      if (renderComp.syncTransform) {
        renderComp.renderable.position = transform.position;
        renderComp.renderable.rotation = transform.rotation;
        renderComp.renderable.scale = transform.scale;
      }

      if (renderComp.renderable.visible) {
        renderComp.renderable.render(canvas, size);
      }
    });

    canvas.restore();
  }
}
