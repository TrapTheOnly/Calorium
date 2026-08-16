import 'dart:math' as math;
import '../models/food.dart';

/// One inventory food ranked against a recipe ingredient, with a 0..1 score.
class MatchCandidate {
  final Food food;
  final double score;
  const MatchCandidate(this.food, this.score);
}

/// How confidently an ingredient was matched to inventory.
enum MatchConfidence { strong, weak, none }

/// The full match result for a single recipe ingredient.
class IngredientMatch {
  final String ingredientName;
  final List<MatchCandidate> candidates; // ranked, highest score first

  const IngredientMatch(this.ingredientName, this.candidates);

  MatchConfidence get confidence {
    if (candidates.isEmpty) return MatchConfidence.none;
    final best = candidates.first.score;
    if (best >= InventoryMatcher.autoThreshold) return MatchConfidence.strong;
    if (best >= InventoryMatcher.minThreshold) return MatchConfidence.weak;
    return MatchConfidence.none;
  }

  MatchCandidate? get best => candidates.isEmpty ? null : candidates.first;
}

/// A local, token-based fuzzy matcher that maps recipe ingredient names to
/// inventory foods WITHOUT sending the inventory to the AI.
///
/// Algorithm:
///  1. Build once: normalize + tokenize every inventory name into an inverted
///     index (token -> food indices) with IDF weights.
///  2. Per ingredient: gather candidate foods that share >=1 token (fast,
///     sub-linear vs a full scan); if none share a token, fall back to a bounded
///     edit-distance scan over all foods.
///  3. Score each candidate with a weighted blend of IDF-weighted token overlap,
///     normalized Levenshtein similarity, and a substring/prefix bonus.
///  4. Penalize form mismatches (powder vs milk vs oil) so they cannot auto-select.
///  5. Classify by the top score (strong / weak / none) and return the top-K.
class InventoryMatcher {
  static const double autoThreshold = 0.85;
  static const double minThreshold = 0.35;

  static const Set<String> _stopWords = {
    'of', 'the', 'a', 'an', 'and', 'with', 'to', 'for', 'in',
    'fresh', 'chopped', 'diced', 'sliced', 'minced', 'raw', 'cooked',
    'large', 'small', 'medium', 'boneless', 'skinless', 'ripe', 'whole',
    'frozen', 'canned', 'organic', 'lean', 'extra', 'virgin',
    'peeled', 'crushed', 'finely', 'roughly',
    // measurement words that add no matching signal
    'cup', 'cups', 'tbsp', 'tsp', 'tablespoon', 'tablespoons', 'teaspoon',
    'teaspoons', 'g', 'kg', 'gram', 'grams', 'ml', 'l', 'oz', 'lb', 'pinch',
    'clove', 'cloves', 'slice', 'slices', 'piece', 'pieces',
  };

  final List<Food> foods;
  final List<Set<String>> _tokenSets = [];
  final List<Set<String>> _formSets = [];
  final List<String> _normalized = [];
  final Map<String, Set<int>> _invertedIndex = {};
  final Map<String, double> _idf = {};

  InventoryMatcher(this.foods) {
    _build();
  }

  void _build() {
    for (var i = 0; i < foods.length; i++) {
      final norm = _normalize(foods[i].name);
      final tokens = _tokenize(norm);
      _normalized.add(norm);
      _tokenSets.add(tokens);
      _formSets.add(_formTokens(norm));
      for (final token in tokens) {
        _invertedIndex.putIfAbsent(token, () => <int>{}).add(i);
      }
    }
    final total = foods.isEmpty ? 1 : foods.length;
    _invertedIndex.forEach((token, ids) {
      // Smoothed IDF: rarer tokens carry more matching weight.
      _idf[token] = math.log((total + 1) / (ids.length + 1)) + 1.0;
    });
  }

