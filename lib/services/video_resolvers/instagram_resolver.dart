import 'package:http/http.dart' as http;
import 'video_resolver.dart';

/// Best-effort resolver for Instagram reels/posts.
///
/// Instagram has no official/stable API for reading arbitrary public media, so
/// this scrapes Open Graph meta tags (and embedded JSON as a fallback) using a
/// crawler user-agent. It is inherently fragile and WILL break periodically;
/// when extraction fails it degrades gracefully, returning whatever it found
/// (possibly nothing) so the UI can fall back to a link-only import.
class InstagramResolver implements VideoResolver {
  static const Map<String, String> _crawlerHeaders = {
    // Facebook's crawler UA tends to receive Open Graph tags for public media.
    'User-Agent':
        'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  @override
  bool canHandle(String url) => url.toLowerCase().contains('instagram.com');

  @override
  Future<ResolvedVideo> resolve(
    String url, {
    void Function(String status)? onProgress,
  }) async {
    final cleanUrl = _stripQuery(url);
    String html = '';
    try {
      onProgress?.call('Fetching post…');
      final response = await http.get(
        Uri.parse(cleanUrl),
        headers: _crawlerHeaders,
      );
      if (response.statusCode == 200) {
        html = response.body;
      }
    } catch (_) {}

    final title = _metaContent(html, 'og:title');
    final rawDescription = _metaContent(html, 'og:description') ?? '';
    final caption = _extractCaption(rawDescription);
    final imageUrl = _metaContent(html, 'og:image');
    final videoUrl = _metaContent(html, 'og:video') ?? _embeddedVideoUrl(html);

    // Download whatever media we located (Instagram exposes a single quality;
    // there is no reliable on-device path to force 480p, so we save as-is).
    String? videoPath;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      onProgress?.call('Downloading video…');
      videoPath = await RecipeMediaStorage.downloadToFile(
        videoUrl,
        '${RecipeMediaStorage.safeName(cleanUrl)}.mp4',
        headers: _crawlerHeaders,
      );
    }

    String? thumbPath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      thumbPath = await RecipeMediaStorage.downloadToFile(
        imageUrl,
        '${RecipeMediaStorage.safeName(cleanUrl)}_thumb.jpg',
        headers: _crawlerHeaders,
      );
    }

    return ResolvedVideo(
      platform: VideoPlatform.instagram,
      sourceUrl: url,
      title: title,
      caption: caption,
      videoLocalPath: videoPath,
      thumbnailPath: thumbPath,
    );
  }

  String _stripQuery(String url) {
    final index = url.indexOf('?');
    return index == -1 ? url : url.substring(0, index);
  }

  /// Reads `<meta property="X" content="...">` (either attribute order).
  String? _metaContent(String html, String property) {
    if (html.isEmpty) return null;
    final patterns = [
      RegExp(
        '<meta[^>]*property="${RegExp.escape(property)}"[^>]*content="([^"]*)"',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]*content="([^"]*)"[^>]*property="${RegExp.escape(property)}"',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        final value = match.group(1);
        if (value != null && value.isNotEmpty) return _unescapeHtml(value);
      }
    }
    return null;
  }

  /// Fallback: pull a `"video_url":"..."` value out of embedded JSON.
  String? _embeddedVideoUrl(String html) {
    if (html.isEmpty) return null;
    final match = RegExp(r'"video_url":"([^"]+)"').firstMatch(html);
    if (match == null) return null;
    return _unescapeJson(match.group(1)!);
  }

  /// Instagram's og:description looks like:
  ///   `123 likes, 45 comments - user on Instagram: "the real caption"`
  /// Extract the quoted caption when present, otherwise return the whole string.
  String _extractCaption(String description) {
    if (description.isEmpty) return '';
    final quoted = RegExp(r'[:]\s*"([\s\S]*)"\s*$').firstMatch(description);
    if (quoted != null) return quoted.group(1)!.trim();
    return description.trim();
  }

  String _unescapeJson(String input) {
    return input
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\"', '"');
  }

  String _unescapeHtml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&#064;', '@')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
