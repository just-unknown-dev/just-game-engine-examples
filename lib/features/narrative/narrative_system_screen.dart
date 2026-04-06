import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_game_engine/just_game_engine.dart';

// =============================================================================
// Demo modes
// =============================================================================

enum _Demo {
  linear,
  branching,
  variables,
  commands,
  signals,
  hubSpoke,
  assetFile;

  String get label => switch (this) {
    linear => 'Linear',
    branching => 'Branching',
    variables => 'Variables',
    commands => 'Commands',
    signals => 'Signals',
    hubSpoke => 'Hub & Spoke',
    assetFile => '.yarn File',
  };

  IconData get icon => switch (this) {
    linear => Icons.chat_bubble_outline,
    branching => Icons.call_split,
    variables => Icons.data_object,
    commands => Icons.terminal,
    signals => Icons.sensors,
    hubSpoke => Icons.hub,
    assetFile => Icons.description_outlined,
  };

  Color get accentColor => switch (this) {
    linear => const Color(0xFF29B6F6),
    branching => const Color(0xFF66BB6A),
    variables => const Color(0xFFAB47BC),
    commands => const Color(0xFFFF7043),
    signals => const Color(0xFFFFCA28),
    hubSpoke => const Color(0xFF26A69A),
    assetFile => const Color(0xFFEF9A9A),
  };

  String get description => switch (this) {
    linear =>
      'Multi-speaker conversation with typewriter animation. '
          'Tap Advance or the dialogue box to progress through a scripted scene.',
    branching =>
      'Player choices drive branching narrative. '
          'DialogueChoicesWidget renders options; each branch routes to '
          'a different story path.',
    variables =>
      'Yarn <<set>> writes to DialogueVariableStore. '
          'Inline {\$varName} substitution renders live values in text. '
          'Conditional #if guards lock choices at runtime.',
    commands =>
      'Custom <<command args>> statements invoke registered Dart async '
          'handlers via DialogueCommandRegistry. '
          'Each command fires a visual effect in the viewport.',
    signals =>
      'NarrativeSignals exposes reactive Signals: currentLine, choices, '
          'isDialogueActive, activeSpeaker, activeNodeTitle. '
          'The live monitor panel updates with every state change.',
    hubSpoke =>
      'Multiple named nodes form a graph. <<jump NodeName>> routes '
          'execution between hubs. Revisitable nodes enable open-world '
          'conversations and persistent branching world states.',
    assetFile =>
      'A real .yarn file loaded from assets/data/embervale.yarn via '
          'rootBundle.loadString() then YarnParser.parse(). '
          'Demonstrates variables, conditionals, commands, hub navigation, and #line tags.',
  };

