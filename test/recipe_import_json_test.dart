import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker/services/recipe_import_service.dart';

void main() {
  group('RecipeImportService.decodeJsonObject', () {
    test('strips ```json fences', () {
      const raw = '''```json
{"isRecipe": true, "recipeName": "Pasta"}
```''';
      final map = RecipeImportService.decodeJsonObject(raw);
      expect(map, isNotNull);
      expect(map!['isRecipe'], true);
      expect(map['recipeName'], 'Pasta');
    });

    test('strips bare ``` fences', () {
      const raw = '''```
{"a": 1, "b": "x"}
```''';
      final map = RecipeImportService.decodeJsonObject(raw);
      expect(map, isNotNull);
      expect(map!['a'], 1);
      expect(map['b'], 'x');
    });

    test('extracts {..} from surrounding prose', () {
      const raw =
          'Sure, here you go:\n{"name": "Soup", "nested": {"ok": true}}\nHope that helps!';
      final map = RecipeImportService.decodeJsonObject(raw);
      expect(map, isNotNull);
      expect(map!['name'], 'Soup');
      expect(map['nested'], isA<Map>());
      expect((map['nested'] as Map)['ok'], true);
    });

    test('returns null for a JSON array', () {
      expect(RecipeImportService.decodeJsonObject('[1, 2]'), isNull);
    });

    test('returns null for invalid text', () {
      expect(RecipeImportService.decodeJsonObject('not json at all'), isNull);
    });
  });
}
