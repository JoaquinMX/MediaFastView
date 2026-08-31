import 'dart:convert';

import '../../../media_library/domain/entities/media_entity.dart';
import '../../domain/entities/duplicate_candidate.dart';
import '../../domain/entities/duplicate_sensitivity.dart';
import '../../domain/entities/image_lookup_match.dart';
import '../../domain/entities/image_lookup_query.dart';
import '../../domain/entities/image_lookup_result.dart';
import '../../domain/entities/image_lookup_session.dart';
import '../../domain/entities/image_lookup_source.dart';

/// Encodes lookup snapshots without persisting copies of the original images.
class ImageLookupSessionSerializer {
  const ImageLookupSessionSerializer();

  String encode(ImageLookupSession session) => jsonEncode(_session(session));

  ImageLookupSession decode(String value) {
    final json = Map<String, dynamic>.from(
      jsonDecode(value) as Map<dynamic, dynamic>,
    );
    return ImageLookupSession(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sensitivity: DuplicateSensitivity.values.firstWhere(
        (value) => value.name == json['sensitivity'],
        orElse: () => DuplicateSensitivity.balanced,
      ),
      results: (json['results'] as List<dynamic>)
          .map(
            (value) => _result(
              Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
            ),
          )
          .toList(growable: false),
      hasPartialCoverage: json['hasPartialCoverage'] as bool? ?? false,
      searchedLibraryImages: json['searchedLibraryImages'] as int? ?? 0,
    );
  }

  Map<String, dynamic> _session(ImageLookupSession session) =>
      <String, dynamic>{
        'id': session.id,
        'profileId': session.profileId,
        'createdAt': session.createdAt.toIso8601String(),
        'sensitivity': session.sensitivity.name,
        'hasPartialCoverage': session.hasPartialCoverage,
        'searchedLibraryImages': session.searchedLibraryImages,
        'results': session.results.map(_resultJson).toList(growable: false),
      };

  Map<String, dynamic> _resultJson(ImageLookupResult result) =>
      <String, dynamic>{
        'source': _sourceJson(result.source),
        if (result.query != null) 'query': _queryJson(result.query!),
        if (result.errorMessage != null) 'errorMessage': result.errorMessage,
        'matches': result.matches.map(_matchJson).toList(growable: false),
      };

  ImageLookupResult _result(Map<String, dynamic> json) {
    final source = _source(
      Map<String, dynamic>.from(json['source'] as Map<dynamic, dynamic>),
    );
    final queryJson = json['query'];
    return ImageLookupResult(
      source: source,
      query: queryJson == null
          ? null
          : _query(
              Map<String, dynamic>.from(queryJson as Map<dynamic, dynamic>),
              source,
            ),
      errorMessage: json['errorMessage'] as String?,
      matches: (json['matches'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (value) => _match(
              Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> _sourceJson(ImageLookupSource source) =>
      <String, dynamic>{
        'path': source.path,
        'name': source.name,
        'size': source.size,
        'lastModified': source.lastModified.toIso8601String(),
        'mediaType': source.mediaType.name,
        if (source.bookmarkData != null) 'bookmarkData': source.bookmarkData,
      };

  ImageLookupSource _source(Map<String, dynamic> json) => ImageLookupSource(
    path: json['path'] as String,
    name: json['name'] as String,
    size: json['size'] as int,
    lastModified: DateTime.parse(json['lastModified'] as String),
    mediaType: MediaType.values.firstWhere(
      (value) => value.name == json['mediaType'],
      orElse: () => MediaType.image,
    ),
    bookmarkData: json['bookmarkData'] as String?,
  );

  Map<String, dynamic> _queryJson(ImageLookupQuery query) => <String, dynamic>{
    'hash': query.hash,
    'width': query.width,
    'height': query.height,
  };

  ImageLookupQuery _query(
    Map<String, dynamic> json,
    ImageLookupSource source,
  ) => ImageLookupQuery(
    source: source,
    hash: json['hash'] as int,
    width: json['width'] as int,
    height: json['height'] as int,
  );

  Map<String, dynamic> _matchJson(ImageLookupMatch match) => <String, dynamic>{
    'distance': match.distance,
    'hash': match.candidate.hash,
    'width': match.candidate.width,
    'height': match.candidate.height,
    'media': _mediaJson(match.candidate.media),
  };

  ImageLookupMatch _match(Map<String, dynamic> json) => ImageLookupMatch(
    distance: json['distance'] as int,
    candidate: DuplicateCandidate(
      media: _media(
        Map<String, dynamic>.from(json['media'] as Map<dynamic, dynamic>),
      ),
      hash: json['hash'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
    ),
  );

  Map<String, dynamic> _mediaJson(MediaEntity media) => <String, dynamic>{
    'id': media.id,
    'path': media.path,
    'name': media.name,
    'type': media.type.name,
    'size': media.size,
    'lastModified': media.lastModified.toIso8601String(),
    'tagIds': media.tagIds,
    'directoryId': media.directoryId,
    if (media.bookmarkData != null) 'bookmarkData': media.bookmarkData,
  };

  MediaEntity _media(Map<String, dynamic> json) => MediaEntity(
    id: json['id'] as String,
    path: json['path'] as String,
    name: json['name'] as String,
    type: MediaType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => MediaType.image,
    ),
    size: json['size'] as int,
    lastModified: DateTime.parse(json['lastModified'] as String),
    tagIds: (json['tagIds'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false),
    directoryId: json['directoryId'] as String,
    bookmarkData: json['bookmarkData'] as String?,
  );
}
