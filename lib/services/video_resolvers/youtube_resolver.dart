import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'video_resolver.dart';

/// Resolves YouTube (incl. Shorts) links: title + description + best-effort top
/// comment, plus a downloaded muxed stream closest to 480p.
///
/// Note: YouTube muxed (audio+video) streams typically cap at ~360p; higher
/// resolutions require separate audio/video muxing (ffmpeg) which is out of
/// scope, so we download the highest available muxed stream up to 480p.
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

      // Download the muxed stream closest to (but not above) 480p.
      String? videoPath;
      try {
        onProgress?.call('Downloading video…');
        final manifest = await yt.videos.streamsClient.getManifest(video.id);
        final muxed = manifest.muxed.toList();
        if (muxed.isNotEmpty) {
          MuxedStreamInfo? chosen;
          for (final s in muxed) {
            if (s.videoResolution.height <= 480) {
              if (chosen == null ||
                  s.videoResolution.height > chosen.videoResolution.height) {
                chosen = s;
              }
            }
          }
          // If every muxed stream is above 480p, fall back to the smallest.
          if (chosen == null) {
            muxed.sort(
              (a, b) =>
                  a.videoResolution.height.compareTo(b.videoResolution.height),
            );
            chosen = muxed.first;
          }
          videoPath = await _downloadStream(yt, chosen, id);
        }
      } catch (_) {}

      // Thumbnail.
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
        videoLocalPath: videoPath,
        thumbnailPath: thumbPath,
      );
    } finally {
      yt.close();
    }
  }

  Future<String> _downloadStream(
    YoutubeExplode yt,
    StreamInfo info,
    String id,
  ) async {
    final folder = await RecipeMediaStorage.dir();
    final file = File(
      p.join(folder.path, '${RecipeMediaStorage.safeName(id)}.mp4'),
    );
    final sink = file.openWrite();
    try {
      await yt.videos.streamsClient.get(info).pipe(sink);
    } finally {
      await sink.flush();
      await sink.close();
    }
    return file.path;
  }
}
