import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_game_engine/just_game_engine.dart';
import 'package:just_game_engine/widgets.dart';

import '../../core/engine/demo_engine.dart';

// -----------------------------------------------------------------------------
// Demo mode
// -----------------------------------------------------------------------------

enum _Demo {
  load,
  manifest,
  custom,
  prefabs,
  spawners,
  save,
  migrate;

  String get label => switch (this) {
    load => 'Load Scene',
    manifest => 'Scene Manifest',
    custom => 'Custom Component',
    prefabs => 'Prefabs',
    spawners => 'Spawners',
    save => 'Save & Reload',
    migrate => 'Migrate 1.x',
  };

  IconData get icon => switch (this) {
    load => Icons.file_open,
    manifest => Icons.format_list_numbered,
    custom => Icons.extension,
    prefabs => Icons.widgets,
    spawners => Icons.person_pin_circle,
    save => Icons.save_alt,
    migrate => Icons.upgrade,
  };

  Color get accentColor => switch (this) {
    load => const Color(0xFF29B6F6),
    manifest => const Color(0xFF26A69A),
    custom => const Color(0xFFAB47BC),
    prefabs => const Color(0xFFFFCA28),
    spawners => const Color(0xFF66BB6A),
    save => const Color(0xFFF5746F),
    migrate => const Color(0xFFFF7043),
  };

  String get description => switch (this) {
    load =>
      'SceneLoader.loadAsset reads assets/scenes/garden.scene.json (scene '
          'format 10): shapes, transforms, tags, layers, parents by name, and '
          'two bees playing bob.timeline.json. Tags are indexed by the world: '
          'allTagged / findTagged.',
    manifest =>
      'SceneLoader.loadManifest reads assets/scenes/scenes.json — the play '
          'order — and SceneAssets.pathFor(name) finds each scene. Pick one.',
    custom =>
      'orbit_lab.scene.json uses SpinComponent, a component of this app: a '
          'ComponentDefinition installed through a ContextExtension '
          '(engine.context.install — once per id). Children follow their '
          'parent, so spinning suns carry planets; a VirtualCameraComponent '
          'in the scene takes the camera.',
    prefabs =>
      'lantern_square.scene.json places three instances of '
          'lantern.prefab.json with overrides (a blue glow, a renamed flame, '
          'a removed glow). Tap the canvas to instantiate the chosen prefab '
          'with PrefabLibrary.of(engine.context).instantiate.',
    spawners =>
      'SpawnComponent marks spawn points; SpawnPoints.spawnAll calls the '
          'Spawner each names — Spawner.prefab places crate.prefab.json, a '
          'code Spawner makes fireflies that play bob.timeline.json.',
    save =>
      'The world written back as a scene: each entity\'s components through '
          'engine.context.definitions.encode, parents by name. Clear the '
          'world and load the text again with SceneLoader.loadString.',
    migrate =>
      'A 1.x-era scene (no "version": format 0) brought to format '
          '${SceneFormat.current} in memory by SceneFormat.migrateWithReport, '
          'with the MigrationResult notes — then loaded.',
  };

