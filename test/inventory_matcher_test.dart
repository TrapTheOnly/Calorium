import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker/models/food.dart';
import 'package:calorie_tracker/services/inventory_matcher_service.dart';

Food _food(int id, String name) {
  return Food(
    id: id,
    name: name,
    calories: 100,
    fat: 2,
    carbs: 3,
    protein: 4,
  );
}

IngredientMatch _match(String query, List<Food> inventory) {
  return InventoryMatcher(inventory).match(query);
}

void main() {
  test('autoThreshold is 0.85 so only true equivalents auto-select', () {
    expect(InventoryMatcher.autoThreshold, 0.85);
    expect(InventoryMatcher.minThreshold, 0.35);
  });

  test('empty inventory yields none and no candidates', () {
    final match = _match('coconut powder', const []);
    expect(match.confidence, MatchConfidence.none);
    expect(match.candidates, isEmpty);
    expect(match.best, isNull);
  });

  test('coconut powder does not match Coconut', () {
    final match = _match('coconut powder', [_food(1, 'Coconut')]);
    expect(match.confidence, MatchConfidence.none);
    if (match.best != null) {
      expect(match.best!.score, lessThan(InventoryMatcher.minThreshold));
    }
  });

  test('coconut powder does not match Coconut flakes', () {
    final match = _match('coconut powder', [_food(1, 'Coconut flakes')]);
    expect(match.confidence, MatchConfidence.none);
  });

  test('coconut powder does not match Coconut milk', () {
    final match = _match('coconut powder', [_food(1, 'Coconut milk')]);
    expect(match.confidence, MatchConfidence.none);
  });

  test('coconut powder strongly matches Coconut powder', () {
    final match = _match('coconut powder', [_food(1, 'Coconut powder')]);
    expect(match.confidence, MatchConfidence.strong);
    expect(match.best!.food.name, 'Coconut powder');
  });

  test('coconut powder strongly matches Unsweetened coconut powder', () {
    final match = _match(
      'coconut powder',
      [_food(1, 'Unsweetened coconut powder')],
    );
    expect(match.confidence, MatchConfidence.strong);
    expect(match.best!.food.name, 'Unsweetened coconut powder');
  });

  test('generic milk does not strongly match Coconut milk', () {
    final match = _match('milk', [_food(1, 'Coconut milk')]);
    expect(match.confidence, isNot(MatchConfidence.strong));
  });

  test('generic powder does not strongly match Coconut powder', () {
    final match = _match('powder', [_food(1, 'Coconut powder')]);
    expect(match.confidence, isNot(MatchConfidence.strong));
  });

  test('olive oil strongly matches Extra virgin olive oil', () {
    final match = _match(
      'olive oil',
      [_food(1, 'Extra virgin olive oil')],
    );
    expect(match.confidence, MatchConfidence.strong);
    expect(match.best!.food.name, 'Extra virgin olive oil');
  });

  test('chicken breast does not strongly match Chicken thighs', () {
    final match = _match('chicken breast', [_food(1, 'Chicken thighs')]);
    expect(match.confidence, isNot(MatchConfidence.strong));
  });

  test('match returns topK ranked candidates for the dropdown', () {
    final inventory = [
      _food(1, 'Coconut'),
      _food(2, 'Coconut flakes'),
      _food(3, 'Coconut milk'),
      _food(4, 'Coconut powder'),
      _food(5, 'Olive oil'),
    ];
    final match = InventoryMatcher(inventory).match('coconut powder', topK: 3);

    expect(match.candidates.length, lessThanOrEqualTo(3));
    expect(match.candidates, isNotEmpty);
    expect(match.best!.food.name, 'Coconut powder');
    expect(match.confidence, MatchConfidence.strong);
    for (var i = 1; i < match.candidates.length; i++) {
      expect(
        match.candidates[i].score,
        lessThanOrEqualTo(match.candidates[i - 1].score),
      );
    }
  });
}
