// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_maximum_frame_index_chunk_collection.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetVideoMaximumFrameIndexChunkCollectionCollection on Isar {
  IsarCollection<VideoMaximumFrameIndexChunkCollection>
      get videoMaximumFrameIndexChunkCollections => this.collection();
}

const VideoMaximumFrameIndexChunkCollectionSchema = CollectionSchema(
  name: r'VideoMaximumFrameIndexChunkCollection',
  id: -7188222489241273623,
  properties: {
    r'chunkIndex': PropertySchema(
      id: 0,
      name: r'chunkIndex',
      type: IsarType.long,
    ),
    r'computedAt': PropertySchema(
      id: 1,
      name: r'computedAt',
      type: IsarType.dateTime,
    ),
    r'descriptorBytes': PropertySchema(
      id: 2,
      name: r'descriptorBytes',
      type: IsarType.byteList,
    ),
    r'encodedByteCount': PropertySchema(
      id: 3,
      name: r'encodedByteCount',
      type: IsarType.long,
    ),
    r'fingerprint': PropertySchema(
      id: 4,
      name: r'fingerprint',
      type: IsarType.string,
    ),
    r'mediaId': PropertySchema(
      id: 5,
      name: r'mediaId',
      type: IsarType.string,
    )
  },
  estimateSize: _videoMaximumFrameIndexChunkCollectionEstimateSize,
  serialize: _videoMaximumFrameIndexChunkCollectionSerialize,
  deserialize: _videoMaximumFrameIndexChunkCollectionDeserialize,
  deserializeProp: _videoMaximumFrameIndexChunkCollectionDeserializeProp,
  idName: r'id',
  indexes: {
    r'mediaId_chunkIndex': IndexSchema(
      id: 6424779245025429486,
      name: r'mediaId_chunkIndex',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'mediaId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'chunkIndex',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'encodedByteCount': IndexSchema(
      id: 1403837069481243133,
      name: r'encodedByteCount',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'encodedByteCount',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _videoMaximumFrameIndexChunkCollectionGetId,
  getLinks: _videoMaximumFrameIndexChunkCollectionGetLinks,
  attach: _videoMaximumFrameIndexChunkCollectionAttach,
  version: '3.1.0+1',
);

int _videoMaximumFrameIndexChunkCollectionEstimateSize(
  VideoMaximumFrameIndexChunkCollection object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.descriptorBytes.length;
  bytesCount += 3 + object.fingerprint.length * 3;
  bytesCount += 3 + object.mediaId.length * 3;
  return bytesCount;
}

void _videoMaximumFrameIndexChunkCollectionSerialize(
  VideoMaximumFrameIndexChunkCollection object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.chunkIndex);
  writer.writeDateTime(offsets[1], object.computedAt);
  writer.writeByteList(offsets[2], object.descriptorBytes);
  writer.writeLong(offsets[3], object.encodedByteCount);
  writer.writeString(offsets[4], object.fingerprint);
  writer.writeString(offsets[5], object.mediaId);
}

VideoMaximumFrameIndexChunkCollection
    _videoMaximumFrameIndexChunkCollectionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = VideoMaximumFrameIndexChunkCollection(
    chunkIndex: reader.readLong(offsets[0]),
    computedAt: reader.readDateTime(offsets[1]),
    descriptorBytes: reader.readByteList(offsets[2]) ?? [],
    encodedByteCount: reader.readLongOrNull(offsets[3]),
    fingerprint: reader.readString(offsets[4]),
    mediaId: reader.readString(offsets[5]),
  );
  object.id = id;
  return object;
}

P _videoMaximumFrameIndexChunkCollectionDeserializeProp<P>(
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
      return (reader.readByteList(offset) ?? []) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _videoMaximumFrameIndexChunkCollectionGetId(
    VideoMaximumFrameIndexChunkCollection object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _videoMaximumFrameIndexChunkCollectionGetLinks(
    VideoMaximumFrameIndexChunkCollection object) {
  return [];
}

void _videoMaximumFrameIndexChunkCollectionAttach(IsarCollection<dynamic> col,
    Id id, VideoMaximumFrameIndexChunkCollection object) {
  object.id = id;
}

extension VideoMaximumFrameIndexChunkCollectionQueryWhereSort on QueryBuilder<
    VideoMaximumFrameIndexChunkCollection,
    VideoMaximumFrameIndexChunkCollection,
    QWhere> {
  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhere> anyEncodedByteCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'encodedByteCount'),
      );
    });
  }
}

