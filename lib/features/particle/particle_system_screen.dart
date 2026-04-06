import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_game_engine/just_game_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo enum
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  presets,
  advanced,
  impact,
  forces,
  renderers,
  subEmitters,
  customEffects,
  interactive;

  String get label => switch (this) {
    presets => 'Classic Presets',
    advanced => 'Advanced Presets',
    impact => 'Impact Effects',
    forces => 'Force Fields',
    renderers => 'Renderer Types',
    subEmitters => 'Sub-Emitters',
    customEffects => 'Custom Effects',
    interactive => 'Interactive',
  };

  IconData get icon => switch (this) {
    presets => Icons.local_fire_department,
    advanced => Icons.auto_fix_high,
    impact => Icons.electric_bolt,
    forces => Icons.waves,
    renderers => Icons.format_shapes,
    subEmitters => Icons.device_hub,
    customEffects => Icons.code,
    interactive => Icons.touch_app,
  };

  Color get accentColor => switch (this) {
    presets => const Color(0xFFFF6B35),
    advanced => const Color(0xFFAB47BC),
    impact => const Color(0xFFFF5252),
    forces => const Color(0xFF29B6F6),
    renderers => const Color(0xFFFFCA28),
    subEmitters => const Color(0xFF66BB6A),
    customEffects => const Color(0xFFEC407A),
    interactive => const Color(0xFF26A69A),
  };

  String get description => switch (this) {
    presets =>
      'Five classic presets running simultaneously (fire, smoke, sparkle, rain, '
          'snow). Tap the canvas anywhere to spawn a random explosion.',
    advanced =>
      'Advanced presets with complex force combinations: Portal (vortex + '
          'attractor), Magic, Electric sparks (LineRenderer streak), Heal aura, '
          'Lava embers.',
    impact =>
      'One-shot burst effects — confetti, blood splatter, dust kick, water splash. '
          'Tap anywhere on the canvas to trigger the selected impact preset.',
    forces =>
      'Force sandbox. Eight force types (Gravity, Wind, Attractor, Repeller, '
          'Vortex, Noise, Drag, Boundary) — toggle them on/off to observe '
          'real-time effects on the same particle stream.',
    renderers =>
      'Seven renderer types side-by-side: Circle, Square (rotatable), Triangle, '
          'Star, Line (motion streak), CustomPath (diamond), Text (emoji). '
          'SpriteParticleRenderer and AnimatedSpriteParticleRenderer require images.',
    subEmitters =>
      'Sub-emitter chaining. Firework spawns sparkle children when particles die '
          '(SubEmitterTrigger.onDeath). Comet spawns a smoke trail at 40% '
          'lifetime (SubEmitterTrigger.onLifetimeFraction).',
    customEffects =>
      'ParticleEffect API — implement onSpawn / onUpdate / onDeath for fully '
          'custom per-particle logic. Left: SpiralEffect stores orbit angle in '
          'customData and overrides onUpdate. Right: RainbowEffect randomizes '
          'colors on spawn.',
    interactive =>
      'Paint particles anywhere. Tap for a one-shot burst, drag to stream '
          'continuously. Switch between presets and combine effects.',
  };

  String get codeSnippet => switch (this) {
    presets =>
      '// Fire-and-forget preset:\n'
          'final fire = ParticleEffects.fire(position: Offset(0, 100));\n'
          'engine.rendering.addManagedEmitter(fire);\n\n'
          '// One-shot explosion (tap callback):\n'
          'final blast = ParticleEffects.explosion(\n'
          '  position: worldPos,\n'
          '  color: Colors.orange,\n'
          '  particleCount: 80,\n'
          ');\n'
          'engine.rendering.addManagedEmitter(blast);',
    advanced =>
      '// Portal vortex — vortex + attractor + drag:\n'
          'final portal = ParticleEffects.portal(position: Offset.zero);\n\n'
          '// Electric sparks with LineParticleRenderer:\n'
          'final sparks = ParticleEffects.electricSparks(\n'
          '  position: Offset(200, 0),\n'
          ');\n\n'
          '// Heal aura — gravity(up) + attractor + noise:\n'
          'final aura = ParticleEffects.healAura(\n'
          '  position: Offset(-200, 0),\n'
          ');\n\n'
          'for (final e in [portal, sparks, aura]) {\n'
          '  engine.rendering.addManagedEmitter(e);\n'
          '}',
    impact =>
      '// Colorful confetti with SquareParticleRenderer + _ConfettiEffect:\n'
          'final confetti = ParticleEffects.confetti(\n'
          '  position: tapPos, count: 80,\n'
          ');\n'
          'engine.rendering.addManagedEmitter(confetti);\n\n'
          '// Water splash with BoundaryForce.bounce:\n'
          'final splash = ParticleEffects.waterSplash(\n'
          '  position: tapPos,\n'
          '  floorY: tapPos.dy + 80,\n'
          ');\n'
          'engine.rendering.addManagedEmitter(splash);',
    forces =>
      '// Assemble forces at construction:\n'
          'final emitter = ParticleEmitter(\n'
          '  maxParticles: 300, emissionRate: 120,\n'
          '  forces: [\n'
          '    GravityForce(const Offset(0, 140)),\n'
          '    WindForce(strength: 80, turbulence: 40),\n'
          '    AttractorForce(center: Offset.zero,\n'
          '      strength: 200, radius: 200),\n'
          '    VortexForce(center: Offset.zero,\n'
          '      strength: 140, radius: 200),\n'
          '    BoundaryForce(\n'
          '      bounds: Rect.fromLTWH(-220,-180, 440, 360),\n'
          '      behavior: ParticleBoundaryBehavior.bounce,\n'
          '    ),\n'
          '  ],\n'
          ');\n'
          '// Toggle at runtime:\n'
          'emitter.addForce(noiseForce);\n'
          'emitter.removeForce(gravityForce);',
    renderers =>
      '// Built-in geometric renderers:\n'
          'renderer: CircleParticleRenderer()\n'
          'renderer: SquareParticleRenderer()   // rotatable\n'
          'renderer: TriangleParticleRenderer() // rotatable\n'
          'renderer: StarParticleRenderer()     // 5-pointed\n\n'
          '// Special renderers:\n'
          'renderer: LineParticleRenderer(strokeWidth: 2.0)\n'
          'renderer: CustomPathParticleRenderer(path: myPath)\n'
          'renderer: TextParticleRenderer(glyph: "snowflake")\n\n'
          '// Image-based (require ui.Image):\n'
          'renderer: SpriteParticleRenderer(image: atlas)\n'
          'renderer: AnimatedSpriteParticleRenderer(\n'
          '  sheet: atlas, frames: [...],\n'
          ')',
    subEmitters =>
      '// Spawn sparkle children when particles die:\n'
          'ParticleEmitter(\n'
          '  ...\n'
          '  subEmitters: [\n'
          '    SubEmitterConfig(\n'
          '      trigger: SubEmitterTrigger.onDeath,\n'
          '      maxInstances: 30,\n'
          '      factory: (pos) =>\n'
          '        ParticleEffects.sparkle(position: pos),\n'
          '    ),\n'
          '  ],\n'
          ');\n\n'
          '// Spawn smoke trail at 40% lifetime:\n'
          'SubEmitterConfig(\n'
          '  trigger: SubEmitterTrigger.onLifetimeFraction,\n'
          '  lifetimeFraction: 0.4,\n'
          '  factory: (pos) =>\n'
          '    ParticleEffects.smoke(position: pos),\n'
          ')',
    customEffects =>
      'class SpiralEffect extends ParticleEffect {\n'
          '  final Offset center;\n'
          '  const SpiralEffect(this.center);\n\n'
          '  @override\n'
          '  void onSpawn(Particle p, ParticleEmitter e) {\n'
          '    // Store initial orbit angle in customData\n'
          '    p.customData = math.atan2(\n'
          '      p.position.dy - center.dy,\n'
          '      p.position.dx - center.dx,\n'
          '    );\n'
          '  }\n\n'
          '  @override\n'
          '  void onUpdate(Particle p, double dt,\n'
          '      List<ParticleForce> forces) {\n'
          '    super.onUpdate(p, dt, forces); // ages particle\n'
          '    final a = (p.customData as double)\n'
          '        + dt * math.pi * (1.5 + p.normalizedLife);\n'
          '    p.customData = a;\n'
          '    final r = (1 - p.normalizedLife) * 100;\n'
          '    p.position = Offset(\n'
          '      center.dx + math.cos(a) * r,\n'
          '      center.dy + math.sin(a) * r,\n'
          '    );\n'
          '  }\n'
          '}',
    interactive =>
      '// Tap -> burst:\n'
          'final worldPos =\n'
          '  camera.screenToWorld(tapScreenPos);\n'
          'engine.rendering.addManagedEmitter(\n'
          '  ParticleEffects.explosion(\n'
          '    position: worldPos,\n'
          '    color: randomColor,\n'
          '    particleCount: 60,\n'
          '  ),\n'
          ');\n\n'
          '// Drag -> stream:\n'
          'final stream =\n'
          '  ParticleEffects.fire(position: dragWorldPos);\n'
          'engine.rendering.addManagedEmitter(stream);\n'
          '// On move: stream.position = newWorldPos;\n'
          '// On release: stream.isEmitting = false;',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Impact type
// ─────────────────────────────────────────────────────────────────────────────

enum _ImpactType {
  confetti,
  bloodSplatter,
  dustKick,
  waterSplash;

  String get label => switch (this) {
    confetti => 'Confetti',
    bloodSplatter => 'Blood Splatter',
    dustKick => 'Dust Kick',
    waterSplash => 'Water Splash',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom effect — spiral orbit using customData
// ─────────────────────────────────────────────────────────────────────────────

class _SpiralEffect extends ParticleEffect {
  final Offset center;
  const _SpiralEffect(this.center);

  @override
  void onSpawn(Particle particle, ParticleEmitter emitter) {
    particle.customData = math.atan2(
      particle.position.dy - center.dy,
      particle.position.dx - center.dx,
    );
  }

  @override
  void onUpdate(Particle particle, double dt, List<ParticleForce> forces) {
    super.onUpdate(particle, dt, forces);
    final angle =
        (particle.customData as double) +
        dt * math.pi * (1.5 + particle.normalizedLife);
    particle.customData = angle;
    final radius = (1.0 - particle.normalizedLife) * 100.0;
    particle.position = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom effect — rainbow spawn colors (extends onSpawn)
// ─────────────────────────────────────────────────────────────────────────────

class _RainbowEffect extends ParticleEffect {
  static final _rng = math.Random();
  static const _palette = [
    Color(0xFFF44336),
    Color(0xFFFF9800),
    Color(0xFFFFEB3B),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
  ];

  @override
  void onSpawn(Particle particle, ParticleEmitter emitter) {
    final c = _palette[_rng.nextInt(_palette.length)];
    particle.startColor = c;
    particle.endColor = c.withValues(alpha: 0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ParticleSystemScreen extends StatefulWidget {
  const ParticleSystemScreen({super.key});

  @override
  State<ParticleSystemScreen> createState() => _ParticleSystemScreenState();
}

class _ParticleSystemScreenState extends State<ParticleSystemScreen>
    with SingleTickerProviderStateMixin {
  // ── Engine ────────────────────────────────────────────────────────────────
  late final Engine _engine;
  late final World _world;
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;

  // ── UI state ──────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.presets;
  String _statusMessage = '';

  // ── Managed emitters ──────────────────────────────────────────────────────
  final List<ParticleEmitter> _emitters = [];

  // ── Forces demo ───────────────────────────────────────────────────────────
  ParticleEmitter? _forcesEmitter;

  final GravityForce _gravityForce = GravityForce(const Offset(0, 140));
  final WindForce _windForce = WindForce(
    direction: const Offset(1, 0),
    strength: 80,
    turbulence: 40,
  );
  final AttractorForce _attractorForce = AttractorForce(
    center: Offset.zero,
    strength: 200,
    radius: 200,
  );
  final RepellerForce _repellerForce = RepellerForce(
    center: Offset.zero,
    strength: 200,
    radius: 150,
  );
  final VortexForce _vortexForce = VortexForce(
    center: Offset.zero,
    strength: 140,
    radius: 200,
  );
  final NoiseForce _noiseForce = NoiseForce(
    strength: 120,
    scale: 0.008,
    speed: 1.5,
  );
  final DragForce _dragForce = DragForce(coefficient: 0.06);
  final BoundaryForce _boundaryForce = BoundaryForce(
    bounds: const Rect.fromLTWH(-220, -180, 440, 360),
    behavior: ParticleBoundaryBehavior.bounce,
    restitution: 0.6,
  );
  final Set<String> _activeForces = {};

  // ── Impact demo ───────────────────────────────────────────────────────────
  _ImpactType _selectedImpact = _ImpactType.confetti;

  // ── Sub-emitter demo ──────────────────────────────────────────────────────
  bool _fireworkReady = true;
  bool _cometReady = true;

  // ── Interactive demo ──────────────────────────────────────────────────────
  int _interactivePreset = 0;
  ParticleEmitter? _streamEmitter;

  static const _kInteractiveLabels = [
    'Explosion',
    'Fire',
    'Magic',
    'Confetti',
    'Electric',
  ];

  final math.Random _rng = math.Random();

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _world = _engine.world;
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildDemo(_demo));
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final e in _emitters) {
      _engine.rendering.removeManagedEmitter(e);
    }
    _world.destroyAllEntities();
    _world.clearSystems();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tick
  // ─────────────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1_000_000.0;
    _lastTick = elapsed;
    _world.update(dt);
    _engine.rendering.updateManagedEmitters(dt);
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo management
  // ─────────────────────────────────────────────────────────────────────────

  void _clearDemo() {
    for (final e in _emitters) {
      _engine.rendering.removeManagedEmitter(e);
    }
    _emitters.clear();
    _world.destroyAllEntities();
    _world.clearSystems();
    _forcesEmitter = null;
    _activeForces.clear();
    _streamEmitter = null;
    _fireworkReady = true;
    _cometReady = true;
    _statusMessage = '';
    _engine.rendering.camera.reset();
  }

  void _buildDemo(_Demo demo) {
    _clearDemo();
    _demo = demo;
    _world.addSystem(RenderSystem(camera: _engine.rendering.camera));
    _spawnBackgroundGrid();
    switch (demo) {
      case _Demo.presets:
        _buildPresets();
      case _Demo.advanced:
        _buildAdvanced();
      case _Demo.impact:
        _buildImpact();
      case _Demo.forces:
        _buildForces();
      case _Demo.renderers:
        _buildRenderers();
      case _Demo.subEmitters:
        _buildSubEmitters();
      case _Demo.customEffects:
        _buildCustomEffects();
      case _Demo.interactive:
        _buildInteractive();
    }
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _spawnBackgroundGrid() {
    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -20,
          getBoundsCallback: () => const Rect.fromLTWH(-900, -600, 1800, 1200),
          onRender: (canvas, _) {
            final gridPaint = Paint()
              ..color = const Color(0xFF1A2535)
              ..strokeWidth = 1.0;
            for (double x = -900; x <= 900; x += 80) {
              canvas.drawLine(Offset(x, -600), Offset(x, 600), gridPaint);
            }
            for (double y = -600; y <= 600; y += 80) {
              canvas.drawLine(Offset(-900, y), Offset(900, y), gridPaint);
            }
            final crossPaint = Paint()
              ..color = const Color(0xFF2A3F55)
              ..strokeWidth = 2.0;
            canvas.drawLine(
              const Offset(-24, 0),
              const Offset(24, 0),
              crossPaint,
            );
            canvas.drawLine(
              const Offset(0, -24),
              const Offset(0, 24),
              crossPaint,
            );
          },
        ),
      ),
    ], name: 'grid');
  }

  ParticleEmitter _addEmitter(ParticleEmitter emitter) {
    _emitters.add(emitter);
    _engine.rendering.addManagedEmitter(emitter);
    return emitter;
  }

  void _addLabel(
    Offset pos,
    String text, {
    Color color = const Color(0xFFCEB8FF),
    double fontSize = 12,
  }) {
    _world.createEntityWithComponents([
      TransformComponent(position: pos),
      RenderableComponent(
        renderable: TextRenderable(
          text: text,
          textStyle: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
          layer: 30,
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Classic Presets
  // ─────────────────────────────────────────────────────────────────────────

  static const _kPresetPositions = <Offset>[
    Offset(-280, 60),
    Offset(-140, 60),
    Offset(0, 10),
    Offset(140, -200),
    Offset(280, -200),
  ];

  void _buildPresets() {
    _addEmitter(ParticleEffects.fire(position: _kPresetPositions[0]));
    _addEmitter(ParticleEffects.smoke(position: _kPresetPositions[1]));
    _addEmitter(ParticleEffects.sparkle(position: _kPresetPositions[2]));
    _addEmitter(
      ParticleEffects.rain(position: _kPresetPositions[3], width: 280),
    );
    _addEmitter(ParticleEffects.snow(position: _kPresetPositions[4]));

    const names = ['fire', 'smoke', 'sparkle', 'rain', 'snow'];
    for (var i = 0; i < names.length; i++) {
      final emitsDown = i >= 3;
      final labelY = emitsDown
          ? _kPresetPositions[i].dy - 32
          : _kPresetPositions[i].dy + 130;
      _addLabel(Offset(_kPresetPositions[i].dx, labelY), names[i]);
    }
    _statusMessage = 'Tap the canvas to spawn explosions';
  }

  void _spawnExplosion(Offset worldPos) {
    const colors = [
      Colors.orange,
      Colors.red,
      Colors.yellow,
      Colors.deepOrange,
      Colors.purple,
      Colors.cyanAccent,
    ];
    final color = colors[_rng.nextInt(colors.length)];
    _addEmitter(
      ParticleEffects.explosion(
        position: worldPos,
        color: color,
        particleCount: 60 + _rng.nextInt(60),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Advanced Presets
  // ─────────────────────────────────────────────────────────────────────────

  static const _kAdvancedPositions = <Offset>[
    Offset(-280, 0),
    Offset(-140, 0),
    Offset(0, 0),
    Offset(140, 0),
    Offset(280, -20),
  ];

  void _buildAdvanced() {
    _addEmitter(ParticleEffects.portal(position: _kAdvancedPositions[0]));
    _addEmitter(
      ParticleEffects.magic(
        position: _kAdvancedPositions[1],
        color: Colors.cyanAccent,
      ),
    );
    _addEmitter(
      ParticleEffects.electricSparks(position: _kAdvancedPositions[2]),
    );
    _addEmitter(ParticleEffects.healAura(position: _kAdvancedPositions[3]));
    _addEmitter(ParticleEffects.lavaEmbers(position: _kAdvancedPositions[4]));

    const names = [
      'portal',
      'magic',
      'elec. sparks',
      'heal aura',
      'lava embers',
    ];
    for (var i = 0; i < names.length; i++) {
      _addLabel(
        Offset(_kAdvancedPositions[i].dx, _kAdvancedPositions[i].dy + 120),
        names[i],
      );
    }
    _statusMessage = '5 advanced presets running simultaneously';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Impact Effects
  // ─────────────────────────────────────────────────────────────────────────

  void _buildImpact() {
    _statusMessage = 'Tap the canvas to trigger ${_selectedImpact.label}';
  }

  void _spawnImpact(Offset worldPos) {
    final emitter = switch (_selectedImpact) {
      _ImpactType.confetti => ParticleEffects.confetti(
        position: worldPos,
        count: 80,
      ),
      _ImpactType.bloodSplatter => ParticleEffects.bloodSplatter(
        position: worldPos,
        count: 60,
        boundsBottom: worldPos.dy + 120,
      ),
      _ImpactType.dustKick => ParticleEffects.dustKick(
        position: worldPos,
        direction: 1.0,
      ),
      _ImpactType.waterSplash => ParticleEffects.waterSplash(
        position: worldPos,
        floorY: worldPos.dy + 90,
      ),
    };
    _addEmitter(emitter);
    setState(
      () => _statusMessage =
          '${_selectedImpact.label} at '
          '(${worldPos.dx.toStringAsFixed(0)}, '
          '${worldPos.dy.toStringAsFixed(0)})',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Force Fields
  // ─────────────────────────────────────────────────────────────────────────

  void _buildForces() {
    final emitter = ParticleEmitter(
      position: Offset.zero,
      maxParticles: 300,
      emissionRate: 100,
      particleLifetime: 4.0,
      lifetimeVariation: 1.0,
      startSize: 6.0,
      endSize: 2.0,
      startColor: const Color(0xFF29B6F6),
      endColor: const Color(0x0029B6F6),
      emissionAngle: 0,
      emissionSpread: math.pi * 2,
      speed: 80,
      speedVariation: 40,
    );
    _forcesEmitter = emitter;
    _addEmitter(emitter);

    _world.createEntityWithComponents([
      TransformComponent(),
      RenderableComponent(
        syncTransform: false,
        renderable: CustomRenderable(
          layer: -10,
          getBoundsCallback: () => const Rect.fromLTWH(-230, -190, 460, 380),
          onRender: (canvas, _) {
            canvas.drawRect(
              const Rect.fromLTWH(-220, -180, 440, 360),
              Paint()
                ..color = const Color(0xFF29B6F6).withValues(alpha: 0.08)
                ..style = PaintingStyle.fill,
            );
            canvas.drawRect(
              const Rect.fromLTWH(-220, -180, 440, 360),
              Paint()
                ..color = const Color(0xFF29B6F6).withValues(alpha: 0.4)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          },
        ),
      ),
    ], name: 'boundary-hint');

    _statusMessage = 'Toggle forces to observe particle behavior';
  }

  bool _isForceActive(String id) => _activeForces.contains(id);

  void _toggleForce(String id) {
    final emitter = _forcesEmitter;
    if (emitter == null) return;
    final force = _forceById(id);
    if (_activeForces.contains(id)) {
      _activeForces.remove(id);
      emitter.removeForce(force);
    } else {
      _activeForces.add(id);
      emitter.addForce(force);
    }
    setState(() {});
  }

  ParticleForce _forceById(String id) => switch (id) {
    'gravity' => _gravityForce,
    'wind' => _windForce,
    'attractor' => _attractorForce,
    'repeller' => _repellerForce,
    'vortex' => _vortexForce,
    'noise' => _noiseForce,
    'drag' => _dragForce,
    'boundary' => _boundaryForce,
    _ => throw ArgumentError('Unknown force: $id'),
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Renderer Types
  // ─────────────────────────────────────────────────────────────────────────

  static const _kRendererPositions = <Offset>[
    Offset(-360, 0),
    Offset(-240, 0),
    Offset(-120, 0),
    Offset(0, 0),
    Offset(120, 0),
    Offset(240, 0),
    Offset(360, 0),
  ];

  void _buildRenderers() {
    final diamondPath = Path()
      ..moveTo(0, -0.5)
      ..lineTo(0.42, 0)
      ..lineTo(0, 0.5)
      ..lineTo(-0.42, 0)
      ..close();

    final renderers = <ParticleRenderer>[
      CircleParticleRenderer(),
      SquareParticleRenderer(),
      TriangleParticleRenderer(),
      StarParticleRenderer(),
      LineParticleRenderer(strokeWidth: 2.0),
      CustomPathParticleRenderer(path: diamondPath),
      TextParticleRenderer(glyph: '\u2744'),
    ];

    const labels = [
      'Circle',
      'Square',
      'Triangle',
      'Star',
      'Line\n(streak)',
      'CustomPath\n(diamond)',
      'Text\n(snowflake)',
    ];

    final accent = _Demo.renderers.accentColor;
    for (var i = 0; i < renderers.length; i++) {
      final pos = _kRendererPositions[i];
      final startSize = i == 6 ? 20.0 : 10.0;
      _addEmitter(
        ParticleEmitter(
          position: pos,
          maxParticles: 60,
          emissionRate: 25,
          particleLifetime: 2.0,
          lifetimeVariation: 0.5,
          startSize: startSize,
          endSize: 3.0,
          startColor: accent,
          endColor: accent.withValues(alpha: 0),
          emissionAngle: -math.pi / 2,
          emissionSpread: math.pi / 3,
          speed: 60,
          speedVariation: 20,
          angularVelocity: i < 5 ? math.pi : 0,
          angularVelocityVariation: math.pi * 0.5,
          renderer: renderers[i],
          forces: [
            GravityForce(const Offset(0, 40)),
            DragForce(coefficient: 0.05),
          ],
        ),
      );
      _addLabel(Offset(pos.dx, pos.dy + 95), labels[i], fontSize: 11);
    }
    _statusMessage =
        '7 of 9 renderers shown  (SpriteParticleRenderer and '
        'AnimatedSpriteParticleRenderer require a loaded ui.Image)';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sub-Emitters
  // ─────────────────────────────────────────────────────────────────────────

  void _buildSubEmitters() {
    _addLabel(
      const Offset(-180, -210),
      'Firework\nonDeath -> sparkle',
      color: _Demo.subEmitters.accentColor,
    );
    _addLabel(
      const Offset(160, -210),
      'Comet\nonLifetimeFraction -> smoke',
      color: const Color(0xFFFFCA28),
    );
    _statusMessage = 'Tap buttons to launch effects';
  }

  void _launchFirework() {
    if (!_fireworkReady) return;
    setState(() => _fireworkReady = false);
    final emitter = ParticleEmitter(
      position: const Offset(-180, 120),
      maxParticles: 30,
      emissionRate: 0,
      particleLifetime: 1.8,
      lifetimeVariation: 0.3,
      startSize: 8.0,
      endSize: 2.0,
      startColor: Colors.yellow,
      endColor: Colors.orange.withValues(alpha: 0),
      emissionAngle: -math.pi / 2,
      emissionSpread: math.pi / 5,
      speed: 210,
      speedVariation: 70,
      forces: [
        GravityForce(const Offset(0, 120)),
        DragForce(coefficient: 0.04),
      ],
      subEmitters: [
        SubEmitterConfig(
          trigger: SubEmitterTrigger.onDeath,
          maxInstances: 30,
          factory: (pos) => ParticleEffects.sparkle(position: pos),
        ),
      ],
    );
    emitter.burst(25);
    _addEmitter(emitter);
    setState(() {
      _statusMessage =
          'Firework launched — sparkle sub-emitters triggered on particle death';
      _fireworkReady = true;
    });
  }

  void _launchComet() {
    if (!_cometReady) return;
    setState(() => _cometReady = false);
    final emitter = ParticleEmitter(
      position: const Offset(160, 80),
      maxParticles: 20,
      emissionRate: 0,
      particleLifetime: 2.2,
      lifetimeVariation: 0.2,
      startSize: 12.0,
      endSize: 5.0,
      startColor: Colors.cyanAccent,
      endColor: Colors.blue.withValues(alpha: 0),
      emissionAngle: math.pi / 4,
      emissionSpread: math.pi / 8,
      speed: 180,
      speedVariation: 30,
      forces: [GravityForce(const Offset(0, 80)), DragForce(coefficient: 0.04)],
      subEmitters: [
        SubEmitterConfig(
          trigger: SubEmitterTrigger.onLifetimeFraction,
          lifetimeFraction: 0.4,
          maxInstances: 20,
          factory: (pos) => ParticleEffects.smoke(position: pos),
        ),
      ],
    );
    emitter.burst(15);
    _addEmitter(emitter);
    setState(() {
      _statusMessage =
          'Comet launched — smoke sub-emitter spawned at 40% particle lifetime';
      _cometReady = true;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Custom Effects
  // ─────────────────────────────────────────────────────────────────────────

  static const _kSpiralCenter = Offset(-150, 0);
  static const _kRainbowCenter = Offset(150, 0);

  void _buildCustomEffects() {
    final accent = _Demo.customEffects.accentColor;
    _addEmitter(
      ParticleEmitter(
        position: _kSpiralCenter,
        maxParticles: 100,
        emissionRate: 40,
        particleLifetime: 2.5,
        lifetimeVariation: 0.4,
        startSize: 8.0,
        endSize: 2.0,
        startColor: accent,
        endColor: accent.withValues(alpha: 0),
        emissionAngle: 0,
        emissionSpread: math.pi * 2,
        speed: 60,
        speedVariation: 20,
        effect: const _SpiralEffect(_kSpiralCenter),
        forces: [DragForce(coefficient: 0.01)],
      ),
    );
    _addEmitter(
      ParticleEmitter(
        position: _kRainbowCenter,
        maxParticles: 140,
        emissionRate: 55,
        particleLifetime: 3.0,
        lifetimeVariation: 0.6,
        startSize: 10.0,
        endSize: 3.0,
        startColor: Colors.white,
        endColor: Colors.transparent,
        emissionAngle: -math.pi / 2,
        emissionSpread: math.pi,
        speed: 120,
        speedVariation: 60,
        angularVelocity: math.pi * 2,
        angularVelocityVariation: math.pi * 3,
        renderer: SquareParticleRenderer(),
        effect: _RainbowEffect(),
        forces: [
          GravityForce(const Offset(0, 80)),
          DragForce(coefficient: 0.06),
        ],
      ),
    );
    _addLabel(
      Offset(_kSpiralCenter.dx, _kSpiralCenter.dy - 155),
      'SpiralEffect\n(orbit via customData)',
      color: accent,
    );
    _addLabel(
      Offset(_kRainbowCenter.dx, _kRainbowCenter.dy - 155),
      'RainbowEffect\n(random onSpawn colors)',
      color: accent,
    );
    _statusMessage = 'Both emitters use custom ParticleEffect subclasses';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Interactive
  // ─────────────────────────────────────────────────────────────────────────

  void _buildInteractive() {
    _addLabel(
      const Offset(0, -220),
      'Tap to burst  \u00b7  Drag to stream',
      color: _Demo.interactive.accentColor,
      fontSize: 13,
    );
    _statusMessage = 'Select a preset below and tap / drag the canvas';
  }

  ParticleEmitter _buildInteractiveEmitter(Offset pos) {
    const colors = [
      Colors.orange,
      Colors.red,
      Colors.yellow,
      Colors.deepOrange,
      Colors.cyanAccent,
    ];
    return switch (_interactivePreset) {
      0 => ParticleEffects.explosion(
        position: pos,
        color: colors[_rng.nextInt(colors.length)],
        particleCount: 60,
      ),
      1 => ParticleEffects.fire(position: pos),
      2 => ParticleEffects.magic(position: pos, color: Colors.cyanAccent),
      3 => ParticleEffects.confetti(position: pos, count: 60),
      4 => ParticleEffects.electricSparks(position: pos),
      _ => ParticleEffects.explosion(
        position: pos,
        color: Colors.orange,
        particleCount: 50,
      ),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pointer handling
  // ─────────────────────────────────────────────────────────────────────────

  void _handlePointerDown(Offset screenPos) {
    final worldPos = _engine.rendering.camera.screenToWorld(screenPos);
    switch (_demo) {
      case _Demo.presets:
        _spawnExplosion(worldPos);
      case _Demo.impact:
        _spawnImpact(worldPos);
      case _Demo.interactive:
        final isOneShot = _interactivePreset == 0 || _interactivePreset == 3;
        final emitter = _buildInteractiveEmitter(worldPos);
        _addEmitter(emitter);
        if (!isOneShot) {
          _streamEmitter = emitter;
        }
      default:
        break;
    }
  }

  void _handlePointerMove(Offset screenPos) {
    if (_demo != _Demo.interactive) return;
    final worldPos = _engine.rendering.camera.screenToWorld(screenPos);
    _streamEmitter?.position = worldPos;
  }

  void _handlePointerUp(Offset screenPos) {
    if (_streamEmitter != null) {
      _streamEmitter!.isEmitting = false;
      _streamEmitter = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stats
  // ─────────────────────────────────────────────────────────────────────────

  int get _totalParticleCount =>
      _emitters.fold(0, (total, e) => total + e.particleCount);

  // ─────────────────────────────────────────────────────────────────────────
  // UI build
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
                'ParticleEmitter  \u00b7  ParticleEffects  \u00b7  Forces',
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
            'particles: $_totalParticleCount  \u00b7  emitters: ${_emitters.length}',
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
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _handlePointerDown(e.localPosition),
      onPointerMove: (e) => _handlePointerMove(e.localPosition),
      onPointerUp: (e) => _handlePointerUp(e.localPosition),
      child: GameCameraControls(
        camera: _engine.rendering.camera,
        enablePan: false,
        enablePinch: true,
        showZoomLevel: true,
        child: GameWidget(engine: _engine, showFPS: true, showDebug: false),
      ),
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
    return switch (_demo) {
      _Demo.presets => _buildPresetsControls(),
      _Demo.advanced => _buildAdvancedControls(),
      _Demo.impact => _buildImpactControls(),
      _Demo.forces => _buildForcesControls(),
      _Demo.renderers => _buildRenderersControls(),
      _Demo.subEmitters => _buildSubEmittersControls(),
      _Demo.customEffects => _buildCustomEffectsControls(),
      _Demo.interactive => _buildInteractiveControls(),
    };
  }

  Widget _buildPresetsControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Text(
            'Tap canvas to spawn explosions',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const Spacer(),
          _actionButton(
            'Respawn All',
            _Demo.presets.accentColor,
            () => _buildDemo(_Demo.presets),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Text(
            'Portal  \u00b7  Magic  \u00b7  Electric sparks  \u00b7  Heal aura  \u00b7  Lava embers',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const Spacer(),
          _actionButton(
            'Restart',
            _Demo.advanced.accentColor,
            () => _buildDemo(_Demo.advanced),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Impact:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        for (final type in _ImpactType.values)
          _actionButton(
            type.label,
            _selectedImpact == type
                ? _Demo.impact.accentColor
                : const Color(0xFF2A4060),
            () {
              setState(() {
                _selectedImpact = type;
                _statusMessage = 'Tap the canvas to trigger ${type.label}';
              });
            },
          ),
      ],
    );
  }

  Widget _buildForcesControls() {
    const forceEntries = [
      ('gravity', 'Gravity \u2193'),
      ('wind', 'Wind \u2192'),
      ('attractor', 'Attractor'),
      ('repeller', 'Repeller'),
      ('vortex', 'Vortex'),
      ('noise', 'Noise'),
      ('drag', 'Drag'),
      ('boundary', 'Boundary'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Toggle:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        for (final (id, label) in forceEntries)
          _actionButton(
            label,
            _isForceActive(id)
                ? _Demo.forces.accentColor
                : const Color(0xFF2A4060),
            () => _toggleForce(id),
          ),
      ],
    );
  }

  Widget _buildRenderersControls() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Circle  \u00b7  Square  \u00b7  Triangle  \u00b7  Star  \u00b7  Line (streak)'
        '  \u00b7  CustomPath  \u00b7  Text (glyph)',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      ),
    );
  }

  Widget _buildSubEmittersControls() {
    return Row(
      children: [
        _actionButton(
          'Launch Firework',
          _Demo.subEmitters.accentColor,
          _fireworkReady ? _launchFirework : null,
        ),
        const SizedBox(width: 8),
        _actionButton(
          'Launch Comet',
          const Color(0xFFFFCA28),
          _cometReady ? _launchComet : null,
        ),
        const SizedBox(width: 10),
        const Flexible(
          child: Text(
            'Sub-emitters appear after the parent particles die / reach the fraction',
            style: TextStyle(color: Colors.white30, fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomEffectsControls() {
    return Row(
      children: [
        _actionButton(
          'Restart',
          _Demo.customEffects.accentColor,
          () => _buildDemo(_Demo.customEffects),
        ),
        const SizedBox(width: 12),
        const Flexible(
          child: Text(
            'Left: SpiralEffect  \u00b7  Right: RainbowEffect  — both extend ParticleEffect',
            style: TextStyle(color: Colors.white30, fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Preset:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        for (var i = 0; i < _kInteractiveLabels.length; i++)
          _actionButton(
            _kInteractiveLabels[i],
            _interactivePreset == i
                ? _Demo.interactive.accentColor
                : const Color(0xFF2A4060),
            () => setState(() => _interactivePreset = i),
          ),
        const SizedBox(width: 4),
        _actionButton('Clear', const Color(0xFF78909C), () {
          for (final e in List.of(_emitters)) {
            _engine.rendering.removeManagedEmitter(e);
          }
          _emitters.clear();
          _streamEmitter = null;
          setState(() => _statusMessage = 'Canvas cleared');
        }),
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
                  'just_game_engine \u00b7 Particle API',
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
