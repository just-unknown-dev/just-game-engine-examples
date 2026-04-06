import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

import '../../core/widgets/camera_zoom_controls.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo type
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  water,
  hitFlash,
  vertexWave;

  String get label => switch (this) {
    water => 'Water Ripple',
    hitFlash => 'Hit Flash',
    vertexWave => 'Vertex Wave',
  };

  IconData get icon => switch (this) {
    water => Icons.waves,
    hitFlash => Icons.local_fire_department,
    vertexWave => Icons.air,
  };

  Color get accentColor => switch (this) {
    water => const Color(0xFF29B6F6),
    hitFlash => const Color(0xFFFF5252),
    vertexWave => const Color(0xFF66BB6A),
  };

  String get shaderPath => switch (this) {
    water => 'assets/shaders/water_ripple.frag',
    hitFlash => 'assets/shaders/hit_flash.frag',
    vertexWave => 'assets/shaders/vertex_wave.frag',
  };

  String get description => switch (this) {
    water =>
      'UV distortion via overlapping sine waves simulates light refraction through water.',
    hitFlash =>
      'Blends sprite pixels toward white/red on damage — alpha silhouette preserved.',
    vertexWave =>
      'UV-displaced sampling fakes vertex displacement: tips sway, roots stay anchored.',
  };

  String codeSnippet({
    required double amplitude,
    required double frequency,
    required Color flashColor,
    required double strength,
    required double speed,
  }) => switch (this) {
    water =>
      '// Wave math runs in onRender (canvas) — per-entity ImageFilter\n'
          '// shaders receive screen-space FlutterFragCoord, so UV = fragCoord\n'
          '// / layerSize only works when the layer starts at (0,0) (fullscreen).\n'
          '// For world-space entities, use canvas-native distortion instead:\n\n'
          'onRender: (canvas, _) {\n'
          '  for (double y = top; y <= bottom; y += 14) {\n'
          '    final uvY = (y - top) / height;\n'
          '    final xOff = sin(uvY * ${frequency.toStringAsFixed(1)} + t * 2.0)\n'
          '               * ${amplitude.toStringAsFixed(3)} * width;\n'
          '    canvas.drawLine(Offset(left + xOff, y),\n'
          '                    Offset(right + xOff, y), paint);\n'
          '  }\n'
          '}',
    hitFlash =>
      '// Canvas saveLayer + BlendMode.srcATop replaces ShaderComponent.\n'
          '// Confines flash tint to the sprite silhouette — no GLSL UV issues.\n\n'
          'onRender: (canvas, _) {\n'
          '  canvas.saveLayer(localBounds, Paint());\n'
          '  paintSprite(canvas);\n'
          '  final i = entity.getComponent<FlashComponent>()?.intensity ?? 0.0;\n'
          '  if (i > 0.001) {\n'
          '    canvas.drawRect(\n'
          '      localBounds,\n'
          '      Paint()\n'
          '        ..color = Color.fromRGBO(${(flashColor.r * 255).round()},\n'
          '                               ${(flashColor.g * 255).round()},\n'
          '                               ${(flashColor.b * 255).round()}, i)\n'
          '        ..blendMode = BlendMode.srcATop,\n'
          '    );\n'
          '  }\n'
          '  canvas.restore();\n'
          '}',

    vertexWave =>
      '// Horizontal-slice canvas.translate replicates vertex_wave.frag:\n'
          '// each strip is offset by the same sine — roots stay anchored.\n\n'
          'for (double y = top; y < bottom; y += sliceH) {\n'
          '  final uvY = (y - top) / height;       // 0=tip, 1=root\n'
          '  final sway = sin(uvY * 3.8 + t * ${speed.toStringAsFixed(1)})\n'
          '             * ${strength.toStringAsFixed(3)} * (1 - uvY) * width;\n'
          '  canvas.save();\n'
          '  canvas.clipRect(Rect.fromLTWH(left, y, width, sliceH));\n'
          '  canvas.translate(sway, 0);\n'
          '  paintSprite(canvas);\n'
          '  canvas.restore();\n'
          '}',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ECS Components
// ─────────────────────────────────────────────────────────────────────────────

class _OrbitComponent extends Component {
  final Offset center;
  final double radius;
  final double speed;
  double angle;

  _OrbitComponent({
    required this.center,
    required this.radius,
    required this.speed,
    double startAngle = 0,
  }) : angle = startAngle;
}

class _BobComponent extends Component {
  final double originY;
  final double amplitude;
  final double speed;
  final double phase;
  double time = 0;

  _BobComponent({
    required this.originY,
    this.amplitude = 5.0,
    this.speed = 1.0,
    this.phase = 0.0,
  });
}

class _FlashComponent extends Component {
  double intensity;
  final double decayRate;

  _FlashComponent({this.intensity = 0.0, this.decayRate = 1.6});
}

// ─────────────────────────────────────────────────────────────────────────────
// ECS Systems
// ─────────────────────────────────────────────────────────────────────────────

class _OrbitSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _OrbitComponent];

  @override
  void update(double dt) {
    for (final e in entities) {
      if (!e.isActive) continue;
      final o = e.getComponent<_OrbitComponent>()!;
      o.angle += dt * o.speed;
      e.getComponent<TransformComponent>()!.position = Offset(
        o.center.dx + math.cos(o.angle) * o.radius,
        o.center.dy + math.sin(o.angle) * o.radius,
      );
    }
  }
}

