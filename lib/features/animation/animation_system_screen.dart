import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/widgets/camera_zoom_controls.dart';

class AnimationSystemScreen extends StatefulWidget {
  const AnimationSystemScreen({super.key});

  @override
  State<AnimationSystemScreen> createState() => _AnimationSystemScreenState();
}

class _AnimationSystemScreenState extends State<AnimationSystemScreen>
    with SingleTickerProviderStateMixin {
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;
  final GlobalKey _gameWidgetKey = GlobalKey();
  final math.Random _random = math.Random();

  Duration _lastTickTime = Duration.zero;
  Size _viewportSize = Size.zero;

  bool _loading = true;
  bool _useWalkAnimation = true;
  int _characterCount = 12;
  double _playbackSpeed = 1.0;

  ui.Image? _idleImage;
  ui.Image? _walkImage;
  List<Rect> _idleFrames = const [];
  List<Rect> _walkFrames = const [];

  String _artist = '';
  String _source = '';

  static const String root = 'assets/sprites/characters/character02';

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;

    _ticker = createTicker(_onTick)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeShowcase();
    });
  }

  Future<void> _initializeShowcase() async {
    await _loadCharacterAssets();
    _rebuildAnimationShowcase();
  }

  Future<void> _loadCharacterAssets() async {
    setState(() {
      _loading = true;
    });

    final jsonAsset = await _engine.assets.loadJson('$root/info.json');
    final parsed = jsonAsset.data as Map<String, dynamic>;

    final credits = parsed['credits'] as Map<String, dynamic>?;
    _artist = (credits?['artist'] as String?) ?? '';
    _source = (credits?['source'] as String?) ?? '';

    final spriteSheet = parsed['spriteSheet'] as Map<String, dynamic>?;

    if (spriteSheet == null) {
      debugPrint('Invalid character info JSON: missing spriteSheet');
      return;
    }

    final idleAsset = '$root/${spriteSheet['idle']?['imagePath']}';
    final walkAsset = '$root/${spriteSheet['walk']?['imagePath']}';

    final idleInfo = spriteSheet['idle'] as Map<String, dynamic>?;
    final walkInfo = spriteSheet['walk'] as Map<String, dynamic>?;

    _idleImage ??= (await _engine.assets.loadImage(idleAsset)).image!;
    _walkImage ??= (await _engine.assets.loadImage(walkAsset)).image!;

    _idleFrames = _buildFrames(
      frameWidth: idleInfo?['frameWidth'] as int,
      frameHeight: idleInfo?['frameHeight'] as int,
      frameCount: idleInfo?['frameCount'] as int,
      linear: idleInfo?['linear'] as bool? ?? true,
      imageWidth: _idleImage!.width,
      imageHeight: _idleImage!.height,
    );

    _walkFrames = _buildFrames(
      frameWidth: walkInfo?['frameWidth'] as int,
      frameHeight: walkInfo?['frameHeight'] as int,
      frameCount: walkInfo?['frameCount'] as int,
      linear: walkInfo?['linear'] as bool? ?? true,
      imageWidth: _walkImage!.width,
      imageHeight: _walkImage!.height,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
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
      return frames;
    }

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

    return frames;
  }

  void _onTick(Duration elapsed) {
    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      return;
    }

    final dt = (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;

    _engine.world.update(dt);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _world.destroyAllEntities();
    super.dispose();
  }

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

  void _rebuildAnimationShowcase() {
    if (_loading || _idleImage == null || _walkImage == null) return;

    _viewportSize = _readViewportSize();
    if (_viewportSize == Size.zero) return;

    _engine.rendering.camera.viewportSize = _viewportSize;
    _engine.rendering.camera.position = Offset.zero;
    _engine.rendering.camera.rotation = 0;
    _engine.rendering.camera.zoom = 1;

    _clearWorld();

    _world.addSystem(_SpriteAnimationSystem()..priority = 90);
    _world.addSystem(_FloatSystem()..priority = 80);
    _world.addSystem(_CameraAwareRenderSystem(_engine.rendering.camera));

    _createBackdrop();
    _createCharacters();
    _createLabels();

    setState(() {});
  }

  void _createBackdrop() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -20,
          onRender: (canvas, size) {
            final gridPaint = Paint()
              ..color = const Color(0xFF1A2E40).withValues(alpha: 0.35)
              ..strokeWidth = 1;

            for (double x = -900; x <= 900; x += 72) {
              canvas.drawLine(Offset(x, -700), Offset(x, 700), gridPaint);
            }
            for (double y = -700; y <= 700; y += 72) {
              canvas.drawLine(Offset(-900, y), Offset(900, y), gridPaint);
            }

            final stagePaint = Paint()
              ..color = const Color(0xFF223349).withValues(alpha: 0.45);
            canvas.drawRect(
              Rect.fromCenter(
                center: const Offset(0, 120),
                width: 1200,
                height: 180,
              ),
              stagePaint,
            );
          },
        ),
      ),
    ], name: 'backdrop');
  }

  void _createCharacters() {
    final rows = (_characterCount / 6).ceil();
    final cols = (_characterCount / rows).ceil();

    const spacingX = 120.0;
    const spacingY = 130.0;

    final startX = -((cols - 1) * spacingX) / 2;
    final startY = -30.0;

    for (int i = 0; i < _characterCount; i++) {
      final row = i ~/ cols;
      final col = i % cols;

      final pos = Offset(startX + col * spacingX, startY + row * spacingY);

      final sprite = Sprite(
        image: _useWalkAnimation ? _walkImage : _idleImage,
        sourceRect: _useWalkAnimation ? _walkFrames.first : _idleFrames.first,
        renderSize: const Size(92, 112),
        layer: 6,
      );

      final idleAnimation = SpriteAnimation(
        sprite: sprite,
        frames: _idleFrames,
        duration: 1.0,
        loop: true,
      );

      final walkAnimation = SpriteAnimation(
        sprite: sprite,
        frames: _walkFrames,
        duration: 1.0,
        loop: true,
      );

      _world.createEntityWithComponents([
        TransformComponent(position: pos),
        RenderableComponent(renderable: sprite),
        _SpriteAnimationComponent(
          idleAnimation: idleAnimation,
          walkAnimation: walkAnimation,
          useWalk: _useWalkAnimation,
          playbackSpeed: _playbackSpeed,
        ),
        _FloatComponent(
          origin: pos,
          amplitudeY: 8 + _random.nextDouble() * 8,
          speed: 1.2 + _random.nextDouble() * 0.8,
          phase: _random.nextDouble() * math.pi * 2,
        ),
      ], name: 'character-$i');
    }
  }

  void _createLabels() {
    final clipName = _useWalkAnimation ? 'Walk' : 'Idle';
    final frameInfo = _useWalkAnimation
        ? '45x58 • 24 frames • linear:false'
        : '46x55 • 10 frames • linear:true';

    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, -220)),
      RenderableComponent(
        renderable: TextRenderable(
          text: 'Clip: $clipName   •   $frameInfo',
          textStyle: const TextStyle(
            color: Color(0xFF9DD9D2),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          layer: 30,
        ),
      ),
    ], name: 'clip-meta');

    _world.createEntityWithComponents([
      TransformComponent(position: const Offset(0, -190)),
      RenderableComponent(
        renderable: TextRenderable(
          text: 'Credit: $_artist   •   Source: $_source',
          textStyle: const TextStyle(
            color: Color(0xFF9DD9D2),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          layer: 30,
        ),
      ),
    ], name: 'credit');
  }

  int get _animatedEntityCount =>
      _world.query([_SpriteAnimationComponent]).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: const Color(0xFF101925),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Animation System Showcase',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _loading
                    ? 'Loading character01 sprite sheets...'
                    : 'Animated characters: $_animatedEntityCount',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Idle'),
                        icon: Icon(Icons.accessibility_new),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Walk'),
                        icon: Icon(Icons.directions_walk),
                      ),
                    ],
                    selected: {_useWalkAnimation},
                    onSelectionChanged: _loading
                        ? null
                        : (selection) {
                            setState(() {
                              _useWalkAnimation = selection.first;
                            });
                            _rebuildAnimationShowcase();
                          },
                  ),
                  Expanded(
                    child: Slider(
                      value: _characterCount.toDouble(),
                      min: 1,
                      max: 36,
                      divisions: 35,
                      label: '$_characterCount',
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() {
                                _characterCount = value.round();
                              });
                            },
                      onChangeEnd: _loading
                          ? null
                          : (_) => _rebuildAnimationShowcase(),
                    ),
                  ),
                  const Text('Count', style: TextStyle(color: Colors.white)),
                ],
              ),
              Row(
                children: [
                  const Text('Speed', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: _playbackSpeed,
                      min: 0.2,
                      max: 3.0,
                      divisions: 28,
                      label: _playbackSpeed.toStringAsFixed(2),
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() {
                                _playbackSpeed = value;
                              });
                            },
                      onChangeEnd: _loading
                          ? null
                          : (_) => _rebuildAnimationShowcase(),
                    ),
                  ),
                  FilledButton(
                    onPressed: _loading ? null : _rebuildAnimationShowcase,
                    child: const Text('Respawn'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
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
      ],
    );
  }
}