  /// Matches [rawName] and returns up to [topK] ranked candidates.
  IngredientMatch match(String rawName, {int topK = 5}) {
    final norm = _normalize(rawName);
    final tokens = _tokenize(norm);
    if (foods.isEmpty) return IngredientMatch(rawName, const []);

    // 1. Candidate gather via the inverted index (token overlap).
    final candidateIds = <int>{};
    for (final token in tokens) {
      final ids = _invertedIndex[token];
      if (ids != null) candidateIds.addAll(ids);
    }

    // 2. Fallback: if nothing shares a token, scan everything (small N).
    final Iterable<int> pool =
        candidateIds.isNotEmpty ? candidateIds : Iterable.generate(foods.length);

    final scored = <MatchCandidate>[];
    for (final id in pool) {
      final score = _score(norm, tokens, id);
      if (score > 0) scored.add(MatchCandidate(foods[id], score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final top = scored.take(topK).toList();
    return IngredientMatch(rawName, top);
  }

  double _score(String queryNorm, Set<String> queryTokens, int foodId) {
    final foodNorm = _normalized[foodId];
    final foodTokens = _tokenSets[foodId];
    final queryForms = _formTokens(queryNorm);
    final foodForms = _formSets[foodId];
    final formsMatch = _setEquals(queryForms, foodForms);
    final queryCovered = queryTokens.isNotEmpty &&
        queryTokens.every(foodTokens.contains);

    if (queryNorm.isEmpty || foodNorm.isEmpty) return 0;
    if (queryNorm == foodNorm) return 1.0;

    // IDF-weighted token coverage (how much of the query is covered).
    double sharedIdf = 0, queryIdf = 0;
    for (final token in queryTokens) {
      final weight = _idf[token] ?? 1.0;
      queryIdf += weight;
      if (foodTokens.contains(token)) sharedIdf += weight;
    }
    final coverage = queryIdf > 0 ? sharedIdf / queryIdf : 0.0;

    // Jaccard over token sets (guards against matching very long names).
    final union = queryTokens.union(foodTokens).length;
    final intersection = queryTokens.intersection(foodTokens).length;
    final jaccard = union > 0 ? intersection / union : 0.0;

    // Normalized Levenshtein similarity on the full strings.
    final lev = _levenshteinSimilarity(queryNorm, foodNorm);

    // Substring / prefix bonus. Do not award 1.0 when token sets differ
    // because of a missing form (e.g. "coconut" inside "coconut powder").
    double substring = 0;
    final contained =
        foodNorm.contains(queryNorm) || queryNorm.contains(foodNorm);
    if (contained && formsMatch && queryCovered) {
      substring = 1.0;
    } else if (foodTokens.any(
      (t) => queryTokens.any((q) => t.startsWith(q) || q.startsWith(t)),
    )) {
      substring = 0.5;
    }

    final tokenScore = (0.7 * coverage) + (0.3 * jaccard);
    var score = (0.6 * tokenScore) + (0.3 * lev) + (0.1 * substring);

    if (!formsMatch) {
      // Form mismatch (powder vs milk vs flakes vs oil, or form vs none).
      score *= 0.15;
    } else if (queryCovered) {
      // True equivalent: distinctive query tokens (including form) are
      // covered. Food may add modifiers (unsweetened, extra virgin).
      score = math.max(score, autoThreshold);
    }

    return score.clamp(0.0, 1.0);
  }

  String _normalize(String input) {
    var s = input.toLowerCase();
    // Drop parenthetical notes.
    s = s.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    // Drop leading quantities like "2", "1/2", "200g".
    s = s.replaceAll(RegExp(r'\b\d+([./]\d+)?\s*'), ' ');
    // Replace non-letters with spaces.
    s = s.replaceAll(RegExp(r'[^a-z\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  Set<String> _tokenize(String normalized) {
    final tokens = <String>{};
    for (final raw in normalized.split(' ')) {
      if (raw.isEmpty) continue;
      if (_stopWords.contains(raw)) continue;
      tokens.add(_singularize(raw));
    }
    return tokens;
  }

  Set<String> _formTokens(String normalized) {
    final forms = <String>{};
    for (final raw in normalized.split(' ')) {
      if (raw.isEmpty) continue;
      final canonical = _canonicalForm(raw);
      if (canonical != null) forms.add(canonical);
    }
    return forms;
  }

  String? _canonicalForm(String word) {
    final direct = _formCanonical[word];
    if (direct != null) return direct;
    return _formCanonical[_singularize(word)];
  }

  static const Map<String, String> _formCanonical = {
    'powder': 'powder',
    'milk': 'milk',
    'oil': 'oil',
    'flour': 'flour',
    'flake': 'flake',
    'flakes': 'flake',
    'flak': 'flake',
    'cream': 'cream',
    'butter': 'butter',
    'sugar': 'sugar',
    'juice': 'juice',
    'sauce': 'sauce',
    'paste': 'paste',
    'water': 'water',
    'yogurt': 'yogurt',
    'yoghurt': 'yogurt',
    'cheese': 'cheese',
    'chees': 'cheese',
    'desiccated': 'desiccated',
    'shredded': 'shredded',
    'extract': 'extract',
  };

  String _singularize(String word) {
    if (word == 'flakes') return 'flake';
    if (word.length > 3 && word.endsWith('ies')) {
      return '${word.substring(0, word.length - 3)}y';
    }
    if (word.length > 3 && word.endsWith('es')) {
      return word.substring(0, word.length - 2);
    }
    if (word.length > 3 && word.endsWith('s')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  double _levenshteinSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    final distance = _levenshtein(a, b);
    final maxLen = math.max(a.length, b.length);
    if (maxLen == 0) return 1.0;
    return 1.0 - (distance / maxLen);
  }

  int _levenshtein(String a, String b) {
    final m = a.length, n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;

    var previous = List<int>.generate(n + 1, (i) => i);
    var current = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      current[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      final tmp = previous;
      previous = current;
      current = tmp;
    }
    return previous[n];
  }
}