  String get codeSnippet => switch (this) {
    load =>
      'DemoEngine.reset(engine, include: {\n'
          '  DefaultSystem.rendering, DefaultSystem.sprites,\n'
          '  DefaultSystem.cameras,\n'
          '});\n'
          'final made = await SceneLoader.loadAsset(\n'
          "    engine.world, 'assets/scenes/garden.scene.json');\n\n"
          "final flowers = engine.world.allTagged('flower');\n"
          "final bee = engine.world.findTagged('bee');\n"
          "final tree = engine.world.findEntityByName('Tree');",
    manifest =>
      '// assets/scenes/scenes.json: {"scenes": ["garden", ...]}\n'
          'final names = await SceneLoader.loadManifest();\n\n'
          'DemoEngine.reset(engine, include: {...});\n'
          'await SceneLoader.loadAsset(\n'
          '    engine.world, SceneAssets.pathFor(names[i]));',
    custom =>
      'class SpinComponent extends Component {\n'
          '  SpinComponent({this.speed = 1});\n'
          '  double speed;\n'
          '}\n\n'
          'final spinDefinition = ComponentDefinition<SpinComponent>(\n'
          "  type: 'SpinComponent',\n"
          '  create: SpinComponent.new,\n'
          '  fields: [\n'
          '    SchemaField(\n'
          "      name: 'speed',\n"
          '      kind: FieldTypes.decimal,\n'
          '      read: (c) => (c as SpinComponent).speed,\n'
          '      write: (c, v) =>\n'
          '          (c as SpinComponent).speed = (v as num).toDouble(),\n'
          '    ),\n'
          '  ],\n'
          ');\n\n'
          'final class ShowcaseExtension implements ContextExtension {\n'
          '  const ShowcaseExtension();\n'
          '  @override\n'
          "  String get id => 'showcase';\n"
          '  @override\n'
          '  void install(EngineContext context) =>\n'
          '      context.definitions.register(spinDefinition);\n'
          '}\n\n'
          '// A second install of the same id is ignored:\n'
          'engine.context.install(const ShowcaseExtension());',
    prefabs =>
      'final prefabs = PrefabLibrary.of(engine.context);\n'
          "await prefabs.load('assets/prefabs/crate.prefab.json');\n"
          'prefabs.instantiate(\n'
          '  engine.world,\n'
          "  'assets/prefabs/crate.prefab.json',\n"
          '  position: Vector3(world.dx, world.dy, 0),\n'
          ');\n\n'
          '// A scene entry placing a prefab, with its changes:\n'
          '// {"name": "Lantern East", "prefab": {\n'
          '//   "path": "assets/prefabs/lantern.prefab.json",\n'
          '//   "overrides": [{"target": "lantern",\n'
          '//     "component": "TransformComponent", "field": "position",\n'
          '//     "value": {"x": 240, "y": 50, "z": 0}}],\n'
          '//   "removed": ["glow"], "names": {"flame": "Cold Wick"}}}',
    spawners =>
      'final spawned = SpawnPoints.spawnAll(engine.world, [\n'
          '  Spawner.prefab(\n'
          "    id: 'crate',\n"
          "    path: 'assets/prefabs/crate.prefab.json',\n"
          '  ),\n'
          '  Spawner(\n'
          "    id: 'firefly',\n"
          '    spawn: (world, point) => world.createEntityWithComponents([\n'
          '      TransformComponent(position: Vector3.copy(\n'
          '          point.getComponent<TransformComponent>()!.position)),\n'
          '      CircleComponent(radius: 5),\n'
          '      TimelinePlayerComponent(\n'
          "        timelinePath: 'assets/timelines/bob.timeline.json',\n"
          '        playOnStart: true,\n'
          '      ),\n'
          '    ]),\n'
          '  ),\n'
          "], onMissing: (point, id) => debugPrint('no spawner \$id'));",
    save =>
      'final definitions = engine.context.definitions;\n'
          'final scene = {\n'
          "  'version': SceneFormat.current,\n"
          "  'entities': [\n"
          '    for (final e in world.entities) {\n'
          "      'name': e.name,\n"
          "      'parentName': parentOf(e)?.name,\n"
          "      'components': [\n"
          '        for (final c in e.components)\n'
          '          if (c is! ParentComponent && c is! ChildrenComponent)\n'
          '            ?definitions.encode(c),\n'
          '      ],\n'
          '    },\n'
          '  ],\n'
          '};\n'
          'final text = const JsonEncoder.withIndent(\'  \').convert(scene);\n\n'
          'world.destroyAllEntities();\n'
          'SceneLoader.loadString(world, text);',
    migrate =>
      'final legacy = jsonDecode(text) as Map<String, dynamic>;\n'
          'final result = SceneFormat.migrateWithReport(\n'
          '  legacy,\n'
          '  hooks: engine.context.migrations,\n'
          ');\n'
          "debugPrint('v\${result.fromVersion} → v\${SceneFormat.current}');\n"
          'for (final note in result.notes) {\n'
          "  debugPrint('\$note'); // v7→v8: Hero: a collider now grows …\n"
          '}\n'
          'debugPrint(result.needsAtlas.join(\', \'));\n\n'
          'SceneLoader.load(engine.world, result.scene);',
  };
}

// -----------------------------------------------------------------------------
// A component of this app, saved in scenes
// -----------------------------------------------------------------------------

/// Turns its entity at [speed] radians a second. A child turns about its
/// own centre, and carries its children round it.
class _SpinComponent extends Component {
  _SpinComponent({this.speed = 1.0});

  double speed;
}

final ComponentDefinition<_SpinComponent> _spinDefinition =
    ComponentDefinition<_SpinComponent>(
      type: 'SpinComponent',
      create: _SpinComponent.new,
      hints: const ComponentHints(
        name: 'Spin',
        group: 'Showcase',
        description: 'Turns the entity at a steady speed.',
      ),
      fields: [
        SchemaField(
          name: 'speed',
          kind: FieldTypes.decimal,
          read: (c) => (c as _SpinComponent).speed,
          write: (c, v) => (c as _SpinComponent).speed = (v as num).toDouble(),
        ),
      ],
    );

/// What this app teaches the shared engine's context: one component. An
/// extension is installed once per context by its [id]; installing it again
/// — this screen opened a second time — is ignored.
final class _ScenesDemoExtension implements ContextExtension {
  const _ScenesDemoExtension();

  @override
  String get id => 'just_game_engine_examples.scenes_demo';

  @override
  void install(EngineContext context) {
    context.definitions.register(_spinDefinition);
  }
}

class _SpinSystem extends System {
  _SpinSystem() {
    priority = SystemPriorities.gameplay;
  }

  @override
  List<Type> get requiredComponents => const [
    TransformComponent,
    _SpinComponent,
  ];

