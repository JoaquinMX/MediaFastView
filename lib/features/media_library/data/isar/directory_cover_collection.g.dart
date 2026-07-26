// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'directory_cover_collection.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDirectoryCoverCollectionCollection on Isar {
  IsarCollection<DirectoryCoverCollection> get directoryCoverCollections =>
      this.collection();
}

const DirectoryCoverCollectionSchema = CollectionSchema(
  name: r'DirectoryCoverCollection',
  id: 4220301573362420006,
  properties: {
    r'coverKey': PropertySchema(
      id: 0,
      name: r'coverKey',
      type: IsarType.string,
    ),
    r'directoryPath': PropertySchema(
      id: 1,
      name: r'directoryPath',
      type: IsarType.string,
    ),
    r'mediaType': PropertySchema(
      id: 2,
      name: r'mediaType',
      type: IsarType.string,
      enumMap: _DirectoryCoverCollectionmediaTypeEnumValueMap,
    ),
    r'mode': PropertySchema(
      id: 3,
      name: r'mode',
      type: IsarType.string,
      enumMap: _DirectoryCoverCollectionmodeEnumValueMap,
    ),
    r'profileId': PropertySchema(
      id: 4,
      name: r'profileId',
      type: IsarType.string,
    ),
    r'sourceFileName': PropertySchema(
      id: 5,
      name: r'sourceFileName',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 6,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _directoryCoverCollectionEstimateSize,
  serialize: _directoryCoverCollectionSerialize,
  deserialize: _directoryCoverCollectionDeserialize,
  deserializeProp: _directoryCoverCollectionDeserializeProp,
  idName: r'id',
  indexes: {
    r'coverKey': IndexSchema(
      id: -4884670108781756099,
      name: r'coverKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'coverKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'profileId': IndexSchema(
      id: 6052971939042612300,
      name: r'profileId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'profileId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'directoryPath': IndexSchema(
      id: 8459447327712180000,
      name: r'directoryPath',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'directoryPath',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _directoryCoverCollectionGetId,
  getLinks: _directoryCoverCollectionGetLinks,
  attach: _directoryCoverCollectionAttach,
  version: '3.1.0+1',
);

int _directoryCoverCollectionEstimateSize(
  DirectoryCoverCollection object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.coverKey.length * 3;
  bytesCount += 3 + object.directoryPath.length * 3;
  bytesCount += 3 + object.mediaType.name.length * 3;
  bytesCount += 3 + object.mode.name.length * 3;
  bytesCount += 3 + object.profileId.length * 3;
  bytesCount += 3 + object.sourceFileName.length * 3;
  return bytesCount;
}

void _directoryCoverCollectionSerialize(
  DirectoryCoverCollection object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.coverKey);
  writer.writeString(offsets[1], object.directoryPath);
  writer.writeString(offsets[2], object.mediaType.name);
  writer.writeString(offsets[3], object.mode.name);
  writer.writeString(offsets[4], object.profileId);
  writer.writeString(offsets[5], object.sourceFileName);
  writer.writeDateTime(offsets[6], object.updatedAt);
}

DirectoryCoverCollection _directoryCoverCollectionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DirectoryCoverCollection(
    coverKey: reader.readString(offsets[0]),
    directoryPath: reader.readString(offsets[1]),
    mediaType: _DirectoryCoverCollectionmediaTypeValueEnumMap[
            reader.readStringOrNull(offsets[2])] ??
        MediaType.image,
    mode: _DirectoryCoverCollectionmodeValueEnumMap[
            reader.readStringOrNull(offsets[3])] ??
        DirectoryCoverMode.media,
    profileId: reader.readString(offsets[4]),
    sourceFileName: reader.readString(offsets[5]),
    updatedAt: reader.readDateTime(offsets[6]),
  );
  object.id = id;
  return object;
}

P _directoryCoverCollectionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (_DirectoryCoverCollectionmediaTypeValueEnumMap[
              reader.readStringOrNull(offset)] ??
          MediaType.image) as P;
    case 3:
      return (_DirectoryCoverCollectionmodeValueEnumMap[
              reader.readStringOrNull(offset)] ??
          DirectoryCoverMode.media) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _DirectoryCoverCollectionmediaTypeEnumValueMap = {
  r'image': r'image',
  r'video': r'video',
  r'text': r'text',
  r'directory': r'directory',
  r'audio': r'audio',
};
const _DirectoryCoverCollectionmediaTypeValueEnumMap = {
  r'image': MediaType.image,
  r'video': MediaType.video,
  r'text': MediaType.text,
  r'directory': MediaType.directory,
  r'audio': MediaType.audio,
};
const _DirectoryCoverCollectionmodeEnumValueMap = {
  r'media': r'media',
  r'none': r'none',
};
const _DirectoryCoverCollectionmodeValueEnumMap = {
  r'media': DirectoryCoverMode.media,
  r'none': DirectoryCoverMode.none,
};

Id _directoryCoverCollectionGetId(DirectoryCoverCollection object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _directoryCoverCollectionGetLinks(
    DirectoryCoverCollection object) {
  return [];
}

void _directoryCoverCollectionAttach(
    IsarCollection<dynamic> col, Id id, DirectoryCoverCollection object) {
  object.id = id;
}

extension DirectoryCoverCollectionByIndex
    on IsarCollection<DirectoryCoverCollection> {
  Future<DirectoryCoverCollection?> getByCoverKey(String coverKey) {
    return getByIndex(r'coverKey', [coverKey]);
  }

  DirectoryCoverCollection? getByCoverKeySync(String coverKey) {
    return getByIndexSync(r'coverKey', [coverKey]);
  }

  Future<bool> deleteByCoverKey(String coverKey) {
    return deleteByIndex(r'coverKey', [coverKey]);
  }

  bool deleteByCoverKeySync(String coverKey) {
    return deleteByIndexSync(r'coverKey', [coverKey]);
  }

  Future<List<DirectoryCoverCollection?>> getAllByCoverKey(
      List<String> coverKeyValues) {
    final values = coverKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'coverKey', values);
  }

  List<DirectoryCoverCollection?> getAllByCoverKeySync(
      List<String> coverKeyValues) {
    final values = coverKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'coverKey', values);
  }

  Future<int> deleteAllByCoverKey(List<String> coverKeyValues) {
    final values = coverKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'coverKey', values);
  }

  int deleteAllByCoverKeySync(List<String> coverKeyValues) {
    final values = coverKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'coverKey', values);
  }

  Future<Id> putByCoverKey(DirectoryCoverCollection object) {
    return putByIndex(r'coverKey', object);
  }

  Id putByCoverKeySync(DirectoryCoverCollection object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'coverKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCoverKey(List<DirectoryCoverCollection> objects) {
    return putAllByIndex(r'coverKey', objects);
  }

  List<Id> putAllByCoverKeySync(List<DirectoryCoverCollection> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'coverKey', objects, saveLinks: saveLinks);
  }
}

