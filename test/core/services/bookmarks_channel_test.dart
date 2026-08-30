import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/bookmarks_channel.dart';

void main() {
  test('decodes every valid directory grant in native order', () {
    final grants = BookmarksChannel.decodeDirectoryPayloads(<dynamic>[
      <String, dynamic>{
        'url': Uri.file('/photos/first').toString(),
        'bookmarkData': 'first-bookmark',
      },
      <String, dynamic>{
        'url': Uri.file('/photos/second').toString(),
        'bookmarkData': 'second-bookmark',
      },
    ]);

    expect(grants.map((grant) => grant.path), <String>[
      '/photos/first',
      '/photos/second',
    ]);
    expect(grants.map((grant) => grant.bookmarkData), <String>[
      'first-bookmark',
      'second-bookmark',
    ]);
  });

  test('ignores malformed native directory payloads', () {
    final grants = BookmarksChannel.decodeDirectoryPayloads(<dynamic>[
      <String, dynamic>{'url': 'https://example.com', 'bookmarkData': 'data'},
      <String, dynamic>{'url': Uri.file('/missing-bookmark').toString()},
      'not-a-map',
    ]);

    expect(grants, isEmpty);
  });
}
