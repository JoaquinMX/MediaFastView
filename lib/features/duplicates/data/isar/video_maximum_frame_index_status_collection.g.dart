// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_maximum_frame_index_status_collection.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetVideoMaximumFrameIndexStatusCollectionCollection on Isar {
  IsarCollection<VideoMaximumFrameIndexStatusCollection>
      get videoMaximumFrameIndexStatusCollections => this.collection();
}

const VideoMaximumFrameIndexStatusCollectionSchema = CollectionSchema(
  name: r'VideoMaximumFrameIndexStatusCollection',
  id: 346248606461763499,
  properties: {
    r'chunkCount': PropertySchema(
      id: 0,
      name: r'chunkCount',
      type: IsarType.long,
    ),
    r'computedAt': PropertySchema(
      id: 1,
      name: r'computedAt',
      type: IsarType.dateTime,
    ),
    r'descriptorVersion': PropertySchema(
      id: 2,
      name: r'descriptorVersion',
      type: IsarType.long,
    ),
    r'fingerprint': PropertySchema(
      id: 3,
      name: r'fingerprint',
      type: IsarType.string,
    ),
    r'frameCount': PropertySchema(
      id: 4,
      name: r'frameCount',
      type: IsarType.long,
    ),
    r'mediaId': PropertySchema(
      id: 5,
      name: r'mediaId',
      type: IsarType.string,
    ),
    r'sourceLastModified': PropertySchema(
      id: 6,
      name: r'sourceLastModified',
      type: IsarType.dateTime,
    ),
    r'sourceSize': PropertySchema(
      id: 7,
      name: r'sourceSize',
      type: IsarType.long,
    ),
    r'state': PropertySchema(
      id: 8,
      name: r'state',
      type: IsarType.string,
    ),
    r'visionRevision': PropertySchema(
      id: 9,
      name: r'visionRevision',
      type: IsarType.long,
    )
  },
  estimateSize: _videoMaximumFrameIndexStatusCollectionEstimateSize,
  serialize: _videoMaximumFrameIndexStatusCollectionSerialize,
  deserialize: _videoMaximumFrameIndexStatusCollectionDeserialize,
  deserializeProp: _videoMaximumFrameIndexStatusCollectionDeserializeProp,
  idName: r'id',
  indexes: {
    r'mediaId': IndexSchema(
      id: -8001372983137409759,
      name: r'mediaId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'mediaId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _videoMaximumFrameIndexStatusCollectionGetId,
  getLinks: _videoMaximumFrameIndexStatusCollectionGetLinks,
  attach: _videoMaximumFrameIndexStatusCollectionAttach,
  version: '3.1.0+1',
);

int _videoMaximumFrameIndexStatusCollectionEstimateSize(
  VideoMaximumFrameIndexStatusCollection object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.fingerprint.length * 3;
  bytesCount += 3 + object.mediaId.length * 3;
  bytesCount += 3 + object.state.length * 3;
  return bytesCount;
}

void _videoMaximumFrameIndexStatusCollectionSerialize(
  VideoMaximumFrameIndexStatusCollection object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.chunkCount);
  writer.writeDateTime(offsets[1], object.computedAt);
  writer.writeLong(offsets[2], object.descriptorVersion);
  writer.writeString(offsets[3], object.fingerprint);
  writer.writeLong(offsets[4], object.frameCount);
  writer.writeString(offsets[5], object.mediaId);
  writer.writeDateTime(offsets[6], object.sourceLastModified);
  writer.writeLong(offsets[7], object.sourceSize);
  writer.writeString(offsets[8], object.state);
  writer.writeLong(offsets[9], object.visionRevision);
}

VideoMaximumFrameIndexStatusCollection
    _videoMaximumFrameIndexStatusCollectionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = VideoMaximumFrameIndexStatusCollection(
    chunkCount: reader.readLong(offsets[0]),
    computedAt: reader.readDateTime(offsets[1]),
    descriptorVersion: reader.readLong(offsets[2]),
    fingerprint: reader.readString(offsets[3]),
    frameCount: reader.readLong(offsets[4]),
    mediaId: reader.readString(offsets[5]),
    sourceLastModified: reader.readDateTime(offsets[6]),
    sourceSize: reader.readLong(offsets[7]),
    state: reader.readString(offsets[8]),
    visionRevision: reader.readLong(offsets[9]),
  );
  object.id = id;
  return object;
}

P _videoMaximumFrameIndexStatusCollectionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _videoMaximumFrameIndexStatusCollectionGetId(
    VideoMaximumFrameIndexStatusCollection object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _videoMaximumFrameIndexStatusCollectionGetLinks(
    VideoMaximumFrameIndexStatusCollection object) {
  return [];
}

void _videoMaximumFrameIndexStatusCollectionAttach(IsarCollection<dynamic> col,
    Id id, VideoMaximumFrameIndexStatusCollection object) {
  object.id = id;
}

extension VideoMaximumFrameIndexStatusCollectionByIndex
    on IsarCollection<VideoMaximumFrameIndexStatusCollection> {
  Future<VideoMaximumFrameIndexStatusCollection?> getByMediaId(String mediaId) {
    return getByIndex(r'mediaId', [mediaId]);
  }

  VideoMaximumFrameIndexStatusCollection? getByMediaIdSync(String mediaId) {
    return getByIndexSync(r'mediaId', [mediaId]);
  }

  Future<bool> deleteByMediaId(String mediaId) {
    return deleteByIndex(r'mediaId', [mediaId]);
  }

  bool deleteByMediaIdSync(String mediaId) {
    return deleteByIndexSync(r'mediaId', [mediaId]);
  }

  Future<List<VideoMaximumFrameIndexStatusCollection?>> getAllByMediaId(
      List<String> mediaIdValues) {
    final values = mediaIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'mediaId', values);
  }

  List<VideoMaximumFrameIndexStatusCollection?> getAllByMediaIdSync(
      List<String> mediaIdValues) {
    final values = mediaIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'mediaId', values);
  }

  Future<int> deleteAllByMediaId(List<String> mediaIdValues) {
    final values = mediaIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'mediaId', values);
  }

  int deleteAllByMediaIdSync(List<String> mediaIdValues) {
    final values = mediaIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'mediaId', values);
  }

  Future<Id> putByMediaId(VideoMaximumFrameIndexStatusCollection object) {
    return putByIndex(r'mediaId', object);
  }

  Id putByMediaIdSync(VideoMaximumFrameIndexStatusCollection object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'mediaId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByMediaId(
      List<VideoMaximumFrameIndexStatusCollection> objects) {
    return putAllByIndex(r'mediaId', objects);
  }

  List<Id> putAllByMediaIdSync(
      List<VideoMaximumFrameIndexStatusCollection> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'mediaId', objects, saveLinks: saveLinks);
  }
}

