import 'package:flutter_test/flutter_test.dart';
import 'package:just_game_engine_examples/features/features_list.dart';

void main() {
  test('feature titles are unique', () {
    final titles = appFeatures.map((f) => f.title).toList();
    expect(titles.toSet().length, titles.length);
  });

  test('the 2.x feature demos are registered', () {
    final titles = appFeatures.map((f) => f.title).toSet();
    expect(
      titles,
      containsAll(<String>[
        '2D Lighting & Shadows',
        '2D Materials',
        'Timelines',
        'Scenes & Prefabs',
        '3D Graphics',
        '3D Physics',
      ]),
    );
  });

  test('core engine and rendering are one feature', () {
    final titles = appFeatures.map((f) => f.title).toSet();
    expect(titles, contains('Core Engine & Rendering'));
    expect(titles, isNot(contains('Core Engine')));
    expect(titles, isNot(contains('Rendering Engine')));
  });
}