class _SpriteAnimationComponent extends Component {
  _SpriteAnimationComponent({
    required this.idleAnimation,
    required this.walkAnimation,
    required this.useWalk,
    required this.playbackSpeed,
  });

  final SpriteAnimation idleAnimation;
  final SpriteAnimation walkAnimation;
  bool useWalk;
  double playbackSpeed;
}

class _FloatComponent extends Component {
  _FloatComponent({
    required this.origin,
    required this.amplitudeY,
    required this.speed,
    required this.phase,
  });

  final Offset origin;
  final double amplitudeY;
  final double speed;
  final double phase;
  double time = 0;
}

class _SpriteAnimationSystem extends System {
  @override
  List<Type> get requiredComponents => [_SpriteAnimationComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final anim = entity.getComponent<_SpriteAnimationComponent>()!;
      final active = anim.useWalk ? anim.walkAnimation : anim.idleAnimation;

      active.speed = anim.playbackSpeed;
      active.update(dt);
    });
  }
}

class _FloatSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _FloatComponent];

  @override
  void update(double dt) {
    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final float = entity.getComponent<_FloatComponent>()!;

      float.time += dt;
      final wave = math.sin(float.phase + float.time * float.speed);
      transform.position = Offset(
        float.origin.dx,
        float.origin.dy + wave * float.amplitudeY,
      );
    });
  }
}

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
