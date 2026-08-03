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

  /// True when the ingredient name reads as a spice/seasoning.
  static bool isSpice(String name) {
    final normalized = name.toLowerCase().trim();
    if (normalized.isEmpty) return false;
    if (keywords.contains(normalized)) return true;
    for (final keyword in keywords) {
      // Match whole-word occurrences (e.g. "ground black pepper").
      if (normalized == keyword ||
          normalized.contains(' $keyword') ||
          normalized.contains('$keyword ') ||
          normalized.endsWith(keyword)) {
        // Avoid false positives like "salted butter" or "peppermint".
        if (keyword == 'salt' && normalized.contains('salted')) continue;
        if (keyword == 'mint' && normalized.contains('peppermint')) continue;
        if (keyword == 'pepper' && normalized.contains('bell pepper')) continue;
        return true;
      }
    }
    return false;
  }
}
