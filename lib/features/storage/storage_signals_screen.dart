import 'package:flutter/material.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_storage/just_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  signals,
  persistence,
  profile,
  storage;

  String get label => switch (this) {
    signals => 'Reactive Signals',
    persistence => 'Persistence',
    profile => 'Player Profile',
    storage => 'Key-Value Store',
  };

  IconData get icon => switch (this) {
    signals => Icons.bolt,
    persistence => Icons.save_outlined,
    profile => Icons.person_outline,
    storage => Icons.storage_outlined,
  };

  Color get accentColor => switch (this) {
    signals => const Color(0xFF29B6F6),
    persistence => const Color(0xFF66BB6A),
    profile => const Color(0xFFAB47BC),
    storage => const Color(0xFFFF7043),
  };

  String get description => switch (this) {
    signals =>
      'Signal<T> holds a reactive value. SignalBuilder rebuilds only the widget '
          'that observes it — no setState, no streams, no controllers.',
    persistence =>
      'Pair a Signal with JustStorage: writes go to disk, reads restore the '
          'value on next launch. The UI stays reactive throughout.',
    profile =>
      'Multiple signals composing a player profile. Each field persists '
          'independently; SignalBuilder scopes rebuilds to exactly the changed field.',
    storage =>
      'JustStorage is an async key-value store. Write arbitrary String values, '
          'read them back, and reflect changes live in the signal-driven UI.',
  };

  String get codeSnippet => switch (this) {
    signals =>
      '// Create a reactive value:\n'
          'final counter = Signal<int>(0);\n\n'
          '// Mutate from anywhere — every listener rebuilds:\n'
          'counter.value += 1;\n\n'
          '// Subscribe a widget (no setState needed):\n'
          'SignalBuilder<int>(\n'
          '  signal: counter,\n'
          '  builder: (context, value, _) {\n'
          "    return Text('Count: \$value');\n"
          '  },\n'
          ');',
    persistence =>
      '// Restore from storage on startup:\n'
          "final raw = await storage.read('counter');\n"
          'final counter = Signal<int>(\n'
          '  raw != null ? int.parse(raw) : 0,\n'
          ');\n\n'
          '// Persist every change:\n'
          'counter.value = newValue;\n'
          "await storage.write('counter', newValue.toString());",
    profile =>
      '// Independent signals per field:\n'
          "final name  = Signal<String>('Guest');\n"
          'final score = Signal<int>(0);\n\n'
          '// Scoped rebuilds — only changed field rerenders:\n'
          'SignalBuilder<String>(signal: name, ...)\n'
          'SignalBuilder<int>(signal: score, ...)\n\n'
          '// Persist independently:\n'
          'name.value = newName;\n'
          "await storage.write('player_name', newName);",
    storage =>
      '// Open the default storage:\n'
          'final storage = await JustStorage.standard();\n\n'
          '// Write a value:\n'
          "await storage.write('sfx_volume', '0.8');\n\n"
          '// Read it back (null if missing):\n'
          "final vol = await storage.read('sfx_volume');\n\n"
          '// Values are String; parse as needed:\n'
          "double.tryParse(vol ?? '1.0') ?? 1.0;",
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class StorageSignalsScreen extends StatefulWidget {
  const StorageSignalsScreen({super.key});

  @override
  State<StorageSignalsScreen> createState() => _StorageSignalsScreenState();
}

class _StorageSignalsScreenState extends State<StorageSignalsScreen> {
  // ── State ────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.signals;
  bool _loading = true;
  String _statusMessage = 'Initializing…';

  // ── Storage ──────────────────────────────────────────────────────────────
  late final JustStandardStorage _storage;

  // ── Signals (initialized immediately; persisted ones updated after load) ─
  final Signal<int> _counterSignal = Signal<int>(0);
  final Signal<int> _persistedCounterSignal = Signal<int>(0);
  final Signal<String> _playerNameSignal = Signal<String>('Guest');
  final Signal<int> _highScoreSignal = Signal<int>(0);

  // Tracks what we know is in storage (refreshed after every write)
  final Map<String, String> _storedEntries = {};

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initializeStorage();
  }

  Future<void> _initializeStorage() async {
    try {
      _storage = await JustStorage.standard();
      await _loadPersistedValues();
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

  Future<void> _loadPersistedValues() async {
    final counter = await _storage.read('counter');
    if (counter != null)
      _persistedCounterSignal.value = int.tryParse(counter) ?? 0;

    final name = await _storage.read('player_name');
    if (name != null) _playerNameSignal.value = name;

    final score = await _storage.read('high_score');
    if (score != null) _highScoreSignal.value = int.tryParse(score) ?? 0;

    await _refreshStoredEntries();
  }

  Future<void> _refreshStoredEntries() async {
    _storedEntries.clear();
    for (final key in const [
      'counter',
      'player_name',
      'high_score',
      'sfx_volume',
      'bgm_volume',
    ]) {
      final val = await _storage.read(key);
      if (val != null) _storedEntries[key] = val;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions — signals demo
  // ─────────────────────────────────────────────────────────────────────────

  void _incrementCounter(int amount) {
    _counterSignal.value += amount;
    setState(() => _statusMessage = 'signal.value = ${_counterSignal.value}');
  }

  void _resetCounter() {
    _counterSignal.value = 0;
    setState(() => _statusMessage = 'Signal reset to 0');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions — persistence demo
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _incrementPersisted(int amount) async {
    final v = _persistedCounterSignal.value + amount;
    _persistedCounterSignal.value = v;
    await _storage.write('counter', v.toString());
    await _refreshStoredEntries();
    setState(() => _statusMessage = 'Saved "counter" = "$v"');
  }

  Future<void> _resetPersisted() async {
    _persistedCounterSignal.value = 0;
    await _storage.write('counter', '0');
    await _refreshStoredEntries();
    setState(() => _statusMessage = 'Counter reset and saved');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions — profile demo
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _addScore(int amount) async {
    final v = _highScoreSignal.value + amount;
    _highScoreSignal.value = v;
    await _storage.write('high_score', v.toString());
    await _refreshStoredEntries();
    setState(() => _statusMessage = 'Score saved: $v');
  }

  Future<void> _resetScore() async {
    _highScoreSignal.value = 0;
    await _storage.write('high_score', '0');
    await _refreshStoredEntries();
    setState(() => _statusMessage = 'Score reset');
  }

  void _showNameDialog() {
    final ctrl = TextEditingController(text: _playerNameSignal.value);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1A2A),
        title: const Text('Edit Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Player name',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: _Demo.profile.accentColor.withValues(alpha: 0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _Demo.profile.accentColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              _playerNameSignal.value = name;
              await _storage.write('player_name', name);
              await _refreshStoredEntries();
              setState(() => _statusMessage = 'Name saved: "$name"');
            },
            child: Text(
              'Save',
              style: TextStyle(color: _Demo.profile.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions — storage demo
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _writeStorageEntry(String key, String value) async {
    await _storage.write(key, value);
    await _refreshStoredEntries();
    setState(() => _statusMessage = 'Written: $key = "$value"');
  }

  Future<void> _readStorageKey(String key) async {
    final val = await _storage.read(key);
    setState(
      () => _statusMessage = val != null
          ? 'Read: $key = "$val"'
          : 'Key "$key" not found in storage',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stats line
  // ─────────────────────────────────────────────────────────────────────────

  String get _statsLine {
    if (_loading) return _statusMessage;
    return switch (_demo) {
      _Demo.signals =>
        'signal.value: ${_counterSignal.value}'
            '  type: Signal<int>'
            '  reactive: true',
      _Demo.persistence =>
        'counter: ${_persistedCounterSignal.value}'
            '  key: "counter"'
            '  entries: ${_storedEntries.length}',
      _Demo.profile =>
        'name: "${_playerNameSignal.value}"'
            '  score: ${_highScoreSignal.value}'
            '  stored keys: ${_storedEntries.length}',
      _Demo.storage =>
        'entries: ${_storedEntries.length}'
            '  keys: [${_storedEntries.keys.join(", ")}]',
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildDemoArea()),
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
                'just_signals  ·  Signal<T>  ·  SignalBuilder  ·  JustStorage',
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

  Widget _buildDemoArea() {
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

    return switch (_demo) {
      _Demo.signals => _buildSignalsArea(),
      _Demo.persistence => _buildPersistenceArea(),
      _Demo.profile => _buildProfileArea(),
      _Demo.storage => _buildStorageArea(),
    };
  }

  // ── Signals area ──────────────────────────────────────────────────────────

  Widget _buildSignalsArea() {
    return Container(
      color: const Color(0xFF060D18),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt,
              color: _demo.accentColor.withValues(alpha: 0.35),
              size: 48,
            ),
            const SizedBox(height: 6),
            Text(
              'Signal<int>',
              style: TextStyle(
                color: _demo.accentColor.withValues(alpha: 0.5),
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 22),
              decoration: BoxDecoration(
                color: _demo.accentColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _demo.accentColor.withValues(alpha: 0.35),
                ),
              ),
              child: SignalBuilder<int>(
                signal: _counterSignal,
                builder: (context, value, _) => Text(
                  '$value',
                  style: TextStyle(
                    color: _demo.accentColor,
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'counter.value',
              style: TextStyle(
                color: _demo.accentColor.withValues(alpha: 0.55),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Only the number above rebuilds when the signal changes',
              style: TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ── Persistence area ──────────────────────────────────────────────────────

  Widget _buildPersistenceArea() {
    return Container(
      color: const Color(0xFF060D18),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.save_outlined,
                  color: _demo.accentColor.withValues(alpha: 0.5),
                  size: 20,
                ),
                const SizedBox(width: 7),
                Text(
                  'Persisted to disk',
                  style: TextStyle(
                    color: _demo.accentColor.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 22),
              decoration: BoxDecoration(
                color: _demo.accentColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _demo.accentColor.withValues(alpha: 0.35),
                ),
              ),
              child: SignalBuilder<int>(
                signal: _persistedCounterSignal,
                builder: (context, value, _) => Text(
                  '$value',
                  style: TextStyle(
                    color: _demo.accentColor,
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF090F1A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1E2E40)),
              ),
              child: const Text(
                'storage.write("counter", value.toString())',
                style: TextStyle(
                  color: Color(0xFF80CBC4),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Value survives app restarts',
              style: TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ── Profile area ──────────────────────────────────────────────────────────

  Widget _buildProfileArea() {
    return Container(
      color: const Color(0xFF060D18),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _demo.accentColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _demo.accentColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    color: _demo.accentColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Player Profile',
                    style: TextStyle(
                      color: _demo.accentColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const SizedBox(
                    width: 44,
                    child: Text(
                      'Name',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                  SignalBuilder<String>(
                    signal: _playerNameSignal,
                    builder: (_, name, __) => Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(
                color: _demo.accentColor.withValues(alpha: 0.2),
                height: 22,
              ),
              Row(
                children: [
                  const SizedBox(
                    width: 44,
                    child: Text(
                      'Score',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                  SignalBuilder<int>(
                    signal: _highScoreSignal,
                    builder: (_, score, __) => Text(
                      '$score',
                      style: TextStyle(
                        color: _demo.accentColor,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.save_outlined, size: 12, color: Colors.white24),
                  const SizedBox(width: 5),
                  const Text(
                    'Both fields persisted via JustStorage',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Storage area ──────────────────────────────────────────────────────────

  Widget _buildStorageArea() {
    if (_storedEntries.isEmpty) {
      return Container(
        color: const Color(0xFF060D18),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storage_outlined, color: Colors.white12, size: 48),
              const SizedBox(height: 12),
              const Text(
                'No entries yet',
                style: TextStyle(color: Colors.white30, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                'Use the buttons below to write values',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF060D18),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Stored entries (${_storedEntries.length})',
            style: TextStyle(
              color: _demo.accentColor.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ..._storedEntries.entries.map(
            (e) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF090F1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1A2535)),
              ),
              child: Row(
                children: [
                  Text(
                    e.key,
                    style: TextStyle(
                      color: _demo.accentColor,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '→',
                    style: TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '"${e.value}"',
                    style: const TextStyle(
                      color: Color(0xFF80CBC4),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
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
                  onSelected: (_) => setState(() {
                    _demo = d;
                    _statusMessage = '';
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Control panel
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildControlPanel() {
    return Container(
      color: const Color(0xFF060D18),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: _loading
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
            )
          : _buildDemoControls(),
    );
  }

  Widget _buildDemoControls() {
    return switch (_demo) {
      _Demo.signals => _buildSignalsControls(),
      _Demo.persistence => _buildPersistenceControls(),
      _Demo.profile => _buildProfileControls(),
      _Demo.storage => _buildStorageControls(),
    };
  }

  Widget _buildSignalsControls() {
    return Row(
      children: [
        _actionButton('+1', _demo.accentColor, () => _incrementCounter(1)),
        const SizedBox(width: 6),
        _actionButton('+5', _demo.accentColor, () => _incrementCounter(5)),
        const SizedBox(width: 6),
        _actionButton('+10', _demo.accentColor, () => _incrementCounter(10)),
        const SizedBox(width: 10),
        _actionButton('Reset', const Color(0xFF546E7A), _resetCounter),
        const SizedBox(width: 12),
        const Text(
          'No setState — SignalBuilder drives the update',
          style: TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildPersistenceControls() {
    return Row(
      children: [
        _actionButton('+10', _demo.accentColor, () => _incrementPersisted(10)),
        const SizedBox(width: 6),
        _actionButton(
          '+100',
          _demo.accentColor,
          () => _incrementPersisted(100),
        ),
        const SizedBox(width: 10),
        _actionButton('Reset', const Color(0xFF546E7A), _resetPersisted),
        const SizedBox(width: 12),
        const Text(
          'Restart the app — the value persists',
          style: TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildProfileControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton('Edit Name', _demo.accentColor, _showNameDialog),
        _actionButton('+10 Score', _demo.accentColor, () => _addScore(10)),
        _actionButton('+100 Score', _demo.accentColor, () => _addScore(100)),
        _actionButton('Reset Score', const Color(0xFF546E7A), _resetScore),
      ],
    );
  }

  Widget _buildStorageControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton(
          'Write sfx: 0.8',
          _demo.accentColor,
          () => _writeStorageEntry('sfx_volume', '0.8'),
        ),
        _actionButton(
          'Write bgm: 0.5',
          _demo.accentColor,
          () => _writeStorageEntry('bgm_volume', '0.5'),
        ),
        _actionButton(
          'Read sfx',
          _demo.accentColor,
          () => _readStorageKey('sfx_volume'),
        ),
        _actionButton(
          'Read bgm',
          _demo.accentColor,
          () => _readStorageKey('bgm_volume'),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Code card
  // ─────────────────────────────────────────────────────────────────────────

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
                  'just_signals  ·  just_storage',
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