class _BobSystem extends System {
  @override
  List<Type> get requiredComponents => [TransformComponent, _BobComponent];

  @override
  void update(double dt) {
    for (final e in entities) {
      if (!e.isActive) continue;
      final b = e.getComponent<_BobComponent>()!;
      b.time += dt;
      final t = e.getComponent<TransformComponent>()!;
      t.position = Offset(
        t.position.dx,
        b.originY + math.sin(b.time * b.speed + b.phase) * b.amplitude,
      );
    }
  }
}

class _FlashDecaySystem extends System {
  @override
  List<Type> get requiredComponents => [_FlashComponent];

  @override
  void update(double dt) {
    for (final e in entities) {
      if (!e.isActive) continue;
      final f = e.getComponent<_FlashComponent>()!;
      f.intensity = (f.intensity - f.decayRate * dt).clamp(0.0, 1.0);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class ShaderScreen extends StatefulWidget {
  const ShaderScreen({super.key});

  @override
  State<ShaderScreen> createState() => _ShaderScreenState();
}

class _ShaderScreenState extends State<ShaderScreen>
    with SingleTickerProviderStateMixin {
  // ── Engine ───────────────────────────────────────────────────────────────
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;
  double _elapsed = 0;

  // ── Shader programs ──────────────────────────────────────────────────────
  final Map<_Demo, ui.FragmentProgram?> _programs = {};
  final Map<_Demo, String> _loadErrors = {};
  bool _loadingComplete = false;

  // ── Demo state ───────────────────────────────────────────────────────────
  _Demo _activeDemo = _Demo.water;
  _Demo? _builtDemo;

  // ── Water params ─────────────────────────────────────────────────────────
  double _waterAmplitude = 0.015;
  double _waterFrequency = 15.0;

  // ── Hit-flash params ─────────────────────────────────────────────────────
  Color _flashColor = Colors.white;
  bool _autoFlash = true;
  double _autoFlashTimer = 0.0;
  static const _kFlashPeriod = 2.2;

  // ── Vertex-wave params ───────────────────────────────────────────────────
  double _waveStrength = 0.035;
  double _waveSpeed = 1.5;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadShaders());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _world.clearSystems();
    _world.destroyAllEntities();
    super.dispose();
  }

  // ─── Tick ─────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1_000_000.0;
    _lastTick = elapsed;
    _elapsed += dt;
    _world.update(dt);

    if (_activeDemo == _Demo.hitFlash && _autoFlash) {
      _autoFlashTimer += dt;
      if (_autoFlashTimer >= _kFlashPeriod) {
        _autoFlashTimer = 0;
        _triggerHitFlash();
      }
    }

    if (mounted) setState(() {});
  }

