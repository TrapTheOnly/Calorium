import '../theme/app_theme.dart';

/// Compact layout tokens for denser, consistent phone UI.
///
/// These now delegate to [AppTheme] so the app has a single source of truth for
/// spacing and radii. Prefer using [AppTheme] directly in new code.
class AppLayout {
  AppLayout._();

  static const double pagePadding = AppTheme.pagePadding;
  static const double sectionGap = AppTheme.space16;
  static const double cardPadding = AppTheme.space16;
  static const double cardPaddingCompact = AppTheme.space12;
  static const double radius = AppTheme.radiusMd;
  static const double radiusLarge = AppTheme.radiusLg;
  static const double listRowVertical = AppTheme.space12;
  static const double emptyIconSize = 32;
  static const double emptyTitleSize = 18;
  static const double emptyBodySize = 14;
  static const double headerTitleSize = 22;
  static const double bottomSpacer = AppTheme.space16;
}