  String get codeSnippet => switch (this) {
    linear =>
      'final graph = YarnParser.parse(yarnSource, id: \'inn\');\n'
          'final runner = DialogueRunner(\n'
          '  graph: graph,\n'
          '  variables: DialogueVariableStore(),\n'
          '  conditions: DialogueConditionRegistry(),\n'
          '  commands: DialogueCommandRegistry(),\n'
          ');\n\n'
          '// Reactive subscription:\n'
          'runner.signals.currentLine.addListener(() {\n'
          '  final line = runner.signals.currentLine.value;\n'
          '  if (line != null) showLine(line.character, line.text);\n'
          '});\n\n'
          '// Or drop in the built-in widget:\n'
          'DialogueBoxWidget(\n'
          '  runner: runner,\n'
          '  onTap: runner.advance,\n'
          '  typewriterSpeed: 40, // chars / second\n'
          '  portraitBuilder: (name) => MyPortrait(name: name),\n'
          ');\n\n'
          'unawaited(runner.start(\'Start\')); // runner.advance() to step',
    branching =>
      '// Yarn:\n'
          '// Guard: State your business.\n'
          '// -> Trade.\n'
          '//     Guard: Market opens at dawn.\n'
          '// -> Pass through.\n'
          '//     Guard: Move quickly.\n\n'
          '// Reactive choices:\n'
          'runner.signals.choices.addListener(() {\n'
          '  final opts = runner.signals.choices.value;\n'
          '  // opts[0].text, opts[0].isAvailable ...\n'
          '});\n\n'
          '// Built-in choices widget:\n'
          'DialogueChoicesWidget(\n'
          '  runner: runner,\n'
          '  showUnavailable: true,\n'
          ');\n\n'
          '// Called internally by the widget on tap:\n'
          'runner.selectChoice(index);',
    variables =>
      '// Yarn:\n'
          '// <<set \$gold = 10>>\n'
          '// Merchant: You have {\$gold} gold.\n'
          '// -> Buy sword  #if \$gold >= 8\n'
          '//     <<set \$gold = \$gold - 8>>\n'
          '//     <<set \$hasSword = true>>\n\n'
          'final vars = DialogueVariableStore();\n\n'
          '// Read values at any point:\n'
          'vars.get<int>(\'gold\')          // → 2\n'
          'vars.get<bool>(\'hasSword\')     // → true\n'
          'vars.getOrDefault(\'coins\', 0)  // → 0\n\n'
          '// Persist and restore:\n'
          'final snap = vars.toMap();\n'
          'vars.loadFromMap(snap);',
    commands =>
      '// Yarn:\n'
          '// <<flash red>>\n'
          '// <<shake>>\n'
          '// <<flash white>>\n\n'
          'final cmds = DialogueCommandRegistry();\n\n'
          'cmds.register(\'flash\', (ctx) async {\n'
          '  final color = colorFromName(ctx.arg(0));\n'
          '  await triggerFlash(color);\n'
          '});\n\n'
          'cmds.register(\'shake\', (ctx) async {\n'
          '  final power =\n'
          '      double.tryParse(ctx.arg(0) ?? \'0.5\') ?? 0.5;\n'
          '  await camera.shake(intensity: power * 20);\n'
          '});\n\n'
          '// ctx members:\n'
          '// ctx.name     → \'flash\'\n'
          '// ctx.args     → [\'red\']\n'
          '// ctx.rawArgs  → \'red\'',
    signals =>
      '// All reactive state on NarrativeSignals:\n'
          'final sig = runner.signals;\n\n'
          'sig.currentLine       // Signal<DialogueLine?>\n'
          'sig.choices           // Signal<List<DialogueChoice>>\n'
          'sig.isDialogueActive  // Signal<bool>\n'
          'sig.activeSpeaker     // Signal<String?>\n'
          'sig.activeNodeTitle   // Signal<String?>\n'
          'sig.hasChoices        // Computed<bool>\n'
          'sig.hasLine           // Computed<bool>\n\n'
          '// Use SignalBuilder in Flutter:\n'
          'SignalBuilder<bool>(\n'
          '  signal: sig.isDialogueActive,\n'
          '  builder: (ctx, active, _) =>\n'
          '    active ? DialogueBoxWidget(runner: runner)\n'
          '           : const SizedBox.shrink(),\n'
          ')',
    hubSpoke =>
      '// Multi-node Yarn:\n'
          '// title: TownSquare\n'
          '// ---\n'
          '// -> Talk to guard.\n'
          '//    <<jump GuardPost>>\n'
          '// -> Visit market.\n'
          '//    <<jump Market>>\n'
          '// ===\n'
          '// title: GuardPost\n'
          '// ---\n'
          '// Guard: All is quiet.\n'
          '// <<jump TownSquare>>\n'
          '// ===\n\n'
          '// Merge multiple .yarn files:\n'
          'final graph = DialogueGraph.merge([\n'
          '  YarnParser.parse(file1, id: \'world\'),\n'
          '  YarnParser.parse(file2, id: \'world\'),\n'
          ']);\n\n'
          'unawaited(runner.start(\'TownSquare\'));',
    assetFile =>
      '// Load a .yarn file from Flutter assets:\n'
          'Future<DialogueRunner> loadFromAsset(String path) async {\n'
          '  final source = await rootBundle.loadString(path);\n'
          '  final graph  = YarnParser.parse(source, id: \'embervale\');\n\n'
          '  final cmds = DialogueCommandRegistry()\n'
          '    ..register(\'ambient_sound\', (ctx) async {\n'
          '      playSoundLoop(ctx.arg(0)!);\n'
          '    })\n'
          '    ..register(\'fade_out\', (ctx) async {\n'
          '      final dur = double.tryParse(ctx.arg(0) ?? \'1\') ?? 1.0;\n'
          '      await camera.fadeOut(dur);\n'
          '    })\n'
          '    ..register(\'flash_quest_accept\', (ctx) async {\n'
          '      triggerQuestAcceptEffect();\n'
          '    });\n\n'
          '  return DialogueRunner(\n'
          '    graph: graph,\n'
          '    variables: DialogueVariableStore(),\n'
          '    conditions: DialogueConditionRegistry(),\n'
          '    commands: cmds,\n'
          '  );\n'
          '}\n\n'
          '// Start from the entry node:\n'
          'unawaited(runner.start(\'EmbervaleInn\'));',
  };
}

