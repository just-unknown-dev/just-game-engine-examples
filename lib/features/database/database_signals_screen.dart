import 'package:flutter/material.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_database/just_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo mode
// ─────────────────────────────────────────────────────────────────────────────

enum _Demo {
  leaderboard,
  crud,
  query,
  signals;

  String get label => switch (this) {
    leaderboard => 'Leaderboard',
    crud => 'CRUD',
    query => 'Raw Query',
    signals => 'Reactive Signals',
  };

  IconData get icon => switch (this) {
    leaderboard => Icons.emoji_events_outlined,
    crud => Icons.edit_note_outlined,
    query => Icons.manage_search_outlined,
    signals => Icons.bolt,
  };

  Color get accentColor => switch (this) {
    leaderboard => const Color(0xFFFFCA28),
    crud => const Color(0xFF66BB6A),
    query => const Color(0xFF26C6DA),
    signals => const Color(0xFFAB47BC),
  };

  String get description => switch (this) {
    leaderboard =>
      'Players table ordered by score DESC. SignalBuilder rebuilds the list '
          'every time the signal is mutated — no setState or streams required.',
    crud =>
      'INSERT, UPDATE, and DELETE rows via just_database. After each operation '
          'the signal is refreshed, keeping the UI in sync automatically.',
    query =>
      'Execute raw SQL SELECT statements and stream the result rows directly '
          'into a Signal<List<Map>>. The view reacts to every refresh.',
    signals =>
      'Multiple Signal<T> instances — one per aggregate stat. Each SignalBuilder '
          'scopes its rebuild to exactly the field that changed.',
  };