extension VideoMaximumFrameIndexChunkCollectionQueryWhere on QueryBuilder<
    VideoMaximumFrameIndexChunkCollection,
    VideoMaximumFrameIndexChunkCollection,
    QWhereClause> {
  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterWhereClause> idBetween(
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> mediaIdEqualToAnyChunkIndex(String mediaId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'mediaId_chunkIndex',
        value: [mediaId],
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> mediaIdNotEqualToAnyChunkIndex(String mediaId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'mediaId_chunkIndex',
              lower: [],
              upper: [mediaId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'mediaId_chunkIndex',
              lower: [mediaId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'mediaId_chunkIndex',
              lower: [mediaId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'mediaId_chunkIndex',
              lower: [],
              upper: [mediaId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
          VideoMaximumFrameIndexChunkCollection, QAfterWhereClause>
      mediaIdChunkIndexEqualTo(String mediaId, int chunkIndex) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'mediaId_chunkIndex',
        value: [mediaId, chunkIndex],
      ));
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
          VideoMaximumFrameIndexChunkCollection, QAfterWhereClause>
      mediaIdEqualToChunkIndexNotEqualTo(String mediaId, int chunkIndex) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'mediaId_chunkIndex',
              lower: [mediaId],
              upper: [mediaId, chunkIndex],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'mediaId_chunkIndex',
              lower: [mediaId, chunkIndex],
              includeLower: false,
              upper: [mediaId],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'mediaId_chunkIndex',
              lower: [mediaId, chunkIndex],
              includeLower: false,
              upper: [mediaId],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'mediaId_chunkIndex',
              lower: [mediaId],
              upper: [mediaId, chunkIndex],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> mediaIdEqualToChunkIndexGreaterThan(
    String mediaId,
    int chunkIndex, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'mediaId_chunkIndex',
        lower: [mediaId, chunkIndex],
        includeLower: include,
        upper: [mediaId],
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> mediaIdEqualToChunkIndexLessThan(
    String mediaId,
    int chunkIndex, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'mediaId_chunkIndex',
        lower: [mediaId],
        upper: [mediaId, chunkIndex],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> mediaIdEqualToChunkIndexBetween(
    String mediaId,
    int lowerChunkIndex,
    int upperChunkIndex, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'mediaId_chunkIndex',
        lower: [mediaId, lowerChunkIndex],
        includeLower: includeLower,
        upper: [mediaId, upperChunkIndex],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> encodedByteCountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'encodedByteCount',
        value: [null],
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> encodedByteCountIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'encodedByteCount',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> encodedByteCountEqualTo(int? encodedByteCount) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'encodedByteCount',
        value: [encodedByteCount],
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> encodedByteCountNotEqualTo(int? encodedByteCount) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'encodedByteCount',
              lower: [],
              upper: [encodedByteCount],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'encodedByteCount',
              lower: [encodedByteCount],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'encodedByteCount',
              lower: [encodedByteCount],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'encodedByteCount',
              lower: [],
              upper: [encodedByteCount],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> encodedByteCountGreaterThan(
    int? encodedByteCount, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'encodedByteCount',
        lower: [encodedByteCount],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> encodedByteCountLessThan(
    int? encodedByteCount, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'encodedByteCount',
        lower: [],
        upper: [encodedByteCount],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterWhereClause> encodedByteCountBetween(
    int? lowerEncodedByteCount,
    int? upperEncodedByteCount, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'encodedByteCount',
        lower: [lowerEncodedByteCount],
        includeLower: includeLower,
        upper: [upperEncodedByteCount],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension VideoMaximumFrameIndexChunkCollectionQueryFilter on QueryBuilder<
    VideoMaximumFrameIndexChunkCollection,
    VideoMaximumFrameIndexChunkCollection,
    QFilterCondition> {
  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> chunkIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chunkIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> chunkIndexGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chunkIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> chunkIndexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chunkIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> chunkIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chunkIndex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> computedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'computedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> descriptorBytesElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'descriptorBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> descriptorBytesElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'descriptorBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> descriptorBytesElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'descriptorBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> descriptorBytesElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'descriptorBytes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> descriptorBytesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'descriptorBytes',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> descriptorBytesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'descriptorBytes',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> descriptorBytesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'descriptorBytes',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> descriptorBytesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'descriptorBytes',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> descriptorBytesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'descriptorBytes',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> descriptorBytesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'descriptorBytes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> encodedByteCountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'encodedByteCount',
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> encodedByteCountIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'encodedByteCount',
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> encodedByteCountEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'encodedByteCount',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> encodedByteCountGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'encodedByteCount',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> encodedByteCountLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'encodedByteCount',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> encodedByteCountBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'encodedByteCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
          VideoMaximumFrameIndexChunkCollection, QAfterFilterCondition>
      fingerprintContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fingerprint',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
          VideoMaximumFrameIndexChunkCollection, QAfterFilterCondition>
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> fingerprintIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fingerprint',
        value: '',
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> fingerprintIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fingerprint',
        value: '',
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterFilterCondition> idBetween(
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
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

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
          VideoMaximumFrameIndexChunkCollection, QAfterFilterCondition>
      mediaIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mediaId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
          VideoMaximumFrameIndexChunkCollection, QAfterFilterCondition>
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
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> mediaIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaId',
        value: '',
      ));
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterFilterCondition> mediaIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mediaId',
        value: '',
      ));
    });
  }
}

extension VideoMaximumFrameIndexChunkCollectionQueryObject on QueryBuilder<
    VideoMaximumFrameIndexChunkCollection,
    VideoMaximumFrameIndexChunkCollection,
    QFilterCondition> {}

extension VideoMaximumFrameIndexChunkCollectionQueryLinks on QueryBuilder<
    VideoMaximumFrameIndexChunkCollection,
    VideoMaximumFrameIndexChunkCollection,
    QFilterCondition> {}

extension VideoMaximumFrameIndexChunkCollectionQuerySortBy on QueryBuilder<
    VideoMaximumFrameIndexChunkCollection,
    VideoMaximumFrameIndexChunkCollection,
    QSortBy> {
  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterSortBy> sortByChunkIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkIndex', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterSortBy> sortByChunkIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkIndex', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterSortBy> sortByComputedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterSortBy> sortByComputedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.desc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterSortBy> sortByEncodedByteCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encodedByteCount', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterSortBy> sortByEncodedByteCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encodedByteCount', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterSortBy> sortByFingerprint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fingerprint', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterSortBy> sortByFingerprintDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fingerprint', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterSortBy> sortByMediaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaId', Sort.asc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterSortBy> sortByMediaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaId', Sort.desc);
    });
  }
}

extension VideoMaximumFrameIndexChunkCollectionQuerySortThenBy on QueryBuilder<
    VideoMaximumFrameIndexChunkCollection,
    VideoMaximumFrameIndexChunkCollection,
    QSortThenBy> {
  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterSortBy> thenByChunkIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkIndex', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterSortBy> thenByChunkIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkIndex', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterSortBy> thenByComputedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterSortBy> thenByComputedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.desc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterSortBy> thenByEncodedByteCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encodedByteCount', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterSortBy> thenByEncodedByteCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encodedByteCount', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterSortBy> thenByFingerprint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fingerprint', Sort.asc);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QAfterSortBy> thenByFingerprintDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fingerprint', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterSortBy> thenByMediaId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaId', Sort.asc);
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QAfterSortBy> thenByMediaIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaId', Sort.desc);
    });
  }
}

