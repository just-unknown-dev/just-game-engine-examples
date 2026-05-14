import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_debugger/just_debugger.dart';
import 'package:just_game_engine/just_game_engine.dart';

class _DebuggerOrbitComponent extends Component {
  _DebuggerOrbitComponent({
    required this.radius,
    required this.speed,
    required this.phase,
  }) : angle = phase;

  final double radius;
  final double speed;
  final double phase;
  double angle;
}

class _DebuggerSpinComponent extends Component {
  _DebuggerSpinComponent({required this.speed});

  final double speed;
}

class _DebuggerOrbitSystem extends System {
  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    _DebuggerOrbitComponent,
  ];

  @override
  void update(double dt) {
    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final orbit = entity.getComponent<_DebuggerOrbitComponent>()!;
      orbit.angle += orbit.speed * dt;
      transform.position = Vector3.fromOffset(
        Offset(
          math.cos(orbit.angle) * orbit.radius,
          math.sin(orbit.angle) * orbit.radius,
        ),
      );
    });
  }
}

class _DebuggerSpinSystem extends System {
  @override
  List<Type> get requiredComponents => [
    TransformComponent,
    _DebuggerSpinComponent,
  ];

  @override
  void update(double dt) {
    forEach((entity) {
      final transform = entity.getComponent<TransformComponent>()!;
      final spin = entity.getComponent<_DebuggerSpinComponent>()!;
      transform.rotation += spin.speed * dt;
    });
  }
}

class DebuggerShowcaseScreen extends StatefulWidget {
  const DebuggerShowcaseScreen({super.key});

  @override
  State<DebuggerShowcaseScreen> createState() => _DebuggerShowcaseScreenState();
}

class _DebuggerShowcaseScreenState extends State<DebuggerShowcaseScreen> {
  late final Engine _engine;
  World? _world;
  late final JustDebuggerController _controller;
  final math.Random _random = math.Random();

  String _status = 'Preparing live debugger showcase...';

