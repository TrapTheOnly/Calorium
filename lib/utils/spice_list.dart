/// Spices and seasonings are assumed to always be on hand, so they are never
/// matched against the inventory and are excluded from nutrition calculations.
///
/// Used as a local safety net in addition to the AI's own `isSpice` flag.
class SpiceList {
  SpiceList._();

  static const Set<String> keywords = {
    'salt',
    'pepper',
    'peppercorn',
    'black pepper',
    'white pepper',
    'cayenne',
    'paprika',
    'chili powder',
    'chilli powder',
    'chili flakes',
    'chilli flakes',
    'red pepper flakes',
    'cumin',
    'coriander',
    'turmeric',
    'cinnamon',
    'nutmeg',
    'clove',
    'cloves',
    'cardamom',
    'allspice',
    'oregano',
    'basil',
    'thyme',
    'rosemary',
    'sage',
    'bay leaf',
    'bay leaves',
    'parsley',
    'dill',
    'mint',
    'ginger powder',
    'garlic powder',
    'onion powder',
    'mustard powder',
    'curry powder',
    'garam masala',
    'saffron',
    'vanilla',
    'vanilla extract',
    'baking powder',
    'baking soda',
    'yeast',
    'seasoning',
    'spice',
    'spices',
    'herbs',
    'zaatar',
    "za'atar",
    'sumac',
    'fennel seeds',
    'star anise',
    'msg',
    'stock cube',
    'bouillon',
  };

  static final RegExp _caloricWord = RegExp(
    r'\b(sugar|honey|syrup|molasses|aminos|oil|milk|flour|butter)\b',
  );

  static final RegExp _coconutProduct = RegExp(
    r'\b(powder|milk|flake|flakes|oil|sugar|cream|water|butter)\b',
  );

  static final RegExp _spiceBlend = RegExp(
    r'\b(spice|spices|seasoning|masala|blend)\b',
  );

  /// True when the ingredient name reads as a spice/seasoning.
  static bool isSpice(String name) {
    final normalized = name.toLowerCase().trim();
    if (normalized.isEmpty) return false;
    if (_isCaloricIngredient(normalized)) return false;

    for (final keyword in keywords) {
      if (!_hasKeyword(normalized, keyword)) continue;
      // Whole-food names that happen to contain a spice word.
      if (keyword == 'pepper' && _hasKeyword(normalized, 'bell pepper')) {
        continue;
      }
      return true;
    }
    return false;
  }

  static bool _isCaloricIngredient(String normalized) {
    if (_caloricWord.hasMatch(normalized)) return true;
    if (!normalized.contains('coconut')) return false;
    // Coconut powder/milk/flakes/oil/sugar are foods, not spices.
    if (_coconutProduct.hasMatch(normalized)) return true;
    // A named coconut spice blend is still a seasoning.
    if (_spiceBlend.hasMatch(normalized)) return false;
    return true;
  }

  static bool _hasKeyword(String normalized, String keyword) {
    return RegExp('\\b${RegExp.escape(keyword)}\\b').hasMatch(normalized);
  }
}
