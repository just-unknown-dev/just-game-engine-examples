import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_tiled/just_tiled.dart';

import '../../core/di/app_config.dart';
import '../../core/widgets/camera_zoom_controls.dart';

class TiledMapScreen extends StatefulWidget {
  const TiledMapScreen({super.key});

  @override
  State<TiledMapScreen> createState() => _TiledMapScreenState();
}

class _TiledMapScreenState extends State<TiledMapScreen>
    with SingleTickerProviderStateMixin {
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  final GlobalKey _gameWidgetKey = GlobalKey();

  Duration _lastTickTime = Duration.zero;

  bool _loading = true;
  String _statusMessage = 'Initializing...';

  // Player state
  Entity? _playerEntity;
  Offset _playerStartPosition = Offset.zero;
  double _playerSpeed = 120.0;

  // Joystick (mobile)
  bool isMobile = getIt<AppConfig>().isMobile;
  JoystickInputComponent? _joystickComponent;

  // Character03 assets
  final Map<String, ui.Image> _characterImages = {};
  final Map<String, List<Rect>> _characterFrames = {};
  final Map<String, SpriteAnimation> _animations = {};
  Sprite? _playerSprite;

  // Map info
  int _mapWidth = 0;
  int _mapHeight = 0;
  int _tileWidth = 0;
  int _tileHeight = 0;
  int _objectCount = 0;
  int _colliderCount = 0;

  static const String _characterRoot = 'assets/sprites/characters/character03';

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;

    _ticker = createTicker(_onTick)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _world.destroyAllEntities();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      return;
    }

    final dt = (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;

    // Bridge joystick → InputComponent on mobile
    if (isMobile && _playerEntity != null && _joystickComponent != null) {
      final input = _playerEntity!.getComponent<InputComponent>();
      if (input != null) {
        input.moveDirection = _joystickComponent!.direction;
      }
    }

    _engine.world.update(dt);

    // Camera follows the player
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

  // ── Initialization ────────────────────────────────────────────────────

  Future<void> _initializeMap() async {
    try {
      setState(() => _statusMessage = 'Loading character03 assets...');
      await _loadCharacterAssets();

      setState(() => _statusMessage = 'Loading desert.tmx map...');
      await _loadAndBuildMap();

      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  // ── Character Asset Loading ───────────────────────────────────────────

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
          frameCount == null) {
        continue;
      }

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

  // ── Map Loading ───────────────────────────────────────────────────────

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

    // Load texture atlases for tilesets
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

    // Configure camera
    final camera = _engine.rendering.camera;
    camera.zoom = 2.0;
    camera.smoothing = true;
    camera.smoothingFactor = 0.08;

    _clearWorld();

    // Add systems in priority order
    // On mobile the joystick bridge writes InputComponent directly,
    // so skip InputSystem which would overwrite with keyboard zeros.
    if (!isMobile) {
      _world.addSystem(InputSystem(_engine.input)..priority = 100);
    }
    _world.addSystem(_PlayerAnimationSystem()..priority = 90);
    _world.addSystem(MovementSystem()..priority = 80);
    _world.addSystem(_CameraAwareRenderSystem(camera)..priority = 40);

    // Spawn tile layers + object entities from the Tiled map
    final spawnedEntities = TiledMapFactory.spawnMap(
      _world,
      map,
      atlasCollection,
      componentMapper: _mapComponentMapper,
    );

    // Process objects to find start position and configure colliders
    _processMapObjects(spawnedEntities);

    // Create the player at the start position
    _createPlayer();
  }

  /// Maps Tiled object type names to engine components.
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

      // Detect start position by object type or name
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

      // Auto-create colliders for collision-typed objects that
      // weren't already handled by the componentMapper
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

    // Default start position: center of map
    _playerStartPosition =
        foundStart ??
        Offset(
          (_mapWidth * _tileWidth) / 2.0,
          (_mapHeight * _tileHeight) / 2.0,
        );
  }

  // ── Player Creation ───────────────────────────────────────────────────

  void _createPlayer() {
    final defaultImage = _characterImages['idle_down'];
    final defaultFrames = _characterFrames['idle_down'];

    if (defaultImage == null ||
        defaultFrames == null ||
        defaultFrames.isEmpty) {
      debugPrint('character03 idle_down animation not found');
      return;
    }

    _playerSprite = Sprite(
      image: defaultImage,
      sourceRect: defaultFrames.first,
      renderSize: const Size(96, 80),
      layer: 10,
    );

    // Build all directional SpriteAnimations
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

    // Place the camera on the player immediately
    _engine.rendering.camera.position = _playerStartPosition;
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Size _readViewportSize() {
    final renderObject = _gameWidgetKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }
    return MediaQuery.sizeOf(context);
  }

  void _clearWorld() {
    final existingSystems = List<System>.from(_world.systems);
    for (final system in existingSystems) {
      _world.removeSystem(system);
    }
    _world.destroyAllEntities();
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _loading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: CameraZoomControls(
                        camera: _engine.rendering.camera,
                        child: GameWidget(
                          key: _gameWidgetKey,
                          engine: _engine,
                          showFPS: true,
                          showDebug: true,
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
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: const Color(0xFF1A1510),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tiled Map – Desert',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _loading
                    ? _statusMessage
                    : 'Map: ${_mapWidth}x$_mapHeight tiles '
                          '(${_tileWidth}x$_tileHeight px)   '
                          'Objects: $_objectCount   '
                          'Colliders: $_colliderCount',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (!_loading) ...[
                const SizedBox(height: 4),
                Text(
                  'Player: character03   '
                  'Pos: (${_playerEntity?.getComponent<TransformComponent>()?.position.dx.toStringAsFixed(0) ?? '?'}, '
                  '${_playerEntity?.getComponent<TransformComponent>()?.position.dy.toStringAsFixed(0) ?? '?'})   '
                  'WASD / Arrow keys to move',
                  style: const TextStyle(
                    color: Color(0xFF9DD9D2),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_statusMessage.isNotEmpty && !_loading)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Speed', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: _playerSpeed,
                      min: 40,
                      max: 400,
                      divisions: 18,
                      label: '${_playerSpeed.toStringAsFixed(0)} px/s',
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() => _playerSpeed = value);
                              _playerEntity
                                      ?.getComponent<VelocityComponent>()
                                      ?.maxSpeed =
                                  _playerSpeed;
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
