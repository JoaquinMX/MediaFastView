// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_frame_hash_collection.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetVideoFrameHashCollectionCollection on Isar {
  IsarCollection<VideoFrameHashCollection> get videoFrameHashCollections =>
      this.collection();
}

const VideoFrameHashCollectionSchema = CollectionSchema(
  name: r'VideoFrameHashCollection',
  id: -6557573844759347013,
  properties: {
    r'computedAt': PropertySchema(
      id: 0,
      name: r'computedAt',
      type: IsarType.dateTime,
    ),
    r'fingerprint': PropertySchema(
      id: 1,
      name: r'fingerprint',
      type: IsarType.string,
    ),
    r'hash': PropertySchema(
      id: 2,
      name: r'hash',
      type: IsarType.long,
    ),
    r'height': PropertySchema(
      id: 3,
      name: r'height',
      type: IsarType.long,
    ),
    r'mediaId': PropertySchema(
      id: 4,
      name: r'mediaId',
      type: IsarType.string,
    ),
    r'positionPercent': PropertySchema(
      id: 5,
      name: r'positionPercent',
      type: IsarType.long,
    ),
    r'timestampMilliseconds': PropertySchema(
      id: 6,
      name: r'timestampMilliseconds',
      type: IsarType.long,
    ),
    r'width': PropertySchema(
      id: 7,
      name: r'width',
      type: IsarType.long,
    )
  },
  estimateSize: _videoFrameHashCollectionEstimateSize,
  serialize: _videoFrameHashCollectionSerialize,
  deserialize: _videoFrameHashCollectionDeserialize,
  deserializeProp: _videoFrameHashCollectionDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _videoFrameHashCollectionGetId,
  getLinks: _videoFrameHashCollectionGetLinks,
  attach: _videoFrameHashCollectionAttach,
  version: '3.1.0+1',
);

int _videoFrameHashCollectionEstimateSize(
  VideoFrameHashCollection object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.fingerprint.length * 3;
  bytesCount += 3 + object.mediaId.length * 3;
  return bytesCount;
}

void _videoFrameHashCollectionSerialize(
  VideoFrameHashCollection object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.computedAt);
  writer.writeString(offsets[1], object.fingerprint);
  writer.writeLong(offsets[2], object.hash);
  writer.writeLong(offsets[3], object.height);
  writer.writeString(offsets[4], object.mediaId);
  writer.writeLong(offsets[5], object.positionPercent);
  writer.writeLong(offsets[6], object.timestampMilliseconds);
  writer.writeLong(offsets[7], object.width);
}

VideoFrameHashCollection _videoFrameHashCollectionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = VideoFrameHashCollection(
    computedAt: reader.readDateTime(offsets[0]),
    fingerprint: reader.readString(offsets[1]),
    hash: reader.readLong(offsets[2]),
    height: reader.readLong(offsets[3]),
    mediaId: reader.readString(offsets[4]),
    positionPercent: reader.readLong(offsets[5]),
    timestampMilliseconds: reader.readLong(offsets[6]),
    width: reader.readLong(offsets[7]),
  );
  object.id = id;
  return object;
}

