import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine_examples/features/features_list.dart';

void main() {
  test('feature list contains the Just Debugger showcase', () {
    expect(
      appFeatures.any((feature) => feature.title == 'Just Debugger'),
      isTrue,
    );
  });
}