  @override
  void update(double deltaTime) {
    forEach((entity) {
      final turn = entity.getComponent<_SpinComponent>()!.speed * deltaTime;
      final link = entity.getComponent<ParentComponent>();
      if (link != null && link.parentId != null && link.inheritTransform) {
        // A child turns in its parent's space: written to its world
        // transform, the hierarchy would take it for a move and stop
        // carrying it round with the parent.
        if (!link.needsLocal) link.localRotation.z += turn;
      } else {
        entity.getComponent<TransformComponent>()!.angle += turn;
      }
    });
  }
}

// -----------------------------------------------------------------------------
// A 1.x-era scene, for the migration demo
// -----------------------------------------------------------------------------

/// Format 0: no `version`, components stored flat, a camera that follows a
/// tagged player, a physics body on a scaled entity, a parent offset that
/// disagrees with where the child stands, a trigger naming its target both
/// by name and by tag, and a grid-sheet sprite with no atlas.
const String _legacyScene = r'''
{
  "name": "courtyard_1x",
  "entities": [
    {
      "name": "Camera",
      "parentName": null,
      "components": [
        {"type": "TransformComponent", "position": {"dx": 0.0, "dy": 0.0}, "rotation": 0.0, "scale": 1.0},
        {"type": "CameraComponent", "zoom": 1.25}
      ]
    },
    {
      "name": "Courtyard",
      "parentName": null,
      "components": [
        {"type": "TransformComponent", "position": {"dx": 0.0, "dy": 110.0}, "rotation": 0.0, "scale": 1.0},
        {"type": "RectangleComponent", "width": 560.0, "height": 36.0, "color": 4282339765, "filled": true},
        {"type": "PhysicsBodyComponent", "shape": {"kind": "rectangle", "width": 560.0, "height": 36.0}, "isStatic": true, "categoryBits": 2}
      ]
    },
    {
      "name": "Hero",
      "parentName": null,
      "components": [
        {"type": "TransformComponent", "position": {"dx": -120.0, "dy": 40.0}, "rotation": 0.0, "scale": {"dx": 1.5, "dy": 1.5}},
        {"type": "CircleComponent", "radius": 18.0, "color": 4294276207},
        {"type": "TagComponent", "tag": "player"},
        {"type": "CameraFollowComponent", "deadZoneWidth": 96.0, "deadZoneHeight": 64.0, "lookaheadDistance": 40.0, "priority": 0},
        {"type": "PhysicsBodyComponent", "shape": {"kind": "circle", "radius": 27.0}, "categoryBits": 5, "maskBits": 3, "fixedRotation": true}
      ]
    },
    {
      "name": "Hat",
      "parentName": "Hero",
      "components": [
        {"type": "TransformComponent", "position": {"dx": -120.0, "dy": 12.0}, "rotation": 0.0, "scale": 1.0},
        {"type": "RectangleComponent", "width": 30.0, "height": 10.0, "color": 4294953512},
        {"type": "ParentComponent", "parentId": 2, "localOffset": {"dx": 0.0, "dy": -32.0}}
      ]
    },
    {
      "name": "Gate",
      "parentName": null,
      "components": [
        {"type": "TransformComponent", "position": {"dx": 150.0, "dy": 52.0}, "rotation": 0.0, "scale": 1.0},
        {"type": "RectangleComponent", "width": 20.0, "height": 80.0, "color": 4288585374},
        {"type": "TagComponent", "tag": "door"}
      ]
    },
    {
      "name": "Gate Trigger",
      "parentName": null,
      "components": [
        {"type": "TransformComponent", "position": {"dx": 90.0, "dy": 52.0}, "rotation": 0.0, "scale": 1.0},
        {"type": "TimelineTriggerComponent", "width": 60.0, "height": 80.0, "targetName": "Gate", "targetTag": "door", "oneShot": true}
      ]
    },
    {
      "name": "Old Sprite",
      "parentName": null,
      "components": [
        {"type": "TransformComponent", "position": {"dx": -220.0, "dy": 60.0}, "rotation": 0.0, "scale": 1.0},
        {"type": "AnimatedSpriteComponent", "spritePath": "assets/sprites/characters/character01/ball_move.png", "frameWidth": 32, "frameHeight": 32, "activeClip": "roll"}
      ]
    },
    {
      "name": "Coin Spawn",
      "parentName": null,
      "components": [
        {"type": "TransformComponent", "position": {"dx": 0.0, "dy": -20.0}, "rotation": 0.0, "scale": 1.0},
        {"type": "SpawnComponent", "tag": "coin"}
      ]
    }
  ]
}
''';

// -----------------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------------

enum _Panel { code, output, entities }

class ScenesPrefabsScreen extends StatefulWidget {
  const ScenesPrefabsScreen({super.key});

  @override
  State<ScenesPrefabsScreen> createState() => _ScenesPrefabsScreenState();
}

class _ScenesPrefabsScreenState extends State<ScenesPrefabsScreen> {
  late final Engine _engine = demoEngine;
  late final World _world = _engine.world;