// =============================================================================
// Embedded Yarn scripts
// =============================================================================

const _kLinearYarn = r'''
title: Start
---
Narrator: Somewhere in the mountains, a lone traveler arrives at Embervale.
Innkeeper: Welcome, friend! You look weary from the road.
Innkeeper: The Rusty Anchor has warm beds and fresh stew.
Traveler: What news from the valley?
Innkeeper: Dark rumors. Strange lights near the old ruins at night.
Innkeeper: None dare go near them. Sensible folk, they are.
Narrator: The fire crackles warmly. For a moment, the world feels safe.
Innkeeper: Rest well, traveler. The road ahead is long.
===
''';

const _kBranchingYarn = r'''
title: Start
---
Guard: Halt! State your business in Embervale.
-> I am here to trade.
    Guard: The market opens at dawn. You are welcome to stay.
    Guard: Mind the south road after dark.
-> I am hunting the lights near the ruins.
    Guard: Brave words. Or perhaps foolish ones.
    Guard: If you do not return by morning, we will send no one after you.
-> Just passing through.
    Guard: Then pass quickly. We have had enough wanderers lately.
Guard: Safe travels.
===
''';

const _kVariablesYarn = r'''
title: Start
---
<<set $gold = 10>>
<<set $hasSword = false>>
Merchant: Greetings! I have a fine blade — only 8 gold.
Merchant: You appear to carry {$gold} gold. Interested?
-> Buy the sword. #if $gold >= 8
    <<set $gold = $gold - 8>>
    <<set $hasSword = true>>
    Merchant: Excellent! You now have {$gold} gold remaining.
-> I cannot afford it. #if $gold < 8
    Merchant: Come back when your purse is heavier.
-> No thank you.
    Merchant: Perhaps another time.
<<if $hasSword>>
Merchant: May that blade serve you well on the road ahead!
<<else>>
Merchant: Safe travels, friend!
<<endif>>
===
''';

const _kCommandsYarn = r'''
title: Start
---
Wizard: Watch closely. Magic demands your full attention.
<<flash red>>
Wizard: Crimson fire — feel the heat!
<<flash blue>>
Wizard: Frost from the northern peaks!
<<shake>>
Wizard: The very earth trembles at my word!
<<flash white>>
Wizard: A blinding flash to seal the spell!
Wizard: Now you have seen what I can do. Tread carefully.
===
''';

const _kSignalsYarn = r'''
title: Start
---
Narrator: The signal monitor shows live reactive state.
Archivist: Every line I speak updates the currentLine signal.
Archivist: My name fills activeSpeaker right now.
Narrator: When choices appear, the choices signal fills with options.
-> I understand.
    Archivist: Signals are the reactive backbone of the engine.
-> Show me more.
    Narrator: isDialogueActive stays true throughout the session.
    Archivist: And resets to false when the dialogue ends.
Narrator: That is the power of NarrativeSignals.
===
''';