extension DirectoryCoverCollectionQueryWhereSort on QueryBuilder<
    DirectoryCoverCollection, DirectoryCoverCollection, QWhere> {
  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension DirectoryCoverCollectionQueryWhere on QueryBuilder<
    DirectoryCoverCollection, DirectoryCoverCollection, QWhereClause> {
  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
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

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
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

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterWhereClause> coverKeyEqualTo(String coverKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'coverKey',
        value: [coverKey],
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterWhereClause> coverKeyNotEqualTo(String coverKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'coverKey',
              lower: [],
              upper: [coverKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'coverKey',
              lower: [coverKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'coverKey',
              lower: [coverKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'coverKey',
              lower: [],
              upper: [coverKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterWhereClause> profileIdEqualTo(String profileId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'profileId',
        value: [profileId],
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterWhereClause> profileIdNotEqualTo(String profileId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'profileId',
              lower: [],
              upper: [profileId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'profileId',
              lower: [profileId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'profileId',
              lower: [profileId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'profileId',
              lower: [],
              upper: [profileId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterWhereClause> directoryPathEqualTo(String directoryPath) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'directoryPath',
        value: [directoryPath],
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterWhereClause> directoryPathNotEqualTo(String directoryPath) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'directoryPath',
              lower: [],
              upper: [directoryPath],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'directoryPath',
              lower: [directoryPath],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'directoryPath',
              lower: [directoryPath],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'directoryPath',
              lower: [],
              upper: [directoryPath],
              includeUpper: false,
            ));
      }
    });
  }
}

extension DirectoryCoverCollectionQueryFilter on QueryBuilder<
    DirectoryCoverCollection, DirectoryCoverCollection, QFilterCondition> {
  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> coverKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coverKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> coverKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'coverKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> coverKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'coverKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> coverKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'coverKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> coverKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'coverKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> coverKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'coverKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
          QAfterFilterCondition>
      coverKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'coverKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
          QAfterFilterCondition>
      coverKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'coverKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> coverKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coverKey',
        value: '',
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> coverKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'coverKey',
        value: '',
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> directoryPathEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'directoryPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> directoryPathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'directoryPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> directoryPathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'directoryPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> directoryPathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'directoryPath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> directoryPathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'directoryPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> directoryPathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'directoryPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
          QAfterFilterCondition>
      directoryPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'directoryPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
          QAfterFilterCondition>
      directoryPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'directoryPath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> directoryPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'directoryPath',
        value: '',
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> directoryPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'directoryPath',
        value: '',
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
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

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
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

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
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

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> mediaTypeEqualTo(
    MediaType value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> mediaTypeGreaterThan(
    MediaType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mediaType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> mediaTypeLessThan(
    MediaType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mediaType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> mediaTypeBetween(
    MediaType lower,
    MediaType upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mediaType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> mediaTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'mediaType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> mediaTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'mediaType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
          QAfterFilterCondition>
      mediaTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mediaType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
          QAfterFilterCondition>
      mediaTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mediaType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> mediaTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaType',
        value: '',
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> mediaTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mediaType',
        value: '',
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> modeEqualTo(
    DirectoryCoverMode value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> modeGreaterThan(
    DirectoryCoverMode value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> modeLessThan(
    DirectoryCoverMode value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> modeBetween(
    DirectoryCoverMode lower,
    DirectoryCoverMode upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> modeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'mode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> modeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'mode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
          QAfterFilterCondition>
      modeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
          QAfterFilterCondition>
      modeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> modeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mode',
        value: '',
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> modeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mode',
        value: '',
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> profileIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'profileId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> profileIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'profileId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> profileIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'profileId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> profileIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'profileId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> profileIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'profileId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> profileIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'profileId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
          QAfterFilterCondition>
      profileIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'profileId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
          QAfterFilterCondition>
      profileIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'profileId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> profileIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'profileId',
        value: '',
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> profileIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'profileId',
        value: '',
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> sourceFileNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceFileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> sourceFileNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceFileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> sourceFileNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceFileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> sourceFileNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceFileName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> sourceFileNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceFileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> sourceFileNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceFileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
          QAfterFilterCondition>
      sourceFileNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceFileName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
          QAfterFilterCondition>
      sourceFileNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceFileName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> sourceFileNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceFileName',
        value: '',
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> sourceFileNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceFileName',
        value: '',
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection,
      QAfterFilterCondition> updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension DirectoryCoverCollectionQueryObject on QueryBuilder<
    DirectoryCoverCollection, DirectoryCoverCollection, QFilterCondition> {}

extension DirectoryCoverCollectionQueryLinks on QueryBuilder<
    DirectoryCoverCollection, DirectoryCoverCollection, QFilterCondition> {}

extension DirectoryCoverCollectionQuerySortBy on QueryBuilder<
    DirectoryCoverCollection, DirectoryCoverCollection, QSortBy> {
  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortByCoverKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverKey', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortByCoverKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverKey', Sort.desc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortByDirectoryPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'directoryPath', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortByDirectoryPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'directoryPath', Sort.desc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortByMediaType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaType', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortByMediaTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaType', Sort.desc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortByMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mode', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortByModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mode', Sort.desc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortByProfileId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profileId', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortByProfileIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profileId', Sort.desc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortBySourceFileName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceFileName', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortBySourceFileNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceFileName', Sort.desc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension DirectoryCoverCollectionQuerySortThenBy on QueryBuilder<
    DirectoryCoverCollection, DirectoryCoverCollection, QSortThenBy> {
  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenByCoverKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverKey', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenByCoverKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverKey', Sort.desc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenByDirectoryPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'directoryPath', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenByDirectoryPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'directoryPath', Sort.desc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenByMediaType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaType', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenByMediaTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaType', Sort.desc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenByMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mode', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenByModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mode', Sort.desc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenByProfileId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profileId', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenByProfileIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'profileId', Sort.desc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenBySourceFileName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceFileName', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenBySourceFileNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceFileName', Sort.desc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension DirectoryCoverCollectionQueryWhereDistinct on QueryBuilder<
    DirectoryCoverCollection, DirectoryCoverCollection, QDistinct> {
  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QDistinct>
      distinctByCoverKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'coverKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QDistinct>
      distinctByDirectoryPath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'directoryPath',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QDistinct>
      distinctByMediaType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QDistinct>
      distinctByMode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QDistinct>
      distinctByProfileId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'profileId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QDistinct>
      distinctBySourceFileName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceFileName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverCollection, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension DirectoryCoverCollectionQueryProperty on QueryBuilder<
    DirectoryCoverCollection, DirectoryCoverCollection, QQueryProperty> {
  QueryBuilder<DirectoryCoverCollection, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DirectoryCoverCollection, String, QQueryOperations>
      coverKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'coverKey');
    });
  }

  QueryBuilder<DirectoryCoverCollection, String, QQueryOperations>
      directoryPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'directoryPath');
    });
  }

  QueryBuilder<DirectoryCoverCollection, MediaType, QQueryOperations>
      mediaTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaType');
    });
  }

  QueryBuilder<DirectoryCoverCollection, DirectoryCoverMode, QQueryOperations>
      modeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mode');
    });
  }

  QueryBuilder<DirectoryCoverCollection, String, QQueryOperations>
      profileIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'profileId');
    });
  }

  QueryBuilder<DirectoryCoverCollection, String, QQueryOperations>
      sourceFileNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceFileName');
    });
  }

  QueryBuilder<DirectoryCoverCollection, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
