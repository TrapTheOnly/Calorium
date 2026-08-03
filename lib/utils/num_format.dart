/// Formats numeric nutrition values consistently across the app.
///
/// Rounds to at most one decimal place and strips a trailing zero so values
/// read cleanly (e.g. `111`, `4.5`, `22.3`) rather than `111.0` / `4.50`.
String fmtNum(num value) {
  final d = value.toDouble();
  if (d.isNaN || d.isInfinite) return '0';
  final rounded = (d * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) {
    return rounded.toStringAsFixed(0);
  }
  final s = rounded.toStringAsFixed(1);
  return s;
}

/// Formats a nutrition value as a whole number (no decimals).
///
/// Used in dense list contexts (e.g. the inventory) where minimalistic,
/// uniform-width numbers matter more than precision. Tapping into an item still
/// shows the finer [fmtNum] value.
String fmtWhole(num value) {
  final d = value.toDouble();
  if (d.isNaN || d.isInfinite) return '0';
  return d.round().toString();
}