  final GlobalKey _canvasKey = GlobalKey();

  static const String _lanternPath = 'assets/prefabs/lantern.prefab.json';
  static const String _cratePath = 'assets/prefabs/crate.prefab.json';
  static const String _bobPath = 'assets/timelines/bob.timeline.json';

  _Demo _demo = _Demo.load;
  _Panel _panel = _Panel.code;

  /// Bumped on every demo or scene switch: a load that finishes after the
  /// user moved on takes back what it made.
  int _generation = 0;
  bool _busy = false;

  String _status = '';
  bool _statusIsError = false;
  String _output = '';

  List<String> _manifest = const [];
  String? _scene;

  String _prefabToPlace = _cratePath;
  int _placed = 0;
  final List<Entity> _spawned = [];

  String? _savedText;
  final math.Random _random = math.Random(7);

  Offset? _downAt;

  PrefabLibrary get _prefabs => PrefabLibrary.of(_engine.context);

  @override
  void initState() {
    super.initState();
    _engine.context.install(const _ScenesDemoExtension());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selectDemo(_demo);
    });
  }

  @override
  void dispose() {
    _generation++;
    DemoEngine.reset(_engine);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // World management
  // ---------------------------------------------------------------------------

  /// A clean world with the systems every scene here needs.
  void _resetWorld() {
    _generation++;
    _busy = false;
    _spawned.clear();
    _placed = 0;
    DemoEngine.reset(
      _engine,
      include: {
        DefaultSystem.rendering,
        DefaultSystem.sprites,
        DefaultSystem.cameras,
      },
    );
    _world.addSystem(_SpinSystem());
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
  }

  /// Zooms the camera so a 680 × 460 world area fits the canvas. A scene's
  /// own virtual camera, where it has one, takes over from it.
  void _fitCamera() {
    if (!mounted) return;
    final size = _canvasKey.currentContext?.size;
    if (size == null || size.isEmpty) return;
    final fit = math.min(size.width / 680, size.height / 460);
    _engine.cameraSystem.mainCamera.setZoom(fit.clamp(0.4, 1.5).toDouble());
  }

  void _setStatus(String text, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _status = text;
      _statusIsError = error;
    });
  }

  /// Loads [path] into a fresh world with [SceneLoader.loadAsset] — which
  /// reads the prefabs the scene places first.
  Future<List<Entity>?> _loadScene(String path) async {
    _resetWorld();
    final generation = _generation;
    setState(() {
      _busy = true;
      _scene = path;
    });
    try {
      final made = await SceneLoader.loadAsset(_world, path);
      if (!mounted || generation != _generation) {
        // The user moved on while it loaded: take it back out.
        for (final e in made) {
          if (e.isAlive) _world.destroyEntity(e);
        }
        return null;
      }
      return made;
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        _setStatus('Could not load $path: $error', error: true);
      }
      return null;
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Demos
  // ---------------------------------------------------------------------------

  void _selectDemo(_Demo demo) {
    setState(() {
      _demo = demo;
      _status = '';
      _statusIsError = false;
      _output = '';
      _panel = _Panel.code;
    });
    switch (demo) {
      case _Demo.load:
        _loadGarden();
      case _Demo.manifest:
        _showManifest();
      case _Demo.custom:
        _loadOrbitLab();
      case _Demo.prefabs:
        _loadSquare(spawn: false);
      case _Demo.spawners:
        _loadSquare(spawn: true);
      case _Demo.save:
        _loadForSave(SceneAssets.pathFor('garden'));
      case _Demo.migrate:
        _migrate();
    }
  }

  Future<void> _loadGarden() async {
    final made = await _loadScene(SceneAssets.pathFor('garden'));
    if (made == null) return;
    final flowers = _world.allTagged('flower').length;
    final bee = _world.findTagged('bee');
    final trees = _world.allTagged('tree').map((e) => e.name).join(', ');
    _output = _describeTags();
    _setStatus(
      'loadAsset made ${made.length} entities  ·  allTagged(flower): '
      '$flowers  ·  findTagged(bee): ${bee?.name}  ·  #tree: $trees',
    );
  }

  Future<void> _showManifest() async {
    _resetWorld();
    try {
      final names = await SceneLoader.loadManifest();
      if (!mounted) return;
      setState(() {
        _manifest = names;
        _output =
            '${SceneAssets.manifest}\n\n'
            '${SceneManifest.encode(names)}\n\n'
            '${[for (final n in names) '$n → ${SceneAssets.pathFor(n)}'].join('\n')}';
      });
      if (names.isNotEmpty) await _loadFromManifest(names.first);
    } on Object catch (error) {
      _setStatus('Could not read ${SceneAssets.manifest}: $error', error: true);
    }
  }

  Future<void> _loadFromManifest(String name) async {
    final path = SceneAssets.pathFor(name);
    final made = await _loadScene(path);
    if (made == null) return;
    final index = _manifest.indexOf(name);
    _setStatus(
      'scene ${index + 1} of ${_manifest.length}: "$name" — '
      '${made.length} entities from $path',
    );
  }

  Future<void> _loadOrbitLab() async {
    final made = await _loadScene(SceneAssets.pathFor('orbit_lab'));
    if (made == null) return;
    final definition = _engine.context.definitions.definitionByType(
      'SpinComponent',
    );
    final spinning = _world.query([_SpinComponent]).length;
    _output =
        'engine.context.isInstalled(\'${const _ScenesDemoExtension().id}\') '
        '= ${_engine.context.isInstalled(const _ScenesDemoExtension().id)}\n'
        'definitionByType(\'SpinComponent\'): '
        '${definition?.type} { ${definition?.fields.map((f) => '${f.name}: ${f.kind.id}').join(', ')} }\n'
        'entities with SpinComponent: $spinning\n'
        'installed extensions: ${_engine.context.installed.join(', ')}\n\n'
        'In the scene file:\n'
        '{"type": "SpinComponent", "fields": {"speed": 0.5}}';
    _setStatus(
      '${made.length} entities  ·  $spinning spin through SpinComponent  ·  '
      'Lab Camera (VirtualCameraComponent, zoom 1.15, dutch 0.06) is live',
    );
  }

  Future<void> _loadSquare({required bool spawn}) async {
    final made = await _loadScene(SceneAssets.pathFor('lantern_square'));
    if (made == null) return;
    final generation = _generation;
    // Prefabs placed at run time are read before they are used.
    await _prefabs.loadAll([_lanternPath, _cratePath]);
    if (!mounted || generation != _generation) return;
    final instances = [
      for (final e in _world.entities)
        if (e.getComponent<PrefabInstanceComponent>() case final instance?)
          '${e.name}: ${instance.path.split('/').last}  '
              '${instance.block.overrides.length} overrides'
              '${instance.block.removed.isEmpty ? '' : ', removed ${instance.block.removed}'}'
              '${instance.block.names.isEmpty ? '' : ', names ${instance.block.names}'}',
    ];
    _output =
        'Prefab instances in the scene (PrefabInstanceComponent):\n'
        '${instances.join('\n')}\n\n'
        'Every entity a prefab made carries a PrefabLink '
        '(instance + path in the prefab): '
        '${_world.query([PrefabLink]).length} here.';
    if (spawn) {
      _setStatus(
        '${SpawnPoints.of(_world, 'crate').length} crate and '
        '${SpawnPoints.of(_world, 'firefly').length} firefly spawn points '
        '(the rings) — press Spawn all',
      );
    } else {
      _setStatus(
        '${instances.length} lanterns from one prefab  ·  tap the canvas to '
        'place a ${_prefabToPlace == _cratePath ? 'crate' : 'lantern'}',
      );
    }
  }

  void _spawnAll() {
    final missing = <String>[];
    final spawned = SpawnPoints.spawnAll(_world, [
      Spawner.prefab(id: 'crate', path: _cratePath, tags: const {'crate'}),
      Spawner(
        id: 'firefly',
        label: 'Firefly',
        tags: const {'firefly'},
        spawn: (world, point) => world.createEntityWithComponents([
          TransformComponent(
            position: Vector3.copy(
              point.getComponent<TransformComponent>()!.position,
            ),
          ),
          CircleComponent(
            radius: 5,
            fillStyle: const ShapePaintStyle(color: Color(0xFFEEFF41)),
            strokeStyle: const ShapePaintStyle(color: Color(0x66C6FF00)),
            strokeWidth: 6,
          ),
          LayerComponent(zOrder: 6),
          TagComponent.of(['firefly']),
          TimelinePlayerComponent(
            timelinePath: _bobPath,
            playOnStart: true,
            speed: 0.8 + _random.nextDouble(),
          ),
        ], name: 'Firefly'),
      ),
    ], onMissing: (point, id) => missing.add('${point.name} → "$id"'));
    _spawned.addAll(spawned);
    _setStatus(
      'spawnAll made ${spawned.length}: '
      '${_world.allTagged('crate').length} crates (Spawner.prefab), '
      '${_world.allTagged('firefly').length} fireflies (code)'
      '${missing.isEmpty ? '' : '  ·  no spawner for ${missing.join(', ')}'}',
    );
  }

  void _clearSpawned() {
    for (final e in _spawned) {
      if (e.isAlive) _world.destroyEntity(e);
    }
    final n = _spawned.length;
    _spawned.clear();
    _setStatus('destroyed $n spawned entities (and what was under them)');
  }

  void _place(Offset screen) {
    final at = _engine.cameraSystem.mainCamera.screenToWorld(screen);
    final file = _prefabs.loaded(_prefabToPlace);
    if (file == null) {
      _setStatus('$_prefabToPlace is still loading', error: true);
      return;
    }
    final top = _prefabs.instantiate(
      _world,
      _prefabToPlace,
      name: '${file.name} ${++_placed}',
      position: Vector3(at.dx, at.dy, 0),
    );
    final made = _world
        .query([PrefabLink])
        .where((e) => e.getComponent<PrefabLink>()!.instance == top.id);
    _setStatus(
      'instantiate → "${top.name}" at (${at.dx.toStringAsFixed(0)}, '
      '${at.dy.toStringAsFixed(0)}) with ${made.length} entities',
    );
  }

  // ── Save & reload ──────────────────────────────────────────────────────────

  Future<void> _loadForSave(String path) async {
    final made = await _loadScene(path);
    if (made == null) return;
    setState(() => _savedText = null);
    _setStatus('${made.length} entities loaded — change something, then Save');
  }

  void _shuffle() {
    var moved = 0;
    for (final e in _world.entities) {
      final t = e.getComponent<TransformComponent>();
      if (t == null || e.getComponent<ParentComponent>()?.parentId != null) {
        continue;
      }
      if (!(e.hasTag('flower') ||
          e.hasTag('bee') ||
          e.hasTag('planet') ||
          e.hasTag('lantern') ||
          e.hasTag('crate'))) {
        continue;
      }
      t.position.x += _random.nextDouble() * 120 - 60;
      moved++;
    }
    _setStatus('moved $moved tagged roots (their children follow)');
  }

  void _save() {
    final skipped = <String>{};
    final scene = _sceneOf(_world, name: 'saved_world', skipped: skipped);
    final text = const JsonEncoder.withIndent('  ').convert(scene);
    final entities = (scene['entities'] as List).length;
    final components = (scene['entities'] as List).fold<int>(
      0,
      (n, e) => n + ((e as Map)['components'] as List).length,
    );
    setState(() {
      _savedText = text;
      _output = text;
      _panel = _Panel.output;
    });
    _setStatus(
      'saved $entities entities, $components components, '
      '${(text.length / 1024).toStringAsFixed(1)} KB'
      '${skipped.isEmpty ? '' : '  ·  runtime-only, not saved: ${skipped.join(', ')}'}',
    );
  }

  void _clearWorld() {
    _resetWorld();
    _setStatus('world cleared: ${_world.entityCount} entities');
  }

  void _reloadSaved() {
    final text = _savedText;
    if (text == null) return;
    _resetWorld();
    try {
      final made = SceneLoader.loadString(_world, text);
      _setStatus('SceneLoader.loadString made ${made.length} entities again');
    } on Object catch (error) {
      _setStatus('Could not load the saved text: $error', error: true);
    }
  }

  /// The world as a scene file — what an editor's Save writes, except that
  /// prefab instances are written out entity by entity rather than collapsed
  /// back into `prefab` blocks.
  ///
  /// Entities are written parents first, each followed by what is under it,
  /// so a child's `parentName` finds the right parent even where names
  /// repeat. Components the context has no definition for (runtime-only
  /// ones: labels, prefab links) are left out and named in [skipped].
  Map<String, dynamic> _sceneOf(
    World world, {
    required String name,
    required Set<String> skipped,
  }) {
    final definitions = world.context.definitions;
    final entities = world.entities;
    final byId = {for (final e in entities) e.id: e};
    final children = <EntityId, List<Entity>>{};
    final roots = <Entity>[];
    for (final e in entities) {
      final parentId = e.getComponent<ParentComponent>()?.parentId;
      final parent = parentId == null ? null : byId[parentId];
      if (parent == null) {
        roots.add(e);
      } else {
        (children[parent.id] ??= []).add(e);
      }
    }

    final out = <Map<String, dynamic>>[];
    void write(Entity entity, Entity? parent) {
      final components = <Map<String, dynamic>>[];
      for (final c in entity.components) {
        // The hierarchy is saved as `parentName`; the links are made again
        // on load.
        if (c is ParentComponent || c is ChildrenComponent) continue;
        final json = definitions.encode(c);
        if (json == null) {
          skipped.add(c.runtimeType.toString());
        } else {
          components.add(json);
        }
      }
      out.add({
        'name': entity.name,
        'parentName': parent?.name,
        if (!entity.isActive) 'enabled': false,
        'components': components,
      });
      for (final child in children[entity.id] ?? const <Entity>[]) {
        write(child, entity);
      }
    }

    for (final root in roots) {
      write(root, null);
    }
    return {
      'version': SceneFormat.current,
      'name': name,
      'mode': '2d',
      'entities': out,
    };
  }

  // ── Migration ──────────────────────────────────────────────────────────────

  void _migrate() {
    _resetWorld();
    try {
      final legacy = jsonDecode(_legacyScene) as Map<String, dynamic>;
      final result = SceneFormat.migrateWithReport(
        legacy,
        hooks: _engine.context.migrations,
      );
      final made = SceneLoader.load(_world, result.scene);
      final notes = result.notes;
      setState(() {
        _panel = _Panel.output;
        _output =
            'SceneFormat.versionOf(legacy) = ${SceneFormat.versionOf(legacy)}'
            '  →  ${SceneFormat.versionOf(result.scene)}'
            '  (migrated: ${result.migrated})\n\n'
            'MigrationResult.notes (${notes.length}):\n'
            '${notes.isEmpty ? '  none' : notes.map((n) => '  • $n').join('\n')}\n\n'
            'MigrationResult.needsAtlas: '
            '${result.needsAtlas.isEmpty ? 'none' : result.needsAtlas.join(', ')}\n\n'
            '── Before (format 0) ──\n${_legacyScene.trim()}\n\n'
            '── After (format ${SceneFormat.current}) ──\n'
            '${const JsonEncoder.withIndent('  ').convert(result.scene)}';
      });
      _setStatus(
        'v${result.fromVersion} → v${SceneFormat.current}: '
        '${notes.length} notes  ·  loaded ${made.length} entities '
        '(CameraComponent → VirtualCameraComponent + framing, '
        'PhysicsBodyComponent → RigidBody2D + Collider2D)',
      );
    } on Object catch (error) {
      _setStatus('Migration failed: $error', error: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------

  String get _statsLine {
    final scene = _scene == null ? '' : '  scene ${_scene!.split('/').last}';
    return 'entities ${_world.entityCount}'
        '  systems ${_world.systems.length}'
        '  prefabs read ${[_lanternPath, _cratePath].where((p) => _prefabs.loaded(p) != null).length}/2'
        '$scene${_busy ? '  loading…' : ''}';
  }

  String _describeTags() {
    final counts = <String, int>{};
    for (final e in _world.entities) {
      for (final tag
          in e.getComponent<TagComponent>()?.tags ?? const <String>{}) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return 'Tags in the world (TagComponent, indexed):\n'
        '${counts.entries.map((e) => '  #${e.key}: ${e.value}').join('\n')}\n\n'
        'Layers (LayerComponent layer / zOrder) decide draw order: '
        'Sky -100, Sun -90, the garden 0, bees on z 5.';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _canvas),
        _buildDemoSelector(),
        _buildControlPanel(),
        _buildBottomPanel(),
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
              const SizedBox(width: 12),
              const Spacer(),
              const Flexible(
                child: Text(
                  'SceneLoader  *  PrefabLibrary  *  SceneFormat',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Color(0xFFF5746F), fontSize: 10),
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
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _status,
              style: TextStyle(
                color: _statusIsError
                    ? const Color(0xFFFF8A80)
                    : Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Made once, so rebuilding the panels never rebuilds the game view. A
  /// tap (a press that does not move) places a prefab in the Prefabs demo;
  /// a drag still pans the camera.
  late final Widget _canvas = KeyedSubtree(
    key: _canvasKey,
    child: GameCameraControls(
      camera: _engine.cameraSystem.mainCamera,
      enablePan: true,
      enablePinch: true,
      showZoomLevel: true,
      child: Listener(
        onPointerDown: (e) => _downAt = e.localPosition,
        onPointerUp: (e) {
          final down = _downAt;
          _downAt = null;
          if (_demo != _Demo.prefabs || down == null) return;
          if ((e.localPosition - down).distance > 8) return;
          _place(e.localPosition);
        },
        child: GameWidget(engine: _engine, showFPS: true),
      ),
    ),
  );

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
                  onSelected: (_) => _selectDemo(d),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _demoControls()),
      ),
    );
  }

  List<Widget> _demoControls() {
    final accent = _demo.accentColor;
    final idle = !_busy;
    switch (_demo) {
      case _Demo.load:
        return [
          _actionButton('Reload garden', accent, idle ? _loadGarden : null),
          const SizedBox(width: 10),
          _hint('Drag to pan  *  Scroll / pinch to zoom'),
        ];
      case _Demo.manifest:
        return [
          _hint('scenes.json:'),
          const SizedBox(width: 8),
          for (final name in _manifest) ...[
            _actionButton(
              name,
              accent,
              idle ? () => _loadFromManifest(name) : null,
              active: _scene == SceneAssets.pathFor(name),
            ),
            const SizedBox(width: 6),
          ],
        ];
      case _Demo.custom:
        return [
          _actionButton('Spin ×2', accent, () {
            for (final e in _world.query([_SpinComponent])) {
              e.getComponent<_SpinComponent>()!.speed *= 2;
            }
            _setStatus('every SpinComponent.speed doubled');
          }),
          const SizedBox(width: 6),
          _actionButton('Reverse', accent, () {
            for (final e in _world.query([_SpinComponent])) {
              e.getComponent<_SpinComponent>()!.speed *= -1;
            }
            _setStatus('every SpinComponent.speed reversed');
          }),
          const SizedBox(width: 6),
          _actionButton('Install again', accent, () {
            final before = _engine.context.installed.length;
            _engine.context.install(const _ScenesDemoExtension());
            _setStatus(
              'install(...) with an id already installed is ignored: '
              '$before extensions before, ${_engine.context.installed.length} after',
            );
          }),
          const SizedBox(width: 6),
          _actionButton('Reload', accent, idle ? _loadOrbitLab : null),
        ];
      case _Demo.prefabs:
        return [
          _hint('Tap to place:'),
          const SizedBox(width: 8),
          _actionButton(
            'Crate',
            accent,
            () => setState(() => _prefabToPlace = _cratePath),
            active: _prefabToPlace == _cratePath,
          ),
          const SizedBox(width: 6),
          _actionButton(
            'Lantern',
            accent,
            () => setState(() => _prefabToPlace = _lanternPath),
            active: _prefabToPlace == _lanternPath,
          ),
          const SizedBox(width: 10),
          _actionButton(
            'Reset square',
            accent,
            idle ? () => _loadSquare(spawn: false) : null,
          ),
        ];
      case _Demo.spawners:
        return [
          _actionButton('Spawn all', accent, idle ? _spawnAll : null),
          const SizedBox(width: 6),
          _actionButton(
            'Clear spawned',
            accent,
            _spawned.isEmpty ? null : _clearSpawned,
          ),
          const SizedBox(width: 10),
          _hint('crate → Spawner.prefab  ·  firefly → Spawner(spawn:)'),
        ];
      case _Demo.save:
        return [
          for (final name in const ['garden', 'orbit_lab', 'lantern_square'])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _actionButton(
                name,
                const Color(0xFF5A6E88),
                idle ? () => _loadForSave(SceneAssets.pathFor(name)) : null,
                active: _scene == SceneAssets.pathFor(name),
              ),
            ),
          const SizedBox(width: 6),
          _actionButton('Shuffle', accent, _shuffle),
          const SizedBox(width: 6),
          _actionButton('Save', accent, _save),
          const SizedBox(width: 6),
          _actionButton('Clear world', accent, _clearWorld),
          const SizedBox(width: 6),
          _actionButton(
            'Reload saved',
            accent,
            _savedText == null ? null : _reloadSaved,
          ),
        ];
      case _Demo.migrate:
        return [
          _actionButton('Migrate & load again', accent, _migrate),
          const SizedBox(width: 10),
          _hint('Output tab: notes, before and after'),
        ];
    }
  }

  Widget _hint(String text) =>
      Text(text, style: const TextStyle(color: Colors.white38, fontSize: 11));

  Widget _actionButton(
    String label,
    Color color,
    VoidCallback? onTap, {
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: onTap == null
              ? const Color(0xFF111C2A)
              : color.withValues(alpha: active ? 0.32 : 0.15),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: onTap == null
                ? const Color(0xFF1A2535)
                : color.withValues(alpha: active ? 0.95 : 0.55),
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

  Widget _tab(String label, _Panel panel, Color color) {
    final active = _panel == panel;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: GestureDetector(
        onTap: () => setState(() => _panel = panel),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.2)
                : const Color(0xFF0E1A2A),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.75)
                  : const Color(0xFF1E2E40),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white60,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final accent = _demo.accentColor;
    final text = switch (_panel) {
      _Panel.code => _demo.codeSnippet,
      _Panel.output => _output.isEmpty ? 'Nothing yet for this demo.' : _output,
      _Panel.entities => _entityList(),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF090F1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _tab('Code', _Panel.code, accent),
                _tab(
                  _demo == _Demo.save
                      ? 'Saved JSON'
                      : _demo == _Demo.migrate
                      ? 'Migration'
                      : 'Output',
                  _Panel.output,
                  accent,
                ),
                _tab('Entities', _Panel.entities, accent),
                const Spacer(),
                const Flexible(
                  child: Text(
                    'just_game_engine  Scenes API',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white24, fontSize: 9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 130,
              width: double.infinity,
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: const TextStyle(
                    color: Color(0xFFB0C8E0),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _entityList() {
    final entities = _world.entities;
    if (entities.isEmpty) return 'The world is empty.';
    final lines = <String>['${entities.length} entities, oldest first:'];
    for (final e in entities.take(120)) {
      final tags = e.getComponent<TagComponent>()?.tags ?? const <String>{};
      final link = e.getComponent<PrefabLink>();
      final parentId = e.getComponent<ParentComponent>()?.parentId;
      final types = [
        for (final c in e.components)
          if (c is! ParentComponent &&
              c is! ChildrenComponent &&
              c is! PrefabLink &&
              c is! PrefabInstanceComponent)
            _engine.context.definitions.definitionFor(c)?.type ??
                c.runtimeType.toString(),
      ];
      lines.add(
        '#${e.id} ${e.name ?? '(unnamed)'}'
        '${parentId == null ? '' : '  ↑#$parentId'}'
        '${e.isActive ? '' : '  (off)'}'
        '${tags.isEmpty ? '' : '  ${tags.map((t) => '#$t').join(' ')}'}'
        '${link == null ? '' : '  [prefab ${link.path}]'}'
        '\n    ${types.join(', ')}',
      );
    }
    if (entities.length > 120) lines.add('… ${entities.length - 120} more');
    return lines.join('\n');
  }
}