const _kHubSpokeYarn = r'''
title: TownSquare
---
Narrator: You stand in the town square. Where would you like to go?
-> Talk to the guard.
    <<jump GuardPost>>
-> Visit the market.
    <<jump Market>>
-> Leave Embervale.
    Narrator: You set off down the mountain road. Farewell.
    <<stop>>
===
title: GuardPost
---
Guard: Evening. All quiet tonight.
Guard: The square is just behind you if you need it.
<<jump TownSquare>>
===
title: Market
---
Trader: Buy something or move along!
-> Browse the wares.
    Trader: Fine goods here, if you have the coin.
    <<jump TownSquare>>
-> I will leave.
    <<jump TownSquare>>
===
''';

// =============================================================================
// Screen
// =============================================================================

class NarrativeSystemScreen extends StatefulWidget {
  const NarrativeSystemScreen({super.key});

  @override
  State<NarrativeSystemScreen> createState() => _NarrativeSystemScreenState();
}

class _NarrativeSystemScreenState extends State<NarrativeSystemScreen> {
  // ── Demo state ────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.linear;
  DialogueRunner? _runner;
  String _statusMessage = '';

  // ── Variables-demo live display ───────────────────────────────────────────
  DialogueVariableStore? _vars;

  // ── Asset-file demo ───────────────────────────────────────────────────────
  bool _assetLoading = false;

