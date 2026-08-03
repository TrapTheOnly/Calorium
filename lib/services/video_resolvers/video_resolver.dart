import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The platform a shared recipe link came from.
enum VideoPlatform { youtube, instagram, unknown }

/// The result of resolving a shared link: whatever metadata and media we were
/// able to extract. Every field beyond [platform] and [sourceUrl] is best-effort
/// and may be null when a platform blocks extraction.
class ResolvedVideo {
  final VideoPlatform platform;
  final String sourceUrl;
  final String? title;

  /// Caption / description text used as the primary input for AI parsing.
  final String caption;

  /// Pinned or top comment, when available (often carries the full recipe).
  final String? topComment;

  /// Local path to the downloaded ~480p video, or null if download failed.
  final String? videoLocalPath;

  /// Local path to a downloaded thumbnail image, or null.
  final String? thumbnailPath;

  const ResolvedVideo({
    required this.platform,
    required this.sourceUrl,
    this.title,
    this.caption = '',
    this.topComment,
    this.videoLocalPath,
    this.thumbnailPath,
  });

  /// The combined text block handed to the AI for recipe extraction.
  String get combinedText {
    final buffer = StringBuffer();
    if (title != null && title!.trim().isNotEmpty) {
      buffer.writeln('TITLE: ${title!.trim()}');
    }
    if (caption.trim().isNotEmpty) {
      buffer.writeln('CAPTION/DESCRIPTION:\n${caption.trim()}');
    }
    if (topComment != null && topComment!.trim().isNotEmpty) {
      buffer.writeln('\nPINNED/TOP COMMENT:\n${topComment!.trim()}');
    }
    return buffer.toString().trim();
  }

  bool get hasUsableText => combinedText.trim().length > 15;
}

/// Contract implemented by every platform-specific resolver.
abstract class VideoResolver {
  bool canHandle(String url);

  Future<ResolvedVideo> resolve(
    String url, {
    void Function(String status)? onProgress,
  });
}

/// Shared on-device storage for imported recipe media (videos + thumbnails).
class RecipeMediaStorage {
  RecipeMediaStorage._();

  static const String _folder = 'recipe_media';

  static Future<Directory> dir() async {
    final base = await getApplicationDocumentsDirectory();
    final target = Directory(p.join(base.path, _folder));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    return target;
  }

  /// Downloads [url] to a file named [filename] inside the media folder and
  /// returns its absolute path. Returns null on any failure.
  ///
  /// The response is streamed and written to disk incrementally, and aborted
  /// once [maxBytes] is exceeded, so a large remote file can never be buffered
  /// whole in memory (which previously risked OOM-killing the app on big reels).
  static Future<String?> downloadToFile(
    String url,
    String filename, {
    Map<String, String>? headers,
    int maxBytes = 8 * 1024 * 1024,
  }) async {
    final client = http.Client();
    File? file;
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(url));
      if (headers != null) request.headers.addAll(headers);
      final response = await client.send(request);
      if (response.statusCode != 200) return null;

      // Reject up front when the server advertises a size over the cap.
      final declared = response.contentLength;
      if (declared != null && declared > maxBytes) return null;

      final folder = await dir();
      file = File(p.join(folder.path, filename));
      sink = file.openWrite();

      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > maxBytes) {
          await sink.close();
          await file.delete().catchError((_) => file!);
          return null;
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (received == 0) {
        await file.delete().catchError((_) => file!);
        return null;
      }
      return file.path;
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
      return null;
    } finally {
      client.close();
    }
  }

  /// Deletes a previously stored media file, ignoring errors.
  static Future<void> deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// A filesystem-safe token derived from an arbitrary id/url.
  static String safeName(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final trimmed =
        cleaned.length > 40 ? cleaned.substring(cleaned.length - 40) : cleaned;
    return '${DateTime.now().millisecondsSinceEpoch}_$trimmed';
  }
}
