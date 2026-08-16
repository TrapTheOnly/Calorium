import 'dart:convert';
import 'package:http/http.dart' as http;
import 'video_resolver.dart';

/// Best-effort resolver for Instagram reels/posts.
///
/// Instagram has no official/stable API for reading arbitrary public media, so
/// this scrapes Open Graph meta tags (and embedded JSON as a fallback) using a
/// crawler user-agent. It is inherently fragile and WILL break periodically;
/// when extraction fails it degrades gracefully, returning whatever it found
/// (possibly nothing) so the UI can fall back to a pasted caption.
class InstagramResolver implements VideoResolver {
  static const Map<String, String> _crawlerHeaders = {
    // Facebook's crawler UA tends to receive Open Graph tags for public media.
    'User-Agent':
        'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static final RegExp _likesCommentsPrefix = RegExp(
    r'^\s*[\d,.]+[kKmMbB]?\s+likes?,?\s+[\d,.]+[kKmMbB]?\s+comments?',
    caseSensitive: false,
  );

  static final RegExp _quotedCaption = RegExp(r'[:]\s*"([\s\S]*)"\s*$');

  @override
  bool canHandle(String url) => url.toLowerCase().contains('instagram.com');

  @override
  Future<ResolvedVideo> resolve(
    String url, {
    void Function(String status)? onProgress,
  }) async {
    final cleanUrl = _stripQuery(url);
    onProgress?.call('Fetching post…');
    var html = await _fetchHtml(cleanUrl);

    var title = _metaContent(html, 'og:title');
    var imageUrl = _metaContent(html, 'og:image');
    var caption = captionFromHtml(html);

    if (caption.isEmpty) {
      onProgress?.call('Trying embed caption…');
      for (final embedUrl in _embedVariants(cleanUrl)) {
        final embedHtml = await _fetchHtml(embedUrl);
        if (embedHtml.isEmpty) continue;
        title ??= _metaContent(embedHtml, 'og:title');
        imageUrl ??= _metaContent(embedHtml, 'og:image');
        caption = captionFromHtml(embedHtml);
        if (caption.isNotEmpty) break;
      }
    }

    // We deliberately only save the poster image, not the video: reels can be
    // hundreds of MB, downloading them reliably is not feasible on-device, and a
    // thumbnail + "open original" link covers the use-case far more cheaply.
    String? thumbPath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      onProgress?.call('Fetching thumbnail…');
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
      thumbnailPath: thumbPath,
    );
  }

  /// Best-effort caption from already-fetched HTML (OG description + JSON).
  /// Returns empty when only the generic likes/comments shell is present.
  static String captionFromHtml(String html) {
    if (html.isEmpty) return '';

    final og = _metaContent(html, 'og:description') ?? '';
    final fromOg = extractCaption(og);
    if (fromOg.isNotEmpty) return fromOg;

    final fromJson = _captionFromJsonBlobs(html);
    if (fromJson.isNotEmpty) return fromJson;

    return '';
  }

  /// Instagram's og:description looks like:
  ///   `123 likes, 45 comments - user on Instagram: "the real caption"`
  /// Returns the quoted caption when present. Likes/comments-only shells
  /// (and empty quotes) become an empty string — never treated as a caption.
  static String extractCaption(String description) {
    if (description.isEmpty) return '';
    final quoted = _quotedCaption.firstMatch(description);
    if (quoted != null) {
      final caption = quoted.group(1)!.trim();
      if (caption.isEmpty || isLikesCommentsShell(caption)) return '';
      return caption;
    }
    if (isLikesCommentsShell(description)) return '';
    return description.trim();
  }

  /// True when [text] is Instagram engagement chrome with no real caption.
  static bool isLikesCommentsShell(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;
    if (!_likesCommentsPrefix.hasMatch(trimmed)) return false;

    final quoted = _quotedCaption.firstMatch(trimmed);
    if (quoted != null) {
      return quoted.group(1)!.trim().isEmpty;
    }
    return true;
  }

  static Future<String> _fetchHtml(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _crawlerHeaders,
      );
      if (response.statusCode == 200) return response.body;
    } catch (_) {}
    return '';
  }

  static String _stripQuery(String url) {
    final index = url.indexOf('?');
    return index == -1 ? url : url.substring(0, index);
  }

  static List<String> _embedVariants(String cleanUrl) {
    var base = cleanUrl;
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return [
      '$base/embed/captioned/',
      '$base/embed/',
    ];
  }

  /// Reads `<meta property="X" content="...">` (either attribute order / quotes).
  static String? _metaContent(String html, String property) {
    if (html.isEmpty) return null;
    final escaped = RegExp.escape(property);
    final patterns = [
      RegExp(
        '<meta[^>]*property="$escaped"[^>]*content="([^"]*)"',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]*content="([^"]*)"[^>]*property="$escaped"',
        caseSensitive: false,
      ),
      RegExp(
        "<meta[^>]*property='$escaped'[^>]*content='([^']*)'",
        caseSensitive: false,
      ),
      RegExp(
        "<meta[^>]*content='([^']*)'[^>]*property='$escaped'",
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

  static String _captionFromJsonBlobs(String html) {
    final scriptPattern = RegExp(
      r'<script[^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    );
    for (final match in scriptPattern.allMatches(html)) {
      final body = match.group(1) ?? '';
      if (body.length < 20) continue;
      final lower = body.toLowerCase();
      if (!lower.contains('caption') &&
          !lower.contains('articlebody') &&
          !lower.contains('edge_media_to_caption')) {
        continue;
      }
      final extracted = _captionFromScriptBody(body);
      if (extracted.isNotEmpty) return extracted;
    }
    return _captionFromInstagramKeys(html);
  }

  static String _captionFromScriptBody(String body) {
    var jsonText = body.trim();
    final assigned = RegExp(r'=\s*(\{[\s\S]*\})\s*;?\s*$').firstMatch(jsonText);
    if (assigned != null) {
      jsonText = assigned.group(1)!;
    }
    if (jsonText.startsWith('{') || jsonText.startsWith('[')) {
      try {
        final decoded = json.decode(jsonText);
        final found = _findCaptionInJson(decoded);
        if (found != null && found.isNotEmpty) return found;
      } catch (_) {}
    }
    return _captionFromInstagramKeys(body);
  }

  static String? _findCaptionInJson(
    dynamic node, {
    int depth = 0,
    String? parentKey,
  }) {
    if (depth > 14 || node == null) return null;

    if (node is Map) {
      final caption = node['caption'];
      if (caption is String) {
        final extracted = extractCaption(caption);
        if (extracted.isNotEmpty) return extracted;
      } else if (caption is Map && caption['text'] is String) {
        final extracted = extractCaption(caption['text'] as String);
        if (extracted.isNotEmpty) return extracted;
      }

      if (node['articleBody'] is String) {
        final extracted = extractCaption(node['articleBody'] as String);
        if (extracted.isNotEmpty) return extracted;
      }

      if (parentKey == 'edge_media_to_caption' || parentKey == 'node') {
        if (node['text'] is String) {
          final extracted = extractCaption(node['text'] as String);
          if (extracted.isNotEmpty) return extracted;
        }
      }

      if (node['description'] is String) {
        final extracted = extractCaption(node['description'] as String);
        if (extracted.isNotEmpty) return extracted;
      }

      for (final entry in node.entries) {
        final nested = _findCaptionInJson(
          entry.value,
          depth: depth + 1,
          parentKey: entry.key.toString(),
        );
        if (nested != null) return nested;
      }
    } else if (node is List) {
      for (final item in node) {
        final nested = _findCaptionInJson(
          item,
          depth: depth + 1,
          parentKey: parentKey,
        );
        if (nested != null) return nested;
      }
    }
    return null;
  }

  static String _captionFromInstagramKeys(String source) {
    final patterns = [
      RegExp(
        r'"edge_media_to_caption"\s*:\s*\{\s*"edges"\s*:\s*\[\s*\{\s*"node"\s*:\s*\{\s*"text"\s*:\s*"((?:\\.|[^"\\])*)"',
      ),
      RegExp(r'"caption"\s*:\s*\{\s*"text"\s*:\s*"((?:\\.|[^"\\])*)"'),
      RegExp(r'"articleBody"\s*:\s*"((?:\\.|[^"\\])*)"'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(source);
      if (match == null) continue;
      final text = _unescapeJsonString(match.group(1)!).trim();
      final extracted = extractCaption(text);
      if (extracted.isNotEmpty) return extracted;
    }
    return '';
  }

  static String _unescapeJsonString(String input) {
    return input
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\"', '"')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\\', r'\');
  }

  static String _unescapeHtml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&#064;', '@')
        .replaceAll('&#64;', '@')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#10;', '\n')
        .replaceAll('&nbsp;', ' ');
  }
}
