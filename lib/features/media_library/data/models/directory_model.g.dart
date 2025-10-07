// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'directory_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DirectoryModelImpl _$$DirectoryModelImplFromJson(Map<String, dynamic> json) =>
    _$DirectoryModelImpl(
      id: json['id'] as String,
      path: json['path'] as String,
      name: json['name'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      tagIds:
          (json['tagIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      lastModified: DateTime.parse(json['lastModified'] as String),
      bookmarkData: json['bookmarkData'] as String?,
    );

Map<String, dynamic> _$$DirectoryModelImplToJson(
  _$DirectoryModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'path': instance.path,
  'name': instance.name,
  'thumbnailPath': instance.thumbnailPath,
  'tagIds': instance.tagIds,
  'lastModified': instance.lastModified.toIso8601String(),
  'bookmarkData': instance.bookmarkData,
};
