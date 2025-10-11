// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FavoriteModelImpl _$$FavoriteModelImplFromJson(Map<String, dynamic> json) =>
    _$FavoriteModelImpl(
      itemId: json['itemId'] as String,
      itemType: $enumDecode(_$FavoriteItemTypeEnumMap, json['itemType']),
      addedAt: DateTime.parse(json['addedAt'] as String),
      metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e),
      ),
    );

Map<String, dynamic> _$$FavoriteModelImplToJson(_$FavoriteModelImpl instance) =>
    <String, dynamic>{
      'itemId': instance.itemId,
      'itemType': _$FavoriteItemTypeEnumMap[instance.itemType]!,
      'addedAt': instance.addedAt.toIso8601String(),
      'metadata': instance.metadata,
    };

const _$FavoriteItemTypeEnumMap = {
  FavoriteItemType.media: 'media',
  FavoriteItemType.directory: 'directory',
};