  @override
  void initState() {
    super.initState();
    _engine = Engine();
    _controller = _engine.createDebuggerController(attachImmediately: false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureEngineReady();
      _world = _engine.world;
      _resetDemoWorld();
      _engine.attachDebugger(
        _controller,
        interval: const Duration(milliseconds: 150),
        componentUsageProvider: _componentUsageSummary,
        memoryStatsProvider: _memorySummary,
      );
      _controller.log(
        'Debugger attached to the live ECS world.',
        category: 'runtime',
      );
      if (mounted) {
        setState(() {
          _status = 'Debugger attached to the live ECS world.';
        });
      }
    });
  }

  Future<void> _ensureEngineReady() async {
    if (!_engine.isInitialized) {
      await _engine.initialize();
    }
    if (!_engine.isRunning) {
      _engine.start();
    }
  }

  void _resetDemoWorld() {
    final world = _world;
    if (world == null) {
      return;
    }

    world.destroyAllEntities();
    world.clearSystems();
    world.addSystem(_DebuggerOrbitSystem()..priority = 90);
    world.addSystem(_DebuggerSpinSystem()..priority = 80);
    _spawnEntities(18, silent: true);
  }

  void _spawnEntities(int count, {bool silent = false}) {
    final world = _world;
    if (world == null) {
      return;
    }

    for (var i = 0; i < count; i++) {
      final angle = (_random.nextDouble() * math.pi * 2);
      final spriteScale = 0.75 + _random.nextDouble() * 0.5;
      world.createEntityWithComponents([
        TransformComponent(
          position: Vector3.fromOffset(
            Offset(
              math.cos(angle) * (50 + _random.nextDouble() * 130),
              math.sin(angle) * (50 + _random.nextDouble() * 130),
            ),
          ),
          scale: Vector3(spriteScale, spriteScale, 1.0),
        ),
        _DebuggerOrbitComponent(
          radius: 40 + _random.nextDouble() * 120,
          speed: 0.4 + _random.nextDouble() * 1.4,
          phase: angle,
        ),
        _DebuggerSpinComponent(speed: -1 + _random.nextDouble() * 2),
      ], name: 'debug-entity-$i');
    }

    if (!silent) {
      _controller.log('Spawned $count new ECS entities.', category: 'ecs');
    }

    if (!silent && mounted) {
      setState(() {
        _status = 'Spawned $count new ECS entities.';
      });
    }
  }

  void _removeEntities(int count) {
    final world = _world;
    if (world == null) {
      return;
    }

    final entities = world.activeEntities.take(count).toList();
    for (final entity in entities) {
      world.destroyEntity(entity);
    }

    _controller.log(
      entities.isEmpty
          ? 'No active entities available to remove.'
          : 'Removed ${entities.length} entities from the live world.',
      category: 'ecs',
      level: entities.isEmpty
          ? DebuggerLogLevel.warning
          : DebuggerLogLevel.info,
    );

    if (mounted) {
      setState(() {
        _status = entities.isEmpty
            ? 'No active entities available to remove.'
            : 'Removed ${entities.length} entities from the live world.';
      });
    }
  }

  Map<String, int> _componentUsageSummary() {
    final world = _world;
    if (world == null) {
      return const <String, int>{};
    }

    var transformCount = 0;
    var orbitCount = 0;
    var spinCount = 0;

    for (final entity in world.activeEntities) {
      if (entity.hasComponent<TransformComponent>()) {
        transformCount += 1;
      }
      if (entity.hasComponent<_DebuggerOrbitComponent>()) {
        orbitCount += 1;
      }
      if (entity.hasComponent<_DebuggerSpinComponent>()) {
        spinCount += 1;
      }
    }

    return <String, int>{
      'Transform': transformCount,
      'Orbit': orbitCount,
      'Spin': spinCount,
    }..removeWhere((key, value) => value == 0);
  }

  Map<String, dynamic> _memorySummary() {
    final components = _componentUsageSummary();
    return <String, dynamic>{
      'componentCount': components.values.fold<int>(
        0,
        (sum, value) => sum + value,
      ),
      'entityCount': _world?.activeEntities.length ?? 0,
      'usingCacheFallback': _engine.cache.isUsingMemoryFallback,
      'counters': <String, int>{
        'trackedTypes': components.length,
        'systems': _world?.stats['systems'] as int? ?? 0,
      },
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    _world?.destroyAllEntities();
    _world?.clearSystems();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return JustDebuggerView(
      controller: _controller,
      showOverlay: true,
      showInspectorPanel: false,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final primaryColor = theme.primaryColor;
          final snapshot = _controller.snapshot;
          final performance = _controller.performance;
          final memory = _controller.memory;

          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF06090D),
                  Color(0xFF0B1117),
                  Color(0xFF111827),
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HackerPanel(
                    accentColor: primaryColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SYSTEM // JUST_DEBUGGER',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: primaryColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Live Debugger Console',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A minimal control surface for runtime ECS signals, memory state, performance telemetry, and log streams.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.memory_rounded,
                                color: primaryColor,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _status,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _HackerPanel(
                    title: 'COMMAND DECK',
                    subtitle: 'Live world controls',
                    accentColor: primaryColor,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _spawnEntities(10),
                          icon: const Icon(Icons.add),
                          label: const Text('Spawn 10'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _removeEntities(10),
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text('Remove 10'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            _resetDemoWorld();
                            _controller.log(
                              'Debugger showcase reset.',
                              category: 'runtime',
                            );
                            setState(() {
                              _status = 'Debugger showcase reset.';
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset world'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            _controller.toggleOverlay();
                            _controller.log(
                              _controller.overlayVisible
                                  ? 'Debugger overlay enabled.'
                                  : 'Debugger overlay disabled.',
                              category: 'ui',
                            );
                          },
                          icon: const Icon(Icons.bug_report_outlined),
                          label: Text(
                            _controller.overlayVisible
                                ? 'Hide overlay'
                                : 'Show overlay',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(
                        label: 'Entities',
                        value: '${snapshot.entityCount}',
                        color: colorScheme.primary,
                      ),
                      _MetricCard(
                        label: 'Active',
                        value: '${snapshot.activeEntityCount}',
                        color: colorScheme.primary,
                      ),
                      _MetricCard(
                        label: 'Systems',
                        value: '${snapshot.systemCount}',
                        color: colorScheme.primary,
                      ),
                      _MetricCard(
                        label: 'Archetypes',
                        value: '${snapshot.archetypeCount}',
                        color: colorScheme.primary,
                      ),
                      _MetricCard(
                        label: 'FPS',
                        value: '${performance.currentFps}',
                        color: colorScheme.primary,
                      ),
                      _MetricCard(
                        label: 'Components',
                        value: '${memory.componentCount}',
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final panelWidth = constraints.maxWidth < 900
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: panelWidth,
                            child: _HackerPanel(
                              title: 'PERFORMANCE MATRIX',
                              subtitle: 'Frame timing and load',
                              accentColor: primaryColor,
                              child: SizedBox(
                                height: 250,
                                child: PerformanceDebuggerPanel(
                                  controller: _controller,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: panelWidth,
                            child: _HackerPanel(
                              title: 'MEMORY MATRIX',
                              subtitle: 'Entity and cache health',
                              accentColor: primaryColor,
                              child: SizedBox(
                                height: 250,
                                child: MemoryDebuggerPanel(
                                  controller: _controller,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: panelWidth,
                            child: _HackerPanel(
                              title: 'SIGNAL FEED',
                              subtitle: 'Latest runtime events',
                              accentColor: primaryColor,
                              child: SizedBox(
                                height: 260,
                                child: DebuggerLogConsole(
                                  controller: _controller,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: panelWidth,
                            child: _HackerPanel(
                              title: 'BOOTSTRAP',
                              subtitle: 'Minimal engine hookup',
                              accentColor: primaryColor,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const SelectableText(
                                  'final engine = Engine();\n'
                                  'await engine.initialize();\n'
                                  'final controller = engine.createDebuggerController();\n\n'
                                  'return JustDebuggerView(\n'
                                  '  controller: controller,\n'
                                  '  child: GameWidget(engine: engine),\n'
                                  ');',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: Colors.white,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HackerPanel extends StatelessWidget {
  const _HackerPanel({
    this.title,
    this.subtitle,
    required this.accentColor,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final Color accentColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xCC0B1117),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: accentColor,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.22)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