  // ─── Shader loading ───────────────────────────────────────────────────────

  Future<void> _loadShaders() async {
    for (final demo in _Demo.values) {
      try {
        _programs[demo] = await ui.FragmentProgram.fromAsset(demo.shaderPath);
      } catch (e) {
        _programs[demo] = null;
        _loadErrors[demo] = e.toString();
      }
    }
    if (!mounted) return;
    setState(() => _loadingComplete = true);
    _rebuildScene();
  }

  // ─── Scene management ─────────────────────────────────────────────────────

  void _triggerHitFlash() {
    for (final entity in _world.query([_FlashComponent])) {
      entity.getComponent<_FlashComponent>()!.intensity = 1.0;
    }
  }

  void _rebuildScene() {
    _world.destroyAllEntities();
    _world.clearSystems();
    _engine.rendering.camera
      ..setPosition(Offset.zero)
      ..setZoom(1.0)
      ..smoothing = false;
    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));
    switch (_activeDemo) {
      case _Demo.water:
        _buildWaterScene();
      case _Demo.hitFlash:
        _buildHitFlashScene();
      case _Demo.vertexWave:
        _buildVertexWaveScene();
    }
    _builtDemo = _activeDemo;
    _autoFlashTimer = 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Water scene
  // ─────────────────────────────────────────────────────────────────────────

  void _buildWaterScene() {
    _world.addSystem(_BobSystem()..priority = 65);
    _world.addSystem(_OrbitSystem()..priority = 70);

    _spawnWaterPool();
    _spawnFish();
    _spawnLilyPads();
  }

  void _spawnWaterPool() {
    // Root cause of GLSL-only approach failing for per-entity shaders:
    // canvas.saveLayer is called inside the camera transform (world space), so
    // the layer's top-left is NOT (0,0) in screen space. FlutterFragCoord()
    // returns screen-space pixels, meaning uv = fragCoord/uSize lands outside
    // [0,1] and clamp pins all samples to the pool edge (solid colour) — no
    // visible wave. Fix: drive the sine-wave math directly in onRender via
    // animated canvas.drawLine calls, then keep ShaderComponent for the
    // colour-tint overlay which works regardless of UV offset.
    const bounds = Rect.fromLTWH(-165, -115, 330, 230);

    final poolEntity = _world.createEntity(name: 'water_pool');
    poolEntity.addComponent(TransformComponent());
    poolEntity.addComponent(
      RenderableComponent(
        renderable: CustomRenderable(
          layer: 0,
          getBoundsCallback: () => bounds,
          onRender: (canvas, _) {
            final t = _elapsed;
            final bw = bounds.width;
            final bh = bounds.height;

            // Deep water base
            canvas.drawRect(bounds, Paint()..color = const Color(0xFF082240));

            // ── Animated horizontal grid lines ─────────────────────────────
            // Each line's X position is offset by the same sine formula as
            // water_ripple.frag, making the wave visible on canvas.
            final gridH = Paint()
              ..color = const Color(0xFF1A5090).withValues(alpha: 0.82)
              ..strokeWidth = 1.0;
            for (double y = bounds.top; y <= bounds.bottom; y += 14) {
              final uvY = (y - bounds.top) / bh;
              final xOff =
                  math.sin(uvY * _waterFrequency + t * 2.00) *
                      _waterAmplitude *
                      bw +
                  math.sin(uvY * _waterFrequency * 0.5 + t * 3.10) *
                      _waterAmplitude *
                      bw *
                      0.35;
              canvas.drawLine(
                Offset(bounds.left + xOff, y),
                Offset(bounds.right + xOff, y),
                gridH,
              );
            }

            // ── Animated vertical grid lines (segmented for wave shape) ───
            final gridV = Paint()
              ..color = const Color(0xFF1A5090).withValues(alpha: 0.55)
              ..strokeWidth = 0.8;
            for (double x = bounds.left; x <= bounds.right; x += 14) {
              for (double y = bounds.top; y < bounds.bottom - 3; y += 4) {
                final uvY = (y - bounds.top) / bh;
                final xOff =
                    math.sin(uvY * _waterFrequency + t * 2.00) *
                        _waterAmplitude *
                        bw +
                    math.sin(uvY * _waterFrequency * 0.5 + t * 3.10) *
                        _waterAmplitude *
                        bw *
                        0.35;
                canvas.drawLine(
                  Offset(x + xOff, y),
                  Offset(x + xOff, y + 3.5),
                  gridV,
                );
              }
            }

            // ── Animated caustic circles ────────────────────────────────────
            final causticPaint = Paint()
              ..color = const Color(0xFF3080C8).withValues(alpha: 0.52)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6;
            const causticBases = [
              (Offset(-55.0, -30.0), 38.0),
              (Offset(65.0, 18.0), 30.0),
              (Offset(-90.0, 50.0), 24.0),
              (Offset(25.0, -68.0), 48.0),
              (Offset(110.0, -45.0), 18.0),
            ];
            for (int i = 0; i < causticBases.length; i++) {
              final (c, r) = causticBases[i];
              final pulse = 1.0 + math.sin(t * 1.3 + i * 1.2) * 0.12;
              final dx = math.cos(t * 0.7 + i * 0.9) * 4.0;
              canvas.drawCircle(c + Offset(dx, 0), r * pulse, causticPaint);
            }

            // ── Sandy floor strip ───────────────────────────────────────────
            canvas.drawRect(
              Rect.fromLTWH(bounds.left, bounds.bottom - 48, bw, 48),
              Paint()..color = const Color(0xFF1E3A60).withValues(alpha: 0.55),
            );

            // ── Specular highlight band (scroll matches wave phase) ─────────
            final specY =
                bounds.top + (0.5 + 0.5 * math.sin(t * 1.8)) * bh * 0.6;
            final specPaint = Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF7FD8FF).withValues(alpha: 0.14),
                  Colors.transparent,
                ],
              ).createShader(Rect.fromLTWH(bounds.left, specY - 18, bw, 36));
            canvas.drawRect(
              Rect.fromLTWH(bounds.left, specY - 18, bw, 36),
              specPaint,
            );
          },
        ),
      ),
    );
  }

  void _spawnFish() {
    final rng = math.Random(1337);
    const colors = [
      Color(0xFFFF7043),
      Color(0xFFFFD54F),
      Color(0xFF80DEEA),
      Color(0xFFCE93D8),
      Color(0xFF80CBC4),
      Color(0xFFF48FB1),
    ];
    for (int i = 0; i < 6; i++) {
      final r = 50.0 + i * 22.0;
      final speed = (0.4 + rng.nextDouble() * 0.55) * (i.isEven ? 1 : -1);
      final color = colors[i];
      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 2,
            onRender: (canvas, _) {
              final p = Paint()..color = color.withValues(alpha: 0.92);
              canvas.drawOval(
                Rect.fromCenter(center: Offset.zero, width: 18, height: 8),
                p,
              );
              final tail = Path()
                ..moveTo(9, 0)
                ..lineTo(15, -5)
                ..lineTo(15, 5)
                ..close();
              canvas.drawPath(tail, p);
              canvas.drawCircle(
                const Offset(-4, -1),
                1.5,
                Paint()..color = Colors.black.withValues(alpha: 0.7),
              );
            },
          ),
        ),
        _OrbitComponent(
          center: Offset.zero,
          radius: r,
          speed: speed,
          startAngle: rng.nextDouble() * math.pi * 2,
        ),
      ]);
    }
  }

  void _spawnLilyPads() {
    final rng = math.Random(88);
    const pads = [
      (Offset(-95.0, -42.0), 14.0, Color(0xFF2E7D32)),
      (Offset(80.0, 30.0), 18.0, Color(0xFF388E3C)),
      (Offset(20.0, -80.0), 11.0, Color(0xFF1B5E20)),
    ];
    for (final (pos, r, color) in pads) {
      _world.createEntityWithComponents([
        TransformComponent(position: pos),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 3,
            onRender: (canvas, _) {
              canvas.drawCircle(Offset.zero, r, Paint()..color = color);
              final notch = Path()
                ..moveTo(0, 0)
                ..lineTo(r * 0.7, -r * 0.7)
                ..lineTo(r, 0);
              canvas.drawPath(
                notch,
                Paint()
                  ..color = const Color(0xFF04111F)
                  ..style = PaintingStyle.fill,
              );
              canvas.drawCircle(
                Offset.zero,
                r * 0.25,
                Paint()
                  ..color = const Color(0xFFFFEE58).withValues(alpha: 0.85),
              );
            },
          ),
        ),
        _BobComponent(
          originY: pos.dy,
          amplitude: 3.5 + rng.nextDouble() * 3,
          speed: 0.5 + rng.nextDouble() * 0.4,
          phase: rng.nextDouble() * math.pi * 2,
        ),
      ]);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hit-flash scene
  // ─────────────────────────────────────────────────────────────────────────

  void _buildHitFlashScene() {
    _world.addSystem(_FlashDecaySystem()..priority = 80);
    _world.addSystem(_OrbitSystem()..priority = 70);

    // _spawnArenaBackground();
    _spawnWarriors();
    _spawnProjectiles();
  }

  void _spawnWarriors() {
    const warriors = [
      (Offset(-155.0, 0.0), Color(0xFF1565C0), Color(0xFF42A5F5)),
      (Offset(0.0, 0.0), Color(0xFF6A1B9A), Color(0xFFAB47BC)),
      (Offset(155.0, 0.0), Color(0xFFB71C1C), Color(0xFFEF5350)),
    ];
    // Flash applied in onRender via saveLayer + BlendMode.srcATop.
    // Per-entity ShaderComponent removed: FlutterFragCoord UV fix.
    const localBounds = Rect.fromLTWH(-36, -69, 72, 114);

    for (final (pos, dark, light) in warriors) {
      final boundsRect = Rect.fromCenter(
        center: Offset(pos.dx, pos.dy - 12),
        width: 72,
        height: 114,
      );

      final entity = _world.createEntity();
      entity.addComponent(TransformComponent(position: pos));
      entity.addComponent(_FlashComponent(decayRate: 1.8));
      entity.addComponent(
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 2,
            getBoundsCallback: () => boundsRect,
            onRender: (canvas, _) {
              // Composite group: warrior drawn first, flash rect applied
              // above with srcATop to restrict the tint to opaque pixels.
              canvas.saveLayer(localBounds, Paint());
              _paintWarrior(canvas, dark, light);
              final intensity =
                  entity.getComponent<_FlashComponent>()?.intensity ?? 0.0;
              if (intensity > 0.001) {
                canvas.drawRect(
                  localBounds,
                  Paint()
                    ..color = _flashColor.withValues(alpha: intensity)
                    ..blendMode = BlendMode.srcATop,
                );
              }
              canvas.restore();
            },
          ),
        ),
      );
    }
  }

  void _paintWarrior(Canvas canvas, Color dark, Color light) {
    // Hexagonal torso
    final bodyPath = Path();
    for (int i = 0; i < 6; i++) {
      final a = i * math.pi / 3 - math.pi / 6;
      final p = Offset(math.cos(a) * 28.0, math.sin(a) * 28.0 + 10);
      if (i == 0)
        bodyPath.moveTo(p.dx, p.dy);
      else
        bodyPath.lineTo(p.dx, p.dy);
    }
    bodyPath.close();
    canvas.drawPath(bodyPath, Paint()..color = dark);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = light.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Head
    canvas.drawCircle(const Offset(0, -40), 18, Paint()..color = dark);
    // Helmet crest
    final crest = Path()
      ..moveTo(-14, -52)
      ..lineTo(0, -68)
      ..lineTo(14, -52)
      ..close();
    canvas.drawPath(crest, Paint()..color = light);
    // Eyes
    canvas.drawCircle(
      const Offset(-6, -42),
      3,
      Paint()..color = Colors.black54,
    );
    canvas.drawCircle(const Offset(6, -42), 3, Paint()..color = Colors.black54);
    // Belt
    canvas.drawRect(
      const Rect.fromLTWH(-28, -8, 56, 10),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    // Rune glow
    canvas.drawCircle(
      const Offset(0, 8),
      9,
      Paint()
        ..color = light.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _spawnProjectiles() {
    const orbits = [
      (Offset(-155.0, 0.0), 0.0),
      (Offset(0.0, 0.0), 2.1),
      (Offset(155.0, 0.0), 4.2),
    ];
    for (final (center, phase) in orbits) {
      _world.createEntityWithComponents([
        TransformComponent(),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 4,
            onRender: (canvas, _) {
              canvas.drawCircle(
                Offset.zero,
                7,
                Paint()..color = const Color(0xFFFFEE58).withValues(alpha: 0.9),
              );
              canvas.drawCircle(
                Offset.zero,
                11,
                Paint()
                  ..color = const Color(0xFFFFEE58).withValues(alpha: 0.35)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
              );
            },
          ),
        ),
        _OrbitComponent(
          center: center,
          radius: 55,
          speed: 1.6,
          startAngle: phase,
        ),
      ]);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Vertex-wave scene
  // ─────────────────────────────────────────────────────────────────────────

  void _buildVertexWaveScene() {
    _world.addSystem(_OrbitSystem()..priority = 70);
    _spawnTrees();
    _spawnWindHints();
  }

  void _spawnTrees() {
    const trees = [
      (Offset(-240.0, 80.0), Color(0xFF1B5E20), Color(0xFF2E7D32), 0.0),
      (Offset(-90.0, 80.0), Color(0xFF1A237E), Color(0xFF283593), 1.1),
      (Offset(70.0, 80.0), Color(0xFF004D40), Color(0xFF00695C), 2.3),
      (Offset(220.0, 80.0), Color(0xFF4A148C), Color(0xFF6A1B9A), 0.7),
    ];
    // Vertex wave applied via horizontal-slice canvas.translate.
    // Per-entity ShaderComponent removed: FlutterFragCoord UV fix.
    const localBounds = Rect.fromLTWH(-44, -130, 88, 130);
    const sliceH = 6.0;

    for (final (pos, dark, light, phase) in trees) {
      final boundsRect = Rect.fromCenter(
        center: Offset(pos.dx, pos.dy - 65),
        width: 88,
        height: 130,
      );

      _world.createEntityWithComponents([
        TransformComponent(position: pos),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 2,
            getBoundsCallback: () => boundsRect,
            onRender: (canvas, _) {
              // Each horizontal strip is translated by the same sine formula
              // as vertex_wave.frag: swayFactor = 1-uvY keeps roots anchored.
              for (
                double y = localBounds.top;
                y < localBounds.bottom;
                y += sliceH
              ) {
                final uvY = (y - localBounds.top) / localBounds.height;
                final swayFactor = 1.0 - uvY;
                final t = _elapsed + phase;
                final xOff =
                    math.sin(uvY * 3.8 + t * _waveSpeed) *
                        _waveStrength *
                        localBounds.width *
                        swayFactor +
                    math.cos(uvY * 2.4 + t * _waveSpeed * 0.55) *
                        _waveStrength *
                        localBounds.width *
                        swayFactor *
                        0.22;
                canvas.save();
                canvas.clipRect(
                  Rect.fromLTWH(localBounds.left, y, localBounds.width, sliceH),
                );
                canvas.translate(xOff, 0.0);
                _paintTree(canvas, dark, light);
                canvas.restore();
              }
            },
          ),
        ),
      ]);
    }
  }

  void _paintTree(Canvas canvas, Color dark, Color light) {
    // Trunk
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-7, -26, 14, 26),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF3E2723),
    );

    void drawLayer(double top, double bottom, double width, Color c) {
      final path = Path()
        ..moveTo(0, top)
        ..lineTo(-width / 2, bottom)
        ..lineTo(width / 2, bottom)
        ..close();
      canvas.drawPath(path, Paint()..color = c);
      canvas.drawPath(
        path,
        Paint()
          ..color = light.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    drawLayer(-128, -22, 80, dark);
    drawLayer(-108, -38, 62, dark.withValues(alpha: 0.90));
    drawLayer(-88, -58, 46, light.withValues(alpha: 0.85));
    drawLayer(-72, -76, 30, light);

    // Tip glow
    canvas.drawCircle(
      const Offset(0, -128),
      3.5,
      Paint()
        ..color = light.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _spawnWindHints() {
    final rng = math.Random(42);
    for (int i = 0; i < 10; i++) {
      final x = (rng.nextDouble() - 0.5) * 600;
      final y = -60 + rng.nextDouble() * 130.0;
      final len = 14.0 + rng.nextDouble() * 10;
      _world.createEntityWithComponents([
        TransformComponent(position: Offset(x, y)),
        RenderableComponent(
          renderable: CustomRenderable(
            layer: 5,
            onRender: (canvas, _) {
              canvas.drawLine(
                Offset.zero,
                Offset(len, 0),
                Paint()
                  ..color = Colors.white.withValues(alpha: 0.07)
                  ..strokeWidth = 1.0,
              );
            },
          ),
        ),
        _OrbitComponent(
          center: Offset(x - 300, y),
          radius: 300,
          speed: 0.08 + rng.nextDouble() * 0.04,
          startAngle: rng.nextDouble() * 0.2,
        ),
      ]);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Widget build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_loadingComplete) return _buildLoadingView();
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildCanvas()),
        _buildControlPanel(),
      ],
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF29B6F6)),
          SizedBox(height: 16),
          Text(
            'Compiling shaders…',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final active = _activeDemo;
    final hasError = _loadErrors.containsKey(active);

    return Container(
      color: const Color(0xFF080F1A),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(active.icon, color: active.accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Custom Shader API — ${active.label}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (hasError) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
                    'shader load failed — canvas fallback',
                    style: TextStyle(color: Colors.orange, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            active.description,
            style: TextStyle(
              color: active.accentColor.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Entities: ${_world.entities.length}   |   '
            'Systems: ${_world.systems.length}   |   '
            'Shader: ${_programs[active] != null ? "loaded ✓" : "unavailable"}   |   '
            'Zoom: ${_engine.rendering.camera.zoom.toStringAsFixed(2)}x',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Canvas ───────────────────────────────────────────────────────────────

  Widget _buildCanvas() {
    return CameraZoomControls(
      camera: _engine.rendering.camera,
      child: GameWidget(engine: _engine, showFPS: true, showDebug: false),
    );
  }

  // ── Control panel ────────────────────────────────────────────────────────

  Widget _buildControlPanel() {
    return Container(
      color: const Color(0xFF080F1A),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFF141E2D)),
          // Demo selector chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _Demo.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final demo = _Demo.values[i];
                final active = demo == _activeDemo;
                return FilterChip(
                  avatar: Icon(
                    demo.icon,
                    size: 14,
                    color: active ? demo.accentColor : Colors.white38,
                  ),
                  label: Text(
                    demo.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? Colors.white : Colors.white54,
                    ),
                  ),
                  selected: active,
                  showCheckmark: true,
                  checkmarkColor: demo.accentColor,
                  selectedColor: demo.accentColor.withValues(alpha: 0.18),
                  backgroundColor: const Color(0xFF111C2A),
                  side: BorderSide(
                    color: active
                        ? demo.accentColor.withValues(alpha: 0.65)
                        : const Color(0xFF1E2E40),
                  ),
                  onSelected: (_) {
                    if (demo == _activeDemo) return;
                    setState(() => _activeDemo = demo);
                    _rebuildScene();
                  },
                );
              },
            ),
          ),
          _buildDemoParams(),
          _buildCodeCard(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildDemoParams() => switch (_activeDemo) {
    _Demo.water => _buildWaterParams(),
    _Demo.hitFlash => _buildHitFlashParams(),
    _Demo.vertexWave => _buildVertexWaveParams(),
  };

  // ── Water params ─────────────────────────────────────────────────────────

  Widget _buildWaterParams() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: _buildSlider(
              label: 'Amplitude',
              value: _waterAmplitude,
              min: 0.005,
              max: 0.040,
              color: _Demo.water.accentColor,
              onChanged: (v) => setState(() => _waterAmplitude = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSlider(
              label: 'Frequency',
              value: _waterFrequency,
              min: 4.0,
              max: 32.0,
              color: _Demo.water.accentColor,
              onChanged: (v) => setState(() => _waterFrequency = v),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hit-flash params ─────────────────────────────────────────────────────

  Widget _buildHitFlashParams() {
    const presets = [
      ('White', Colors.white),
      ('Red', Color(0xFFFF1744)),
      ('Gold', Color(0xFFFFD600)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          for (final (lbl, color) in presets) ...[
            _buildFlashColorButton(lbl, color),
            const SizedBox(width: 6),
          ],
          const Spacer(),
          const Text(
            'Auto',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Switch(
            value: _autoFlash,
            activeColor: _Demo.hitFlash.accentColor,
            onChanged: (v) => setState(() {
              _autoFlash = v;
              _autoFlashTimer = 0;
            }),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Demo.hitFlash.accentColor.withValues(
                alpha: 0.25,
              ),
              foregroundColor: _Demo.hitFlash.accentColor,
              side: BorderSide(
                color: _Demo.hitFlash.accentColor.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.flash_on, size: 14),
            label: const Text('Hit!', style: TextStyle(fontSize: 12)),
            onPressed: _triggerHitFlash,
          ),
        ],
      ),
    );
  }

  Widget _buildFlashColorButton(String label, Color color) {
    final selected = _flashColor == color;
    return GestureDetector(
      onTap: () => setState(() => _flashColor = color),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected ? color : const Color(0xFF2A3A50),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Vertex-wave params ───────────────────────────────────────────────────

  Widget _buildVertexWaveParams() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: _buildSlider(
              label: 'Strength',
              value: _waveStrength,
              min: 0.005,
              max: 0.08,
              color: _Demo.vertexWave.accentColor,
              onChanged: (v) => setState(() => _waveStrength = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSlider(
              label: 'Speed',
              value: _waveSpeed,
              min: 0.3,
              max: 4.0,
              color: _Demo.vertexWave.accentColor,
              onChanged: (v) => setState(() => _waveSpeed = v),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────────────

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              value.toStringAsFixed(3),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.18),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.12),
            trackHeight: 2.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildCodeCard() {
    final active = _activeDemo;
    final snippet = active.codeSnippet(
      amplitude: _waterAmplitude,
      frequency: _waterFrequency,
      flashColor: _flashColor,
      strength: _waveStrength,
      speed: _waveSpeed,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1622),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active.accentColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(active.icon, size: 12, color: active.accentColor),
                const SizedBox(width: 6),
                Text(
                  active.label,
                  style: TextStyle(
                    color: active.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text(
                  'ShaderComponent  ·  per-entity via canvas.saveLayer',
                  style: TextStyle(color: Colors.white24, fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: SingleChildScrollView(
                child: Text(
                  snippet,
                  style: const TextStyle(
                    color: Color(0xFFB0C8E0),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