P _videoFrameHashCollectionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _videoFrameHashCollectionGetId(VideoFrameHashCollection object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _videoFrameHashCollectionGetLinks(
    VideoFrameHashCollection object) {
  return [];
}

void _videoFrameHashCollectionAttach(
    IsarCollection<dynamic> col, Id id, VideoFrameHashCollection object) {
  object.id = id;
}

extension VideoFrameHashCollectionQueryWhereSort on QueryBuilder<
    VideoFrameHashCollection, VideoFrameHashCollection, QWhere> {
  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension VideoFrameHashCollectionQueryWhere on QueryBuilder<
    VideoFrameHashCollection, VideoFrameHashCollection, QWhereClause> {
  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterWhereClause> idBetween(
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
}

extension VideoFrameHashCollectionQueryFilter on QueryBuilder<
    VideoFrameHashCollection, VideoFrameHashCollection, QFilterCondition> {
  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> computedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'computedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
          QAfterFilterCondition>
      fingerprintContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fingerprint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
          QAfterFilterCondition>
      fingerprintMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fingerprint',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> fingerprintIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fingerprint',
        value: '',
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> fingerprintIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fingerprint',
        value: '',
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> hashEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hash',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> hashGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'hash',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> hashLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'hash',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> hashBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'hash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> heightEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'height',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> heightGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'height',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> heightLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'height',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> heightBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'height',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> idLessThan(
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> idBetween(
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
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

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
          QAfterFilterCondition>
      mediaIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mediaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
          QAfterFilterCondition>
      mediaIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mediaId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> mediaIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaId',
        value: '',
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> mediaIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mediaId',
        value: '',
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> positionPercentEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'positionPercent',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> positionPercentGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'positionPercent',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> positionPercentLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'positionPercent',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> positionPercentBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'positionPercent',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> timestampMillisecondsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestampMilliseconds',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> timestampMillisecondsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestampMilliseconds',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> timestampMillisecondsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestampMilliseconds',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> timestampMillisecondsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestampMilliseconds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> widthEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'width',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> widthGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'width',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> widthLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'width',
        value: value,
      ));
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection,
      QAfterFilterCondition> widthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'width',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension VideoFrameHashCollectionQueryObject on QueryBuilder<
    VideoFrameHashCollection, VideoFrameHashCollection, QFilterCondition> {}

extension VideoFrameHashCollectionQueryLinks on QueryBuilder<
    VideoFrameHashCollection, VideoFrameHashCollection, QFilterCondition> {}

extension VideoFrameHashCollectionQuerySortBy on QueryBuilder<
    VideoFrameHashCollection, VideoFrameHashCollection, QSortBy> {
  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByComputedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByComputedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByFingerprint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fingerprint', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByFingerprintDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fingerprint', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hash', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hash', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByHeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByMediaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaId', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByMediaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaId', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByPositionPercent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'positionPercent', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByPositionPercentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'positionPercent', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByTimestampMilliseconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampMilliseconds', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByTimestampMillisecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampMilliseconds', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'width', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      sortByWidthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'width', Sort.desc);
    });
  }
}

extension VideoFrameHashCollectionQuerySortThenBy on QueryBuilder<
    VideoFrameHashCollection, VideoFrameHashCollection, QSortThenBy> {
  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByComputedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByComputedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByFingerprint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fingerprint', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByFingerprintDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fingerprint', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hash', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hash', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByHeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByMediaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaId', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByMediaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaId', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByPositionPercent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'positionPercent', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByPositionPercentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'positionPercent', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByTimestampMilliseconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampMilliseconds', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByTimestampMillisecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampMilliseconds', Sort.desc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'width', Sort.asc);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QAfterSortBy>
      thenByWidthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'width', Sort.desc);
    });
  }
}

extension VideoFrameHashCollectionQueryWhereDistinct on QueryBuilder<
    VideoFrameHashCollection, VideoFrameHashCollection, QDistinct> {
  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QDistinct>
      distinctByComputedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'computedAt');
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QDistinct>
      distinctByFingerprint({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fingerprint', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QDistinct>
      distinctByHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hash');
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QDistinct>
      distinctByHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'height');
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QDistinct>
      distinctByMediaId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QDistinct>
      distinctByPositionPercent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'positionPercent');
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QDistinct>
      distinctByTimestampMilliseconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestampMilliseconds');
    });
  }

  QueryBuilder<VideoFrameHashCollection, VideoFrameHashCollection, QDistinct>
      distinctByWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'width');
    });
  }
}

extension VideoFrameHashCollectionQueryProperty on QueryBuilder<
    VideoFrameHashCollection, VideoFrameHashCollection, QQueryProperty> {
  QueryBuilder<VideoFrameHashCollection, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<VideoFrameHashCollection, DateTime, QQueryOperations>
      computedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'computedAt');
    });
  }

  QueryBuilder<VideoFrameHashCollection, String, QQueryOperations>
      fingerprintProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fingerprint');
    });
  }

  QueryBuilder<VideoFrameHashCollection, int, QQueryOperations> hashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hash');
    });
  }

  QueryBuilder<VideoFrameHashCollection, int, QQueryOperations>
      heightProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'height');
    });
  }

  QueryBuilder<VideoFrameHashCollection, String, QQueryOperations>
      mediaIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaId');
    });
  }

  QueryBuilder<VideoFrameHashCollection, int, QQueryOperations>
      positionPercentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'positionPercent');
    });
  }

  QueryBuilder<VideoFrameHashCollection, int, QQueryOperations>
      timestampMillisecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestampMilliseconds');
    });
  }

  QueryBuilder<VideoFrameHashCollection, int, QQueryOperations>
      widthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'width');
    });
  }
}
