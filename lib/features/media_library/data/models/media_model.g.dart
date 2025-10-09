// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MediaModelImpl _$$MediaModelImplFromJson(Map<String, dynamic> json) =>
    _$MediaModelImpl(
      id: json['id'] as String,
      path: json['path'] as String,
      name: json['name'] as String,
      type: $enumDecode(_$MediaTypeEnumMap, json['type']),
      size: (json['size'] as num).toInt(),
      lastModified: DateTime.parse(json['lastModified'] as String),
      tagIds:
          (json['tagIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      directoryId: json['directoryId'] as String,
      bookmarkData: json['bookmarkData'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$MediaModelImplToJson(_$MediaModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'path': instance.path,
      'name': instance.name,
      'type': _$MediaTypeEnumMap[instance.type]!,
      'size': instance.size,
      'lastModified': instance.lastModified.toIso8601String(),
      'tagIds': instance.tagIds,
      'directoryId': instance.directoryId,
      'bookmarkData': instance.bookmarkData,
      'thumbnailPath': instance.thumbnailPath,
      'width': instance.width,
      'height': instance.height,
      'durationSeconds': instance.durationSeconds,
      'metadata': instance.metadata,
    };

const _$MediaTypeEnumMap = {
  MediaType.image: 'image',
  MediaType.video: 'video',
  MediaType.text: 'text',
  MediaType.audio: 'audio',
  MediaType.document: 'document',
  MediaType.directory: 'directory',
};
