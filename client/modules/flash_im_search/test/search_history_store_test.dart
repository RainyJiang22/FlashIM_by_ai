import 'package:flash_im_search/flash_im_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSearchHistoryStore.key: [
        for (var index = 0; index < 20; index++) '历史$index',
      ],
    });
  });

  test(
    'history trims, deduplicates, moves to front and caps at twenty',
    () async {
      const store = SharedPreferencesSearchHistoryStore();

      final inserted = await store.save('  新关键词  ');
      expect(inserted, hasLength(20));
      expect(inserted.first, '新关键词');
      expect(inserted.last, '历史18');

      final moved = await store.save('历史5');
      expect(moved.first, '历史5');
      expect(moved.where((item) => item == '历史5'), hasLength(1));
    },
  );

  test('history clears persisted values', () async {
    const store = SharedPreferencesSearchHistoryStore();
    await store.clear();
    expect(await store.load(), isEmpty);
  });
}
