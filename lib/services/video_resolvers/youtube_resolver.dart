import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'video_resolver.dart';

/// Resolves YouTube (incl. Shorts) links: title + description + best-effort top
/// comment, plus the video thumbnail.
///
/// We intentionally do not download the video itself — it's large, slow, and
/// unnecessary for recipe import. A thumbnail plus an "open original" link is
/// far cheaper and more reliable.
class YouTubeResolver implements VideoResolver {
  @override
  bool canHandle(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  @override
  Future<ResolvedVideo> resolve(
    String url, {
    void Function(String status)? onProgress,
  }) async {
    final yt = YoutubeExplode();
    try {
      onProgress?.call('Fetching video details…');
      final video = await yt.videos.get(url);
      final id = video.id.value;

      // Best-effort pinned/top comment (the comments API is fragile).
      String? topComment;
      try {
        final comments = await yt.videos.commentsClient.getComments(video);
        if (comments != null && comments.isNotEmpty) {
          final hearted = comments.where((c) => c.isHearted).toList();
          topComment = (hearted.isNotEmpty ? hearted.first : comments.first).text;
        }
      } catch (_) {}

      // Thumbnail only (see class doc — we don't download the video).
      String? thumbPath;
      try {
        onProgress?.call('Fetching thumbnail…');
        thumbPath = await RecipeMediaStorage.downloadToFile(
          video.thumbnails.highResUrl,
          '${RecipeMediaStorage.safeName(id)}_thumb.jpg',
        );
      } catch (_) {}

      return ResolvedVideo(
        platform: VideoPlatform.youtube,
        sourceUrl: url,
        title: video.title,
        caption: video.description,
        topComment: topComment,
        thumbnailPath: thumbPath,
      );
    } finally {
      yt.close();
    }
  }
}
