import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/favorites/data/favorites_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('favorites are added removed and persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = FavoritesController();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state, isEmpty);

    await controller.toggle('space-1');
    expect(controller.state, {'space-1'});

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('freiraum_favorite_parking_ids'),
      ['space-1'],
    );

    await controller.toggle('space-1');
    expect(controller.state, isEmpty);
  });
}