  String get codeSnippet => switch (this) {
    leaderboard =>
      '// Open the database:\n'
          "final db = await JustDatabase.open('game_db');\n\n"
          '// Create schema:\n'
          'await db.execute(\'\'\'\n'
          '  CREATE TABLE IF NOT EXISTS players (\n'
          '    id INTEGER PRIMARY KEY,\n'
          '    name TEXT,\n'
          '    score INTEGER\n'
          '  )\n'
          '\'\'\');\n\n'
          '// Query and bind to a signal:\n'
          "final result = await db.query(\n"
          "  'SELECT * FROM players ORDER BY score DESC',\n"
          ');\n'
          'playersSignal.value = result.rows;',
    crud =>
      '// INSERT:\n'
          'await db.execute(\n'
          "  'INSERT INTO players (name, score) VALUES (?, ?)',\n"
          "  [playerName, score],\n"
          ');\n\n'
          '// UPDATE:\n'
          'await db.execute(\n'
          "  'UPDATE players SET score = ? WHERE id = ?',\n"
          '  [newScore, id],\n'
          ');\n\n'
          '// DELETE:\n'
          "await db.execute('DELETE FROM players WHERE id = ?', [id]);\n\n"
          '// Refresh signal after mutation:\n'
          'playersSignal.value = await _fetchPlayers();',
    query =>
      '// Ad-hoc SELECT:\n'
          'final result = await db.query(\n'
          "  'SELECT name, score FROM players\n"
          "   WHERE score > 50\n"
          "   ORDER BY score DESC\n"
          "   LIMIT 5',\n"
          ');\n\n'
          'if (result.success) {\n'
          '  for (final row in result.rows) {\n'
          "    print('\${row[\"name\"]} — \${row[\"score\"]}');\n"
          '  }\n'
          '}',
    signals =>
      '// One signal per aggregate:\n'
          'final total   = Signal<int>(0);\n'
          'final topName = Signal<String>(\'\');\n'
          'final topScore = Signal<int>(0);\n\n'
          '// Update independently — only the changed widget rebuilds:\n'
          'total.value   = players.length;\n'
          'topScore.value = players.first[\'score\'] as int;\n\n'
          '// Bind in the widget tree:\n'
          'SignalBuilder<int>(signal: topScore, ...)',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class DatabaseSignalsScreen extends StatefulWidget {
  const DatabaseSignalsScreen({super.key});

  @override
  State<DatabaseSignalsScreen> createState() => _DatabaseSignalsScreenState();
}

class _DatabaseSignalsScreenState extends State<DatabaseSignalsScreen> {
  // ── State ────────────────────────────────────────────────────────────────
  _Demo _demo = _Demo.leaderboard;
  bool _loading = true;
  String _statusMessage = 'Opening database…';

  // ── Database ─────────────────────────────────────────────────────────────
  late JustDatabase _db;

  // ── Signals ──────────────────────────────────────────────────────────────
  final Signal<List<Map<String, dynamic>>> _playersSignal =
      Signal<List<Map<String, dynamic>>>([]);
  final Signal<int> _totalSignal = Signal<int>(0);
  final Signal<String> _topNameSignal = Signal<String>('—');
  final Signal<int> _topScoreSignal = Signal<int>(0);
  final Signal<int> _avgScoreSignal = Signal<int>(0);

  // Raw query demo
  String _lastSql = '';
  List<Map<String, dynamic>> _queryRows = [];

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    try {
      _db = await JustDatabase.open('demo_db');
      await _db.execute('''
        CREATE TABLE IF NOT EXISTS players (
          id INTEGER PRIMARY KEY,
          name TEXT,
          score INTEGER
        )
      ''');
      await _refresh();
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
  // Data helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchPlayers() async {
    final result = await _db.query('SELECT * FROM players ORDER BY score DESC');
    if (!result.success) return [];
    return result.rows
        .map((r) => r.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  Future<void> _refresh() async {
    final players = await _fetchPlayers();
    _playersSignal.value = players;
    _totalSignal.value = players.length;
    if (players.isNotEmpty) {
      _topNameSignal.value = players.first['name']?.toString() ?? '—';
      _topScoreSignal.value = (players.first['score'] as num?)?.toInt() ?? 0;
      final total = players.fold<int>(
        0,
        (s, r) => s + ((r['score'] as num?)?.toInt() ?? 0),
      );
      _avgScoreSignal.value = players.isEmpty
          ? 0
          : (total / players.length).round();
    } else {
      _topNameSignal.value = '—';
      _topScoreSignal.value = 0;
      _avgScoreSignal.value = 0;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _addRandomPlayer() async {
    final now = DateTime.now().microsecondsSinceEpoch;
    final id = now % 1000000000;
    final score = (now % 90) + 10;
    final names = [
      'ArrowStrike',
      'BlazeRunner',
      'CrystalMage',
      'DuskHunter',
      'EmberWolf',
      'FrostBlade',
      'GlitchKnight',
      'HexCaster',
    ];
    final name = names[id % names.length];
    final safeName = name.replaceAll("'", "''");

    final res = await _db.execute(
      "INSERT INTO players (id, name, score) VALUES ($id, '$safeName', $score)",
    );
    if (res.success) {
      await _refresh();
      setState(() => _statusMessage = 'Inserted $name (score $score)');
    } else {
      setState(() => _statusMessage = 'Insert failed: ${res.errorMessage}');
    }
  }

  Future<void> _updateTopScore() async {
    final players = _playersSignal.value;
    if (players.isEmpty) {
      setState(() => _statusMessage = 'No players to update');
      return;
    }
    final id = players.first['id'];
    final newScore = (_topScoreSignal.value + 50).clamp(0, 9999);
    final res = await _db.execute(
      'UPDATE players SET score = $newScore WHERE id = $id',
    );
    if (res.success) {
      await _refresh();
      setState(() => _statusMessage = 'Updated top player score → $newScore');
    }
  }

  Future<void> _deleteLastPlayer() async {
    final players = _playersSignal.value;
    if (players.isEmpty) {
      setState(() => _statusMessage = 'No players to delete');
      return;
    }
    final id = players.last['id'];
    final name = players.last['name'];
    final res = await _db.execute('DELETE FROM players WHERE id = $id');
    if (res.success) {
      await _refresh();
      setState(() => _statusMessage = 'Deleted $name');
    }
  }

  Future<void> _clearAll() async {
    final res = await _db.execute('DELETE FROM players');
    if (res.success) {
      await _refresh();
      setState(() => _statusMessage = 'Table cleared');
    }
  }

  Future<void> _runQuery(String sql) async {
    _lastSql = sql;
    final result = await _db.query(sql);
    if (result.success) {
      setState(() {
        _queryRows = result.rows
            .map((r) => r.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
        _statusMessage = '${_queryRows.length} row(s) returned';
      });
    } else {
      setState(() {
        _queryRows = [];
        _statusMessage = 'Query error: ${result.errorMessage}';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stats line
  // ─────────────────────────────────────────────────────────────────────────

  String get _statsLine {
    if (_loading) return _statusMessage;
    final total = _totalSignal.value;
    return switch (_demo) {
      _Demo.leaderboard =>
        'rows: $total'
            '  top: ${_topNameSignal.value}'
            '  top score: ${_topScoreSignal.value}'
            '  avg: ${_avgScoreSignal.value}',
      _Demo.crud =>
        'rows: $total'
            '  top score: ${_topScoreSignal.value}'
            '  avg: ${_avgScoreSignal.value}',
      _Demo.query =>
        'rows: $total'
            '  last query returned: ${_queryRows.length}'
            '  db: demo_db',
      _Demo.signals =>
        'total: $total'
            '  top: ${_topNameSignal.value}'
            '  top score: ${_topScoreSignal.value}'
            '  avg: ${_avgScoreSignal.value}',
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
                'just_database  ·  JustDatabase  ·  Signal<T>  ·  SignalBuilder',
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
      _Demo.leaderboard => _buildLeaderboardArea(),
      _Demo.crud => _buildCrudArea(),
      _Demo.query => _buildQueryArea(),
      _Demo.signals => _buildSignalsArea(),
    };
  }

  // ── Leaderboard area ──────────────────────────────────────────────────────

  Widget _buildLeaderboardArea() {
    return Container(
      color: const Color(0xFF060D18),
      child: SignalBuilder<List<Map<String, dynamic>>>(
        signal: _playersSignal,
        builder: (context, players, _) {
          if (players.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    color: Colors.white12,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No players yet',
                    style: TextStyle(color: Colors.white30, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Use "Add Player" to insert rows',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: players.length,
            itemBuilder: (context, i) {
              final p = players[i];
              final name = p['name']?.toString() ?? '?';
              final score = (p['score'] as num?)?.toInt() ?? 0;
              final rankColor = i == 0
                  ? const Color(0xFFFFCA28)
                  : i == 1
                  ? const Color(0xFFB0BEC5)
                  : i == 2
                  ? const Color(0xFFFF8A65)
                  : Colors.white38;

              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: i == 0
                      ? _demo.accentColor.withValues(alpha: 0.08)
                      : const Color(0xFF090F1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i == 0
                        ? _demo.accentColor.withValues(alpha: 0.4)
                        : const Color(0xFF1A2535),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '#${i + 1}',
                        style: TextStyle(
                          color: rankColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: i == 0 ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: i == 0
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      '$score pts',
                      style: TextStyle(
                        color: _demo.accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── CRUD area ─────────────────────────────────────────────────────────────

  Widget _buildCrudArea() {
    return Container(
      color: const Color(0xFF060D18),
      child: SignalBuilder<List<Map<String, dynamic>>>(
        signal: _playersSignal,
        builder: (context, players, _) {
          if (players.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note_outlined,
                    color: Colors.white12,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Table is empty',
                    style: TextStyle(color: Colors.white30, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Use "Add Player" to insert a row',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: players.length,
            itemBuilder: (context, i) {
              final p = players[i];
              final name = p['name']?.toString() ?? '?';
              final score = (p['score'] as num?)?.toInt() ?? 0;
              final id = p['id']?.toString() ?? '?';

              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF090F1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1A2535)),
                ),
                child: Row(
                  children: [
                    Text(
                      'id:$id',
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '$score pts',
                      style: TextStyle(
                        color: _demo.accentColor,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Query area ────────────────────────────────────────────────────────────

  Widget _buildQueryArea() {
    if (_lastSql.isEmpty) {
      return Container(
        color: const Color(0xFF060D18),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.manage_search_outlined,
                color: Colors.white12,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'No query run yet',
                style: TextStyle(color: Colors.white30, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                'Use the preset queries below',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF060D18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF090F1A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _demo.accentColor.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              _lastSql,
              style: const TextStyle(
                color: Color(0xFF80CBC4),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: _queryRows.isEmpty
                ? const Center(
                    child: Text(
                      'No rows returned',
                      style: TextStyle(color: Colors.white30, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    itemCount: _queryRows.length,
                    itemBuilder: (context, i) {
                      final row = _queryRows[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090F1A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF1A2535)),
                        ),
                        child: Row(
                          children: row.entries
                              .map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(right: 18),
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${e.key}: ',
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        TextSpan(
                                          text: '${e.value}',
                                          style: TextStyle(
                                            color: _demo.accentColor,
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Signals area ──────────────────────────────────────────────────────────

  Widget _buildSignalsArea() {
    return Container(
      color: const Color(0xFF060D18),
      child: Center(
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _buildSignalCard(
              'Total Players',
              Icons.people_outline,
              const Color(0xFF29B6F6),
              SignalBuilder<int>(
                signal: _totalSignal,
                builder: (_, v, __) => _bigValue('$v'),
              ),
              'Signal<int>',
            ),
            _buildSignalCard(
              'Top Player',
              Icons.emoji_events_outlined,
              const Color(0xFFFFCA28),
              SignalBuilder<String>(
                signal: _topNameSignal,
                builder: (_, v, __) => _bigValue(v, size: 22),
              ),
              'Signal<String>',
            ),
            _buildSignalCard(
              'Top Score',
              Icons.star_outline,
              _demo.accentColor,
              SignalBuilder<int>(
                signal: _topScoreSignal,
                builder: (_, v, __) => _bigValue('$v pts'),
              ),
              'Signal<int>',
            ),
            _buildSignalCard(
              'Avg Score',
              Icons.analytics_outlined,
              const Color(0xFF66BB6A),
              SignalBuilder<int>(
                signal: _avgScoreSignal,
                builder: (_, v, __) => _bigValue('$v'),
              ),
              'Signal<int>',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalCard(
    String title,
    IconData icon,
    Color color,
    Widget valueWidget,
    String typeLabel,
  ) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          valueWidget,
          const SizedBox(height: 8),
          Text(
            typeLabel,
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigValue(String text, {double size = 28}) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: size,
        fontWeight: FontWeight.w700,
        fontFamily: 'monospace',
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
      _Demo.leaderboard => _buildLeaderboardControls(),
      _Demo.crud => _buildCrudControls(),
      _Demo.query => _buildQueryControls(),
      _Demo.signals => _buildSignalsControls(),
    };
  }

  Widget _buildLeaderboardControls() {
    return Row(
      children: [
        _actionButton('Add Player', _demo.accentColor, _addRandomPlayer),
        const SizedBox(width: 6),
        _actionButton('Clear All', const Color(0xFF546E7A), _clearAll),
        const SizedBox(width: 12),
        const Text(
          'SignalBuilder rebuilds the list on every insert',
          style: TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCrudControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton('Add Player', _demo.accentColor, _addRandomPlayer),
        _actionButton('+50 Top Score', _demo.accentColor, _updateTopScore),
        _actionButton(
          'Delete Last',
          const Color(0xFFEF5350),
          _deleteLastPlayer,
        ),
        _actionButton('Clear All', const Color(0xFF546E7A), _clearAll),
      ],
    );
  }

  Widget _buildQueryControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _actionButton(
          'All rows',
          _demo.accentColor,
          () => _runQuery('SELECT * FROM players ORDER BY score DESC'),
        ),
        _actionButton(
          'Score > 50',
          _demo.accentColor,
          () => _runQuery(
            'SELECT name, score FROM players WHERE score > 50 ORDER BY score DESC',
          ),
        ),
        _actionButton(
          'Top 3',
          _demo.accentColor,
          () => _runQuery(
            'SELECT name, score FROM players ORDER BY score DESC LIMIT 3',
          ),
        ),
        _actionButton(
          'Count',
          _demo.accentColor,
          () => _runQuery('SELECT COUNT(*) AS total FROM players'),
        ),
        _actionButton('Add Player', const Color(0xFF546E7A), _addRandomPlayer),
      ],
    );
  }

  Widget _buildSignalsControls() {
    return Row(
      children: [
        _actionButton('Add Player', _demo.accentColor, _addRandomPlayer),
        const SizedBox(width: 6),
        _actionButton('+50 Top Score', _demo.accentColor, _updateTopScore),
        const SizedBox(width: 6),
        _actionButton('Clear All', const Color(0xFF546E7A), _clearAll),
        const SizedBox(width: 12),
        const Text(
          'Each card rebuilds independently',
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
                  'just_database  ·  just_signals',
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
