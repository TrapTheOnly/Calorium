import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker/utils/spice_list.dart';

void main() {
  group('SpiceList keeps true seasonings', () {
    test('salt and pepper', () {
      expect(SpiceList.isSpice('salt'), isTrue);
      expect(SpiceList.isSpice('black pepper'), isTrue);
      expect(SpiceList.isSpice('ground black pepper'), isTrue);
    });

    test('dried herbs and common spices', () {
      expect(SpiceList.isSpice('dried oregano'), isTrue);
      expect(SpiceList.isSpice('cumin'), isTrue);
      expect(SpiceList.isSpice('garlic powder'), isTrue);
      expect(SpiceList.isSpice('onion powder'), isTrue);
      expect(SpiceList.isSpice('chili powder'), isTrue);
    });
  });

  group('SpiceList rejects lookalikes', () {
    test('peppermint is not mint', () {
      expect(SpiceList.isSpice('peppermint'), isFalse);
    });

    test('salted butter is not salt', () {
      expect(SpiceList.isSpice('salted butter'), isFalse);
    });

    test('bell pepper is not pepper', () {
      expect(SpiceList.isSpice('bell pepper'), isFalse);
    });
  });

  group('SpiceList rejects caloric ingredients', () {
    test('sugars and syrups', () {
      expect(SpiceList.isSpice('sugar'), isFalse);
      expect(SpiceList.isSpice('cinnamon sugar'), isFalse);
      expect(SpiceList.isSpice('honey'), isFalse);
      expect(SpiceList.isSpice('maple syrup'), isFalse);
      expect(SpiceList.isSpice('molasses'), isFalse);
    });

    test('oils, milks, flours, butter, aminos', () {
      expect(SpiceList.isSpice('olive oil'), isFalse);
      expect(SpiceList.isSpice('chili oil'), isFalse);
      expect(SpiceList.isSpice('almond milk'), isFalse);
      expect(SpiceList.isSpice('almond flour'), isFalse);
      expect(SpiceList.isSpice('butter'), isFalse);
      expect(SpiceList.isSpice('coconut aminos'), isFalse);
    });

    test('coconut products are not spices', () {
      expect(SpiceList.isSpice('coconut'), isFalse);
      expect(SpiceList.isSpice('coconut powder'), isFalse);
      expect(SpiceList.isSpice('coconut milk'), isFalse);
      expect(SpiceList.isSpice('coconut flakes'), isFalse);
      expect(SpiceList.isSpice('coconut oil'), isFalse);
      expect(SpiceList.isSpice('coconut sugar'), isFalse);
    });
  });
}
