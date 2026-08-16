/// Gemini prompt text for recipe import. Matching owns the wording.
class RecipeImportPrompts {
  RecipeImportPrompts._();

  static String recipeParser({required String sourceText}) {
    return '''
You are a careful recipe parser. Below is the text (title, caption/description,
and possibly a pinned comment) from a cooking video shared by a user.

SOURCE TEXT:
"""
$sourceText
"""

TASK:
1. Decide whether this text describes a cookable food recipe. If it clearly does
   NOT (e.g. it is a vlog, a product ad, or has no ingredients), set
   "isRecipe": false and leave the other fields empty.
2. If it IS a recipe, extract it. Infer sensible ingredient amounts when the
   text is vague, and write clear step-by-step instructions even if the caption
   only implies them.
3. For EACH ingredient also estimate "amountGrams": the quantity in grams (or
   millilitres for liquids) as a plain number, so nutrition can be computed.
4. Mark ONLY true zero-calorie seasonings (salt, pepper, dried herbs, spices
   used in pinches) with "isSpice": true. Do NOT mark sugar, honey, oils,
   coconut products, flours, milks, or other caloric ingredients as spices.

Respond with ONLY a valid JSON object in EXACTLY this shape, no extra text:

{
  "isRecipe": true,
  "recipeName": "A short, appetising name",
  "description": "One or two sentences describing the dish",
  "servings": 2,
  "prepTimeMinutes": 10,
  "cookTimeMinutes": 20,
  "difficulty": "easy|medium|hard",
  "tags": ["dinner", "high-protein"],
  "ingredients": [
    {
      "name": "unsweetened coconut powder",
      "amount": "2 tbsp",
      "amountGrams": 16,
      "unit": "g",
      "isSpice": false,
      "notes": "unsweetened"
    }
  ],
  "instructions": ["Step 1 ...", "Step 2 ..."]
}

Rules:
- "unit" must be "g" for solids or "ml" for liquids.
- "amountGrams" must be a positive number (never a string).
- Keep ingredient "name" SPECIFIC. Preserve form words (powder, milk, oil,
  flour, flakes, cream). Never collapse "coconut powder" to "coconut".
- Never substitute. Do not replace coconut powder with coconut, coconut
  flakes, coconut milk, or coconut oil — or any other "close enough" food.
- Put extra prep detail in "notes", not by deleting form words from "name".
''';
  }

  static String nearestMatch({required String itemsText}) {
    return '''
You match recipe ingredients to a user's pantry. For each ingredient below,
choose the SINGLE candidate that is the SAME product — same food and same form
(powder vs milk vs flakes vs oil). Substitutes are forbidden. "Close enough"
is not a match: coconut powder is not coconut, coconut flakes, coconut milk,
or coconut oil. If none of the candidates is the same ingredient, use null.

INGREDIENTS AND CANDIDATES:
$itemsText

Respond with ONLY a valid JSON object mapping each ingredient name to the chosen
candidate string (exactly as written) or null. Example:
{"coconut powder": null, "tomato": "Cherry tomatoes"}
''';
  }

  static String nutritionEstimate({required String namesText}) {
    return '''
Estimate typical USDA-style nutrition per 100 grams (or per 100 ml for liquids)
for each ingredient below. Use the EXACT product named — never a substitute.
Coconut powder is not coconut, coconut flakes, coconut milk, or coconut oil.
If you are unsure, give a conservative typical value for that exact product.

INGREDIENTS:
$namesText

Respond with ONLY a valid JSON object mapping each ingredient name to:
{"calories": 0, "protein": 0, "carbs": 0, "fat": 0}
Numbers must be per 100 g/ml, never per serving.
''';
  }
}