extension VideoMaximumFrameIndexStatusCollectionQueryWhereSort on QueryBuilder<
    VideoMaximumFrameIndexStatusCollection,
    VideoMaximumFrameIndexStatusCollection,
    QWhere> {
  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension VideoMaximumFrameIndexStatusCollectionQueryWhere on QueryBuilder<
    VideoMaximumFrameIndexStatusCollection,
    VideoMaximumFrameIndexStatusCollection,
    QWhereClause> {
  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterWhereClause> mediaIdEqualTo(String mediaId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'mediaId',
        value: [mediaId],
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterWhereClause> mediaIdNotEqualTo(String mediaId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'mediaId',
              lower: [],
              upper: [mediaId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'mediaId',
              lower: [mediaId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'mediaId',
              lower: [mediaId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'mediaId',
              lower: [],
              upper: [mediaId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension VideoMaximumFrameIndexStatusCollectionQueryFilter on QueryBuilder<
    VideoMaximumFrameIndexStatusCollection,
    VideoMaximumFrameIndexStatusCollection,
    QFilterCondition> {
  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> chunkCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chunkCount',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> chunkCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chunkCount',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> chunkCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chunkCount',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> chunkCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chunkCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> computedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'computedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> computedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'computedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> computedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'computedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> computedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'computedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> descriptorVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'descriptorVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> descriptorVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'descriptorVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> descriptorVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'descriptorVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> descriptorVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'descriptorVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> fingerprintEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fingerprint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> fingerprintGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fingerprint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> fingerprintLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fingerprint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> fingerprintBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fingerprint',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> fingerprintStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'fingerprint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> fingerprintEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'fingerprint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
          VideoMaximumFrameIndexStatusCollection, QAfterFilterCondition>
      fingerprintContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fingerprint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
          VideoMaximumFrameIndexStatusCollection, QAfterFilterCondition>
      fingerprintMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fingerprint',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> fingerprintIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fingerprint',
        value: '',
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> fingerprintIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fingerprint',
        value: '',
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> frameCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'frameCount',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> frameCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'frameCount',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> frameCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'frameCount',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> frameCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'frameCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> mediaIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> mediaIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mediaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> mediaIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mediaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> mediaIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mediaId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> mediaIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'mediaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> mediaIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'mediaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
          VideoMaximumFrameIndexStatusCollection, QAfterFilterCondition>
      mediaIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mediaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
          VideoMaximumFrameIndexStatusCollection, QAfterFilterCondition>
      mediaIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mediaId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> mediaIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaId',
        value: '',
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> mediaIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mediaId',
        value: '',
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> sourceLastModifiedEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceLastModified',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> sourceLastModifiedGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceLastModified',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> sourceLastModifiedLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceLastModified',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> sourceLastModifiedBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceLastModified',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> sourceSizeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceSize',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> sourceSizeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceSize',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> sourceSizeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceSize',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> sourceSizeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceSize',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> stateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'state',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> stateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'state',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> stateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'state',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> stateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'state',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> stateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'state',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> stateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'state',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
          VideoMaximumFrameIndexStatusCollection, QAfterFilterCondition>
      stateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'state',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
          VideoMaximumFrameIndexStatusCollection, QAfterFilterCondition>
      stateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'state',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> stateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'state',
        value: '',
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> stateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'state',
        value: '',
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> visionRevisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'visionRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> visionRevisionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'visionRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> visionRevisionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'visionRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterFilterCondition> visionRevisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'visionRevision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension VideoMaximumFrameIndexStatusCollectionQueryObject on QueryBuilder<
    VideoMaximumFrameIndexStatusCollection,
    VideoMaximumFrameIndexStatusCollection,
    QFilterCondition> {}

extension VideoMaximumFrameIndexStatusCollectionQueryLinks on QueryBuilder<
    VideoMaximumFrameIndexStatusCollection,
    VideoMaximumFrameIndexStatusCollection,
    QFilterCondition> {}

extension VideoMaximumFrameIndexStatusCollectionQuerySortBy on QueryBuilder<
    VideoMaximumFrameIndexStatusCollection,
    VideoMaximumFrameIndexStatusCollection,
    QSortBy> {
  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> sortByChunkCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkCount', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> sortByChunkCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkCount', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> sortByComputedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> sortByComputedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.desc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> sortByDescriptorVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descriptorVersion', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> sortByDescriptorVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descriptorVersion', Sort.desc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> sortByFingerprint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fingerprint', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> sortByFingerprintDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fingerprint', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> sortByFrameCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'frameCount', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> sortByFrameCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'frameCount', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> sortByMediaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaId', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> sortByMediaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaId', Sort.desc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> sortBySourceLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLastModified', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> sortBySourceLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLastModified', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> sortBySourceSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSize', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> sortBySourceSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSize', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> sortByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> sortByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> sortByVisionRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visionRevision', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> sortByVisionRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visionRevision', Sort.desc);
    });
  }
}

extension VideoMaximumFrameIndexStatusCollectionQuerySortThenBy on QueryBuilder<
    VideoMaximumFrameIndexStatusCollection,
    VideoMaximumFrameIndexStatusCollection,
    QSortThenBy> {
  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> thenByChunkCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkCount', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> thenByChunkCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkCount', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> thenByComputedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> thenByComputedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.desc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> thenByDescriptorVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descriptorVersion', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> thenByDescriptorVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descriptorVersion', Sort.desc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> thenByFingerprint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fingerprint', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> thenByFingerprintDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fingerprint', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> thenByFrameCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'frameCount', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> thenByFrameCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'frameCount', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> thenByMediaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaId', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> thenByMediaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaId', Sort.desc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> thenBySourceLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLastModified', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> thenBySourceLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceLastModified', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> thenBySourceSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSize', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> thenBySourceSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceSize', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> thenByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection, QAfterSortBy> thenByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> thenByVisionRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visionRevision', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QAfterSortBy> thenByVisionRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visionRevision', Sort.desc);
    });
  }
}

extension VideoMaximumFrameIndexStatusCollectionQueryWhereDistinct
    on QueryBuilder<VideoMaximumFrameIndexStatusCollection,
        VideoMaximumFrameIndexStatusCollection, QDistinct> {
  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QDistinct> distinctByChunkCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chunkCount');
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QDistinct> distinctByComputedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'computedAt');
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QDistinct> distinctByDescriptorVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'descriptorVersion');
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QDistinct> distinctByFingerprint({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fingerprint', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QDistinct> distinctByFrameCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'frameCount');
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QDistinct> distinctByMediaId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QDistinct> distinctBySourceLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceLastModified');
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QDistinct> distinctBySourceSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceSize');
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QDistinct> distinctByState({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexStatusCollection,
      VideoMaximumFrameIndexStatusCollection,
      QDistinct> distinctByVisionRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'visionRevision');
    });
  }
}

extension VideoMaximumFrameIndexStatusCollectionQueryProperty on QueryBuilder<
    VideoMaximumFrameIndexStatusCollection,
    VideoMaximumFrameIndexStatusCollection,
    QQueryProperty> {
  QueryBuilder<VideoMaximumFrameIndexStatusCollection, int, QQueryOperations>
      idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection, int, QQueryOperations>
      chunkCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chunkCount');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection, DateTime,
      QQueryOperations> computedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'computedAt');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection, int, QQueryOperations>
      descriptorVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'descriptorVersion');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection, String, QQueryOperations>
      fingerprintProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fingerprint');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection, int, QQueryOperations>
      frameCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'frameCount');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection, String, QQueryOperations>
      mediaIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaId');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection, DateTime,
      QQueryOperations> sourceLastModifiedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceLastModified');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection, int, QQueryOperations>
      sourceSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceSize');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection, String, QQueryOperations>
      stateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexStatusCollection, int, QQueryOperations>
      visionRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'visionRevision');
    });
  }
}
