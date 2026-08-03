import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../utils/app_navigator.dart';
import '../screens/recipe_import_screen.dart';

/// Listens for Android "share to app" intents that carry a link and, when the
/// link points at a supported video platform (Instagram / YouTube), opens the
/// [RecipeImportScreen] so the shared recipe can be imported.
///
/// Wired up once from `main()`. Handles both a cold start (app launched by the
/// share) and a warm start (app already running).
class ShareIntentService {
  ShareIntentService._();

  static StreamSubscription<List<SharedMediaFile>>? _sub;
  static bool _initialized = false;

  static final RegExp _urlPattern = RegExp(
    r'https?:\/\/[^\s]+',
    caseSensitive: false,
  );

  static void init() {
    if (_initialized) return;
    _initialized = true;

    // Warm start: app already running when the user shares.
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleShared,
      onError: (_) {},
    );

    // Cold start: app launched by the share intent.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handleShared(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
  }

  static void _handleShared(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    String? url;
    for (final file in files) {
      if (file.type != SharedMediaType.text &&
          file.type != SharedMediaType.url) {
        continue;
      }
      final candidate = _extractUrl(file.path);
      if (candidate != null) {
        url = candidate;
        break;
      }
    }

    if (url == null) return;
    final resolved = url;

    if (!isSupportedRecipeUrl(resolved)) {
      _showMessage(
        'Only Instagram and YouTube links can be imported as recipes.',
      );
      return;
    }

    _openImport(resolved);
  }

  static String? _extractUrl(String text) {
    final match = _urlPattern.firstMatch(text);
    return match?.group(0);
  }

  /// True when [url] points at a platform we can attempt to import from.
  static bool isSupportedRecipeUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('instagram.com') ||
        lower.contains('youtube.com') ||
        lower.contains('youtu.be');
  }

  static void _openImport(String url) {
    // The navigator may not be mounted yet on a cold start; defer until it is.
    void push() {
      final nav = appNavigatorKey.currentState;
      if (nav == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => push());
        return;
      }
      nav.push(
        MaterialPageRoute(
          builder: (_) => RecipeImportScreen(sharedUrl: url),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => push());
  }

  static void _showMessage(String message) {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
  }
}
