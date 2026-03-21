import 'package:flutter/material.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_storage/just_storage.dart';

class StorageSignalsScreen extends StatefulWidget {
  const StorageSignalsScreen({super.key});

  @override
  State<StorageSignalsScreen> createState() => _StorageSignalsScreenState();
}

class _StorageSignalsScreenState extends State<StorageSignalsScreen> {
  // A signal to hold the user's high score.
  late Signal<int> _highScoreSignal;

  // A signal to hold the user's name.
  late Signal<String> _playerNameSignal;

  late final JustStandardStorage _storage;
  bool _isStorageReady = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Initialize storage instance
    _storage = await JustStorage.standard();

    // Read initial values from storage or default them
    final savedScoreString = await _storage.read('high_score');
    final savedScore = savedScoreString != null
        ? int.tryParse(savedScoreString) ?? 0
        : 0;

    final savedName = await _storage.read('player_name') ?? 'Guest';

    // Initialize our signals with the starting values
    _highScoreSignal = Signal(savedScore);
    _playerNameSignal = Signal(savedName);

    setState(() {
      _isStorageReady = true;
    });
  }

  void _incrementScore() async {
    final currentScore = _highScoreSignal.value;
    final newScore = currentScore + 10;

    // Update Signal (UI reacts automatically via SignalBuilder)
    _highScoreSignal.value = newScore;

    // Persist to storage
    await _storage.write('high_score', newScore.toString());
  }

  void _resetScore() async {
    // Update Signal
    _highScoreSignal.value = 0;

    // Persist to storage
    await _storage.write('high_score', '0');
  }

  void _updateName(String name) async {
    if (name.isEmpty) return;

    _playerNameSignal.value = name;
    await _storage.write('player_name', name);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isStorageReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Storage & Signals',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Demonstrates how just_signals (reactive state) pairs seamlessly with just_storage (key-value persistence) to keep the UI in sync with local data.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),

          // Player Profile Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Player Profile',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Reactive Name
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white54),
                    const SizedBox(width: 8),
                    SignalBuilder<String>(
                      signal: _playerNameSignal,
                      builder: (context, name, child) => Expanded(
                        child: Text(
                          'Name: $name',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showNameEditDialog(context),
                      child: const Text('Edit'),
                    ),
                  ],
                ),

                const Divider(color: Colors.white24, height: 30),

                // Reactive Score
                Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SignalBuilder<int>(
                        signal: _highScoreSignal,
                        builder: (context, score, child) => Text(
                          'High Score: $score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _incrementScore,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Points (+10)'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _resetScore,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNameEditDialog(BuildContext context) {
    final controller = TextEditingController(text: _playerNameSignal.value);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blueGrey.shade900,
        title: const Text(
          'Edit Player Name',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter name',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _updateName(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
