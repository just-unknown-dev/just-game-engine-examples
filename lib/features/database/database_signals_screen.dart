import 'package:flutter/material.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_database/just_database.dart';

class DatabaseSignalsScreen extends StatefulWidget {
  const DatabaseSignalsScreen({super.key});

  @override
  State<DatabaseSignalsScreen> createState() => _DatabaseSignalsScreenState();
}

class _DatabaseSignalsScreenState extends State<DatabaseSignalsScreen> {
  // Signal to hold the list of players mapping
  late Signal<List<Map<String, dynamic>>> _playersSignal;
  late Signal<int> _totalPlayersSignal;

  late JustDatabase _db;
  bool _isDbReady = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Initialize the in-memory/standard database for demo purposes
    _db = await JustDatabase.open('demo_db');

    // Create the table
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS players (
        id INTEGER PRIMARY KEY,
        name TEXT,
        score INTEGER
      )
    ''');

    // Seed defaults only when the table is empty so data persists across launches.
    final countResult = await _db.query(
      'SELECT COUNT(*) AS total FROM players',
    );
    final totalPlayers = countResult.success && countResult.rows.isNotEmpty
        ? (countResult.rows.first['total'] as num?)?.toInt() ?? 0
        : 0;

    // Fetch initial data
    final records = await _fetchPlayers();

    // Initialize our list signal
    _playersSignal = Signal<List<Map<String, dynamic>>>(records);
    _totalPlayersSignal = Signal<int>(totalPlayers);

    setState(() {
      _isDbReady = true;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchPlayers() async {
    final result = await _db.query('SELECT * FROM players ORDER BY score DESC');
    if (!result.success) return [];

    return result.rows
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  Future<void> _addRandomPlayer() async {
    final now = DateTime.now().microsecondsSinceEpoch;
    final newId = now % 1000000000;
    final randomScore = (now % 100) + 10;
    final playerName = 'Player_$newId';
    final safePlayerName = playerName.replaceAll("'", "''");

    final insertResult = await _db.execute(
      "INSERT INTO players (id, name, score) VALUES ($newId, '$safePlayerName', $randomScore)",
    );

    if (!insertResult.success) {
      if (mounted) {
        final error = insertResult.errorMessage ?? 'Unknown database error';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add player: $error')));
      }
      return;
    }

    // Refresh the signal data
    final players = await _fetchPlayers();
    _playersSignal.value = players;
    _totalPlayersSignal.value = players.length;
  }

  Future<void> _clearPlayers() async {
    final clearResult = await _db.execute('DELETE FROM players');

    if (!clearResult.success) {
      if (mounted) {
        final error = clearResult.errorMessage ?? 'Unknown database error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear players: $error')),
        );
      }
      return;
    }

    // Refresh the signal data
    final players = await _fetchPlayers();
    _playersSignal.value = players;
    _totalPlayersSignal.value = players.length;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDbReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Database & Signals',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Demonstrates how just_signals (reactive state) pairs with just_database (Local pure-dart SQL) to reflect queries in the UI effortlessly.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),

          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _addRandomPlayer,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Random Player'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _clearPlayers,
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Clear All'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
              ),
              const Spacer(),
              SignalBuilder<int>(
                signal: _totalPlayersSignal,
                builder: (context, totalPlayers, child) => Text(
                  'Total Players: $totalPlayers',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blueGrey.withValues(alpha: 0.3),
                ),
              ),
              child: SignalBuilder<List<Map<String, dynamic>>>(
                signal: _playersSignal,
                builder: (context, players, child) {
                  if (players.isEmpty) {
                    return const Center(
                      child: Text(
                        'No players found in database.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: players.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: Colors.white12),
                    itemBuilder: (context, index) {
                      final player = players[index];
                      // Note: just_database records often return columns as keys
                      final id = player['id']?.toString() ?? '?';
                      final name = player['name']?.toString() ?? 'Unknown';
                      final score = player['score']?.toString() ?? '0';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.shade800,
                          child: Text(
                            '#${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'ID: $id',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: Text(
                          '$score pts',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
