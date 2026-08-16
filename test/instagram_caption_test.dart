import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_tracker/services/video_resolvers/instagram_resolver.dart';

void main() {
  group('InstagramResolver.extractCaption', () {
    test('quoted og:description yields the real caption', () {
      const og =
          '123 likes, 45 comments - chef_home on Instagram: "2 cups flour\n1 egg\nBake 20 min"';
      expect(
        InstagramResolver.extractCaption(og),
        '2 cups flour\n1 egg\nBake 20 min',
      );
    });

    test('likes-only shell is empty', () {
      expect(InstagramResolver.extractCaption('123 likes, 45 comments'), '');
      expect(
        InstagramResolver.extractCaption(
          '1,234 likes, 56 comments - chef on Instagram',
        ),
        '',
      );
      expect(
        InstagramResolver.extractCaption(
          '123 likes, 45 comments - chef on Instagram:',
        ),
        '',
      );
      expect(
        InstagramResolver.extractCaption(
          '92K likes, 1,204 comments - chef on Instagram',
        ),
        '',
      );
    });

    test('empty quoted caption is treated as a shell', () {
      expect(
        InstagramResolver.extractCaption(
          '10 likes, 2 comments - chef on Instagram: ""',
        ),
        '',
      );
    });
  });

  group('InstagramResolver.captionFromHtml', () {
    test('unescapes quoted og:description from a meta tag', () {
      const html = '''
<html><head>
<meta property="og:description" content="123 likes, 45 comments - chef on Instagram: &quot;2 cups flour&quot;" />
</head></html>
''';
      expect(InstagramResolver.captionFromHtml(html), '2 cups flour');
    });

    test('likes-only og:description stays empty', () {
      const html = '''
<meta property="og:description" content="123 likes, 45 comments - chef on Instagram" />
''';
      expect(InstagramResolver.captionFromHtml(html), '');
    });

    test('reads caption from an Instagram JSON blob', () {
      const html = '''
<script type="application/json">
{"edge_media_to_caption":{"edges":[{"node":{"text":"1 tbsp coconut powder\\n200 ml milk"}}]}}
</script>
''';
      expect(
        InstagramResolver.captionFromHtml(html),
        '1 tbsp coconut powder\n200 ml milk',
      );
    });
  });
}