extension VideoMaximumFrameIndexChunkCollectionQueryWhereDistinct
    on QueryBuilder<VideoMaximumFrameIndexChunkCollection,
        VideoMaximumFrameIndexChunkCollection, QDistinct> {
  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QDistinct> distinctByChunkIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chunkIndex');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection, QDistinct> distinctByComputedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'computedAt');
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QDistinct> distinctByDescriptorBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'descriptorBytes');
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QDistinct> distinctByEncodedByteCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'encodedByteCount');
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QDistinct> distinctByFingerprint({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fingerprint', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<
      VideoMaximumFrameIndexChunkCollection,
      VideoMaximumFrameIndexChunkCollection,
      QDistinct> distinctByMediaId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaId', caseSensitive: caseSensitive);
    });
  }
}

extension VideoMaximumFrameIndexChunkCollectionQueryProperty on QueryBuilder<
    VideoMaximumFrameIndexChunkCollection,
    VideoMaximumFrameIndexChunkCollection,
    QQueryProperty> {
  QueryBuilder<VideoMaximumFrameIndexChunkCollection, int, QQueryOperations>
      idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection, int, QQueryOperations>
      chunkIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chunkIndex');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection, DateTime,
      QQueryOperations> computedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'computedAt');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection, List<int>,
      QQueryOperations> descriptorBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'descriptorBytes');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection, int?, QQueryOperations>
      encodedByteCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'encodedByteCount');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection, String, QQueryOperations>
      fingerprintProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fingerprint');
    });
  }

  QueryBuilder<VideoMaximumFrameIndexChunkCollection, String, QQueryOperations>
      mediaIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaId');
    });
  }
}