  // ── Commands-demo effects ─────────────────────────────────────────────────
  final List<String> _commandLog = [];
  Color? _flashColor;
  Timer? _flashTimer;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildDemo(_demo));
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _disposeRunner();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Runner management
  // ─────────────────────────────────────────────────────────────────────────

  void _disposeRunner() {
    final r = _runner;
    if (r != null) {
      r.signals.currentLine.removeListener(_rebuild);
      r.signals.choices.removeListener(_rebuild);
      r.signals.isDialogueActive.removeListener(_rebuild);
      r.signals.activeSpeaker.removeListener(_rebuild);
      r.signals.activeNodeTitle.removeListener(_rebuild);
      r.stop().ignore();
    }
    _runner = null;
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  DialogueRunner _makeRunner(
    String yarnSource,
    String graphId, {
    DialogueVariableStore? vars,
    DialogueConditionRegistry? conditions,
    DialogueCommandRegistry? commands,
  }) {
    final graph = YarnParser.parse(yarnSource, id: graphId);
    final runner = DialogueRunner(
      graph: graph,
      variables: vars ?? DialogueVariableStore(),
      conditions: conditions ?? DialogueConditionRegistry(),
      commands: commands ?? DialogueCommandRegistry(),
    );
    runner.signals.currentLine.addListener(_rebuild);
    runner.signals.choices.addListener(_rebuild);
    runner.signals.isDialogueActive.addListener(_rebuild);
    runner.signals.activeSpeaker.addListener(_rebuild);
    runner.signals.activeNodeTitle.addListener(_rebuild);
    return runner;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo builders
  // ─────────────────────────────────────────────────────────────────────────

  void _buildDemo(_Demo demo) {
    _disposeRunner();
    _demo = demo;
    _commandLog.clear();
    _flashColor = null;
    _flashTimer?.cancel();
    _flashTimer = null;
    _vars = null;
    _statusMessage = '';

    switch (demo) {
      case _Demo.linear:
        _runner = _makeRunner(_kLinearYarn, 'inn');
        _statusMessage = 'Tap Start — advance through the inn conversation';
      case _Demo.branching:
        _runner = _makeRunner(_kBranchingYarn, 'guard');
        _statusMessage = 'Tap Start — choices appear automatically';
      case _Demo.variables:
        _vars = DialogueVariableStore();
        _runner = _makeRunner(_kVariablesYarn, 'merchant', vars: _vars);
        _statusMessage =
            'Tap Start — watch \$gold and \$hasSword update in real time';
      case _Demo.commands:
        final cmds = DialogueCommandRegistry();
        cmds.register('flash', (ctx) async {
          final colorName = ctx.arg(0) ?? 'white';
          final color = _colorFromName(colorName);
          if (mounted) {
            setState(() {
              _flashColor = color;
              _commandLog.insert(0, '<<flash $colorName>>');
            });
          }
          _flashTimer?.cancel();
          _flashTimer = Timer(const Duration(milliseconds: 450), () {
            if (mounted) setState(() => _flashColor = null);
          });
        });
        cmds.register('shake', (ctx) async {
          if (mounted) {
            setState(() => _commandLog.insert(0, '<<shake>>'));
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        _runner = _makeRunner(_kCommandsYarn, 'wizard', commands: cmds);
        _statusMessage = 'Tap Start — commands trigger visual effects';
      case _Demo.signals:
        _runner = _makeRunner(_kSignalsYarn, 'signals');
        _statusMessage = 'Tap Start — watch signals update in the monitor';
      case _Demo.hubSpoke:
        _runner = _makeRunner(_kHubSpokeYarn, 'world');
        _statusMessage =
            'Tap Start — explore nodes via choices; <<jump>> navigates between them';
      case _Demo.assetFile:
        _statusMessage = 'Loading embervale.yarn from assets…';
        _assetLoading = true;
        if (mounted) setState(() {});
        _loadAssetDemo();
        return; // early return — setState called in _loadAssetDemo
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadAssetDemo() async {
    try {
      final source = await rootBundle.loadString('assets/data/embervale.yarn');
      final vars = DialogueVariableStore()..set('playerName', 'Traveler');

      final cmds = DialogueCommandRegistry();
      cmds.register('ambient_sound', (ctx) async {
        if (mounted) {
          setState(
            () => _commandLog.insert(0, '<<ambient_sound ${ctx.rawArgs}>>'),
          );
        }
      });
      cmds.register('sound_effect', (ctx) async {
        if (mounted) {
          setState(
            () => _commandLog.insert(0, '<<sound_effect ${ctx.rawArgs}>>'),
          );
        }
      });
      cmds.register('flash_quest_accept', (ctx) async {
        final color = const Color(0xFFFFCA28);
        if (mounted) {
          setState(() {
            _flashColor = color;
            _commandLog.insert(0, '<<flash_quest_accept>>');
          });
        }
        _flashTimer?.cancel();
        _flashTimer = Timer(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _flashColor = null);
        });
      });
      cmds.register('fade_out', (ctx) async {
        if (mounted) {
          setState(() => _commandLog.insert(0, '<<fade_out ${ctx.rawArgs}>>'));
        }
        final dur = (double.tryParse(ctx.arg(0) ?? '1') ?? 1.0) * 1000;
        await Future<void>.delayed(Duration(milliseconds: dur.toInt()));
      });

      _vars = vars;
      _runner = _makeRunner(source, 'embervale', vars: vars, commands: cmds);
    } catch (e) {
      _statusMessage = 'Failed to load embervale.yarn: $e';
    } finally {
      _assetLoading = false;
      if (mounted)
        setState(() => _statusMessage = 'Tap to begin — The Rusty Anchor Inn');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  void _startDialogue() {
    final r = _runner;
    if (r == null || r.signals.isDialogueActive.value) return;
    final startNode = switch (_demo) {
      _Demo.hubSpoke => 'TownSquare',
      _Demo.assetFile => 'EmbervaleInn',
      _ => 'Start',
    };
    r.start(startNode).ignore();
    setState(() => _statusMessage = 'Dialogue running…');
  }

  void _stopDialogue() {
    _runner?.stop().ignore();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  Color _colorFromName(String name) {
    const map = {
      'red': Color(0xFFEF5350),
      'blue': Color(0xFF29B6F6),
      'green': Color(0xFF66BB6A),
      'white': Colors.white,
      'yellow': Color(0xFFFFCA28),
      'purple': Color(0xFFAB47BC),
      'orange': Color(0xFFFF7043),
    };
    return map[name.toLowerCase()] ?? Colors.white;
  }

  Color _characterColor(String character) {
    const colors = [
      Color(0xFF29B6F6),
      Color(0xFF66BB6A),
      Color(0xFFAB47BC),
      Color(0xFFFF7043),
      Color(0xFFFFCA28),
      Color(0xFF26A69A),
      Color(0xFFEF5350),
    ];
    final hash = character.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
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

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final isRunning = _runner?.signals.isDialogueActive.value ?? false;
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
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (isRunning)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'RUNNING',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _demo.description,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _statusMessage,
              style: TextStyle(
                color: _demo.accentColor.withOpacity(0.85),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Canvas
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCanvas() {
    final r = _runner;
    final isActive = r?.signals.isDialogueActive.value ?? false;

    return Container(
      color: const Color(0xFF07111F),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background world
          CustomPaint(painter: _WorldPainter(_demo.accentColor)),

          // Variables / asset-file demo: live variable store panel
          if (_demo == _Demo.variables || _demo == _Demo.assetFile)
            _buildVariablesPanel(),

          // Commands / asset-file demo: flash overlay
          if ((_demo == _Demo.commands || _demo == _Demo.assetFile) &&
              _flashColor != null)
            Positioned.fill(
              child: Container(color: _flashColor!.withOpacity(0.30)),
            ),

          // Commands / asset-file demo: command log
          if ((_demo == _Demo.commands || _demo == _Demo.assetFile) &&
              _commandLog.isNotEmpty)
            _buildCommandLog(),

          // Signals demo: live monitor
          if (_demo == _Demo.signals) _buildSignalMonitor(),

          // Idle placeholder — tap anywhere on the canvas to start
          if (!isActive)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _assetLoading ? null : _startDialogue,
                child: Center(
                  child: _assetLoading
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _demo.accentColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Loading embervale.yarn…',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _demo.icon,
                              color: _demo.accentColor.withOpacity(0.25),
                              size: 52,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tap to begin',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.25),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            )
          else ...[
            // Choices widget — above the box
            if (r != null)
              Positioned(
                left: 16,
                right: _demo == _Demo.signals ? 210 : 16,
                bottom: 184,
                child: DialogueChoicesWidget(
                  runner: r,
                  backgroundColor: const Color(0xCC0A1628),
                  selectedColor: const Color(0xFF1E3A5F),
                  showUnavailable: true,
                  choiceStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  unavailableStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ),

            // Dialogue box
            if (r != null)
              Positioned(
                left: 16,
                right: _demo == _Demo.signals ? 210 : 16,
                bottom: 16,
                child: DialogueBoxWidget(
                  runner: r,
                  onTap: r.advance,
                  height: 160,
                  typewriterSpeed: 38,
                  portraitBuilder: _buildPortrait,
                  boxDecoration: BoxDecoration(
                    color: const Color(0xF0060D18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _demo.accentColor.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  characterNameStyle: TextStyle(
                    color: _demo.accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),

            // Advance button — bottom-right, visible only when a line is ready
            if (r != null)
              Positioned(
                right: _demo == _Demo.signals ? 218 : 16,
                bottom: 184,
                child: _AdvanceButton(
                  accentColor: _demo.accentColor,
                  onTap:
                      (r.signals.hasLine.value && !r.signals.hasChoices.value)
                      ? r.advance
                      : null,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPortrait(String character) {
    final color = _characterColor(character);
    final initial = character.isNotEmpty ? character[0].toUpperCase() : '?';
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Canvas overlays
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildVariablesPanel() {
    final vars = _vars;
    if (vars == null) return const SizedBox.shrink();
    final gold = vars.getOrDefault<int>('gold', 10);
    final hasSword = vars.getOrDefault<bool>('hasSword', false);

    return Positioned(
      top: 12,
      right: 12,
      child: _overlayPanel(
        accentColor: const Color(0xFFAB47BC),
        title: 'DialogueVariableStore',
        children: [
          _monitorRow(
            '\$gold',
            '$gold',
            gold >= 8 ? const Color(0xFF66BB6A) : const Color(0xFFFF5252),
          ),
          _monitorRow(
            '\$hasSword',
            '$hasSword',
            hasSword ? const Color(0xFF66BB6A) : const Color(0xFF78909C),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandLog() {
    return Positioned(
      top: 12,
      left: 12,
      child: _overlayPanel(
        accentColor: const Color(0xFFFF7043),
        title: 'Command Log',
        children: [
          for (final entry in _commandLog.take(6))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                entry,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          if (_commandLog.isEmpty)
            const Text(
              'no commands yet',
              style: TextStyle(color: Colors.white30, fontSize: 10),
            ),
        ],
      ),
    );
  }

  Widget _buildSignalMonitor() {
    final sig = _runner?.signals;

    final isActive = sig?.isDialogueActive.value ?? false;
    final hasLine = sig?.hasLine.value ?? false;
    final hasChoices = sig?.hasChoices.value ?? false;
    final speaker = sig?.activeSpeaker.value;
    final node = sig?.activeNodeTitle.value;
    final line = sig?.currentLine.value;
    final choices = sig?.choices.value ?? const [];

    return Positioned(
      right: 8,
      top: 8,
      bottom: 8,
      width: 186,
      child: _overlayPanel(
        accentColor: const Color(0xFFFFCA28),
        title: 'NarrativeSignals',
        minWidth: 170,
        children: [
          _monitorRow(
            'isDialogueActive',
            isActive ? 'true' : 'false',
            isActive ? const Color(0xFF66BB6A) : const Color(0xFF78909C),
          ),
          _monitorRow(
            'hasLine',
            hasLine ? 'true' : 'false',
            hasLine ? const Color(0xFF66BB6A) : const Color(0xFF78909C),
          ),
          _monitorRow(
            'hasChoices',
            hasChoices ? 'true' : 'false',
            hasChoices ? const Color(0xFFFFCA28) : const Color(0xFF78909C),
          ),
          _monitorRow(
            'activeSpeaker',
            speaker ?? 'null',
            const Color(0xFF29B6F6),
          ),
          _monitorRow(
            'activeNodeTitle',
            node ?? 'null',
            const Color(0xFF80DEEA),
          ),
          const SizedBox(height: 6),
          const Text(
            'currentLine.text:',
            style: TextStyle(color: Colors.white54, fontSize: 9),
          ),
          const SizedBox(height: 2),
          Text(
            line == null
                ? 'null'
                : '"${line.text.length > 38 ? '${line.text.substring(0, 38)}…' : line.text}"',
            style: const TextStyle(color: Colors.white, fontSize: 9),
            maxLines: 3,
          ),
          if (choices.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'choices (${choices.length}):',
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
            for (final c in choices)
              Text(
                '[${c.index}] ${c.text.length > 22 ? '${c.text.substring(0, 22)}…' : c.text}'
                '${c.isAvailable ? '' : ' ✗'}',
                style: TextStyle(
                  color: c.isAvailable ? Colors.white70 : Colors.white30,
                  fontSize: 9,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _overlayPanel({
    required Color accentColor,
    required String title,
    required List<Widget> children,
    double? minWidth,
  }) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth ?? 140, maxWidth: 200),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        border: Border.all(color: accentColor.withOpacity(0.45), width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accentColor,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          ...children,
        ],
      ),
    );
  }

  Widget _monitorRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 9.5),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Demo selector
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDemoSelector() {
    return Container(
      color: const Color(0xFF060D18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Color(0xFF1A2A3A)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: _Demo.values.map((d) => _demoChip(d)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _demoChip(_Demo d) {
    final isActive = _demo == d;
    return GestureDetector(
      onTap: isActive ? null : () => _buildDemo(d),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? d.accentColor.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? d.accentColor.withOpacity(0.85)
                : Colors.white.withOpacity(0.15),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              d.icon,
              color: isActive ? d.accentColor : Colors.white38,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              d.label,
              style: TextStyle(
                color: isActive ? d.accentColor : Colors.white38,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Control panel
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildControlPanel() {
    return Container(
      color: const Color(0xFF060D18),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: _buildDemoControls(),
    );
  }

  Widget _buildDemoControls() {
    final r = _runner;
    final isRunning = r?.signals.isDialogueActive.value ?? false;
    final hasLine = r?.signals.hasLine.value ?? false;
    final hasChoices = r?.signals.hasChoices.value ?? false;
    final canAdvance = isRunning && hasLine && !hasChoices;

    return Row(
      children: [
        _actionButton(
          'Start',
          _demo.accentColor,
          !isRunning ? _startDialogue : null,
        ),
        const SizedBox(width: 8),
        _actionButton(
          'Stop',
          const Color(0xFF78909C),
          isRunning ? _stopDialogue : null,
        ),
        const SizedBox(width: 8),
        _actionButton(
          'Advance',
          Colors.white24,
          canAdvance ? () => r!.advance() : null,
        ),
        const Spacer(),
        // Demo-specific extras
        if (_demo == _Demo.hubSpoke && isRunning) ...[
          Text(
            'Current node: ${r?.signals.activeNodeTitle.value ?? '—'}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
        if (_demo == _Demo.commands && isRunning)
          Text(
            'Flash: ${_flashColor != null ? "active" : "off"}',
            style: TextStyle(
              color: _flashColor != null
                  ? const Color(0xFFFF7043)
                  : Colors.white38,
              fontSize: 11,
            ),
          ),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled ? color.withOpacity(0.7) : Colors.white12,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? color : Colors.white24,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Code card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCodeCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 190),
        decoration: BoxDecoration(
          color: const Color(0xFF04080F),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _demo.accentColor.withOpacity(0.30),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              decoration: BoxDecoration(
                color: _demo.accentColor.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.code, color: _demo.accentColor, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    'Code — ${_demo.label}',
                    style: TextStyle(
                      color: _demo.accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable snippet
            SizedBox(
              height: 120,
              width: double.infinity,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _demo.codeSnippet,
                  style: const TextStyle(
                    color: Color(0xFFCDD9E5),
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

// =============================================================================
// Advance button overlay
// =============================================================================

class _AdvanceButton extends StatefulWidget {
  const _AdvanceButton({required this.accentColor, required this.onTap});
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  State<_AdvanceButton> createState() => _AdvanceButtonState();
}

class _AdvanceButtonState extends State<_AdvanceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: enabled ? 1.0 : 0.3,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _pressed
                ? widget.accentColor.withOpacity(0.30)
                : widget.accentColor.withOpacity(0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.accentColor.withOpacity(0.70),
              width: 1.5,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.25),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            color: widget.accentColor,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Background painter
// =============================================================================

class _WorldPainter extends CustomPainter {
  const _WorldPainter(this.accentColor);
  final Color accentColor;

  static const _dots = [
    (0.12, 0.18),
    (0.72, 0.12),
    (0.88, 0.48),
    (0.52, 0.30),
    (0.28, 0.68),
    (0.64, 0.62),
    (0.92, 0.72),
    (0.08, 0.52),
    (0.46, 0.82),
    (0.76, 0.28),
    (0.35, 0.45),
    (0.58, 0.78),
    (0.20, 0.88),
    (0.84, 0.22),
    (0.42, 0.58),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()..style = PaintingStyle.fill;
    for (final (fx, fy) in _dots) {
      final c = Offset(fx * size.width, fy * size.height);
      glow.color = accentColor.withOpacity(0.055);
      canvas.drawCircle(c, 36, glow);
      glow.color = accentColor.withOpacity(0.028);
      canvas.drawCircle(c, 58, glow);
    }

    // Subtle grid
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.028)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const step = 56.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(_WorldPainter old) => old.accentColor != accentColor;
}
