// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'directory_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DirectoryModel _$DirectoryModelFromJson(Map<String, dynamic> json) {
  return _DirectoryModel.fromJson(json);
}

/// @nodoc
mixin _$DirectoryModel {
  String get id => throw _privateConstructorUsedError;
  String get path => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get thumbnailPath => throw _privateConstructorUsedError;
  List<String> get tagIds => throw _privateConstructorUsedError;
  DateTime get lastModified => throw _privateConstructorUsedError;
  String? get bookmarkData => throw _privateConstructorUsedError;

  /// Serializes this DirectoryModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DirectoryModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DirectoryModelCopyWith<DirectoryModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DirectoryModelCopyWith<$Res> {
  factory $DirectoryModelCopyWith(
    DirectoryModel value,
    $Res Function(DirectoryModel) then,
  ) = _$DirectoryModelCopyWithImpl<$Res, DirectoryModel>;
  @useResult
  $Res call({
    String id,
    String path,
    String name,
    String? thumbnailPath,
    List<String> tagIds,
    DateTime lastModified,
    String? bookmarkData,
  });
}

/// @nodoc
class _$DirectoryModelCopyWithImpl<$Res, $Val extends DirectoryModel>
    implements $DirectoryModelCopyWith<$Res> {
  _$DirectoryModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DirectoryModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? path = null,
    Object? name = null,
    Object? thumbnailPath = freezed,
    Object? tagIds = null,
    Object? lastModified = null,
    Object? bookmarkData = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            path: null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            thumbnailPath: freezed == thumbnailPath
                ? _value.thumbnailPath
                : thumbnailPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            tagIds: null == tagIds
                ? _value.tagIds
                : tagIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            lastModified: null == lastModified
                ? _value.lastModified
                : lastModified // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            bookmarkData: freezed == bookmarkData
                ? _value.bookmarkData
                : bookmarkData // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DirectoryModelImplCopyWith<$Res>
    implements $DirectoryModelCopyWith<$Res> {
  factory _$$DirectoryModelImplCopyWith(
    _$DirectoryModelImpl value,
    $Res Function(_$DirectoryModelImpl) then,
  ) = __$$DirectoryModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String path,
    String name,
    String? thumbnailPath,
    List<String> tagIds,
    DateTime lastModified,
    String? bookmarkData,
  });
}

/// @nodoc
class __$$DirectoryModelImplCopyWithImpl<$Res>
    extends _$DirectoryModelCopyWithImpl<$Res, _$DirectoryModelImpl>
    implements _$$DirectoryModelImplCopyWith<$Res> {
  __$$DirectoryModelImplCopyWithImpl(
    _$DirectoryModelImpl _value,
    $Res Function(_$DirectoryModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DirectoryModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? path = null,
    Object? name = null,
    Object? thumbnailPath = freezed,
    Object? tagIds = null,
    Object? lastModified = null,
    Object? bookmarkData = freezed,
  }) {
    return _then(
      _$DirectoryModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        path: null == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        thumbnailPath: freezed == thumbnailPath
            ? _value.thumbnailPath
            : thumbnailPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        tagIds: null == tagIds
            ? _value._tagIds
            : tagIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        lastModified: null == lastModified
            ? _value.lastModified
            : lastModified // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        bookmarkData: freezed == bookmarkData
            ? _value.bookmarkData
            : bookmarkData // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DirectoryModelImpl implements _DirectoryModel {
  const _$DirectoryModelImpl({
    required this.id,
    required this.path,
    required this.name,
    this.thumbnailPath,
    final List<String> tagIds = const <String>[],
    required this.lastModified,
    this.bookmarkData,
  }) : _tagIds = tagIds;

  factory _$DirectoryModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$DirectoryModelImplFromJson(json);

  @override
  final String id;
  @override
  final String path;
  @override
  final String name;
  @override
  final String? thumbnailPath;
  final List<String> _tagIds;
  @override
  @JsonKey()
  List<String> get tagIds {
    if (_tagIds is EqualUnmodifiableListView) return _tagIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tagIds);
  }

  @override
  final DateTime lastModified;
  @override
  final String? bookmarkData;

  @override
  String toString() {
    return 'DirectoryModel(id: $id, path: $path, name: $name, thumbnailPath: $thumbnailPath, tagIds: $tagIds, lastModified: $lastModified, bookmarkData: $bookmarkData)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DirectoryModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.thumbnailPath, thumbnailPath) ||
                other.thumbnailPath == thumbnailPath) &&
            const DeepCollectionEquality().equals(other._tagIds, _tagIds) &&
            (identical(other.lastModified, lastModified) ||
                other.lastModified == lastModified) &&
            (identical(other.bookmarkData, bookmarkData) ||
                other.bookmarkData == bookmarkData));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    path,
    name,
    thumbnailPath,
    const DeepCollectionEquality().hash(_tagIds),
    lastModified,
    bookmarkData,
  );

  /// Create a copy of DirectoryModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DirectoryModelImplCopyWith<_$DirectoryModelImpl> get copyWith =>
      __$$DirectoryModelImplCopyWithImpl<_$DirectoryModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DirectoryModelImplToJson(this);
  }
}

abstract class _DirectoryModel implements DirectoryModel {
  const factory _DirectoryModel({
    required final String id,
    required final String path,
    required final String name,
    final String? thumbnailPath,
    final List<String> tagIds,
    required final DateTime lastModified,
    final String? bookmarkData,
  }) = _$DirectoryModelImpl;

  factory _DirectoryModel.fromJson(Map<String, dynamic> json) =
      _$DirectoryModelImpl.fromJson;

  @override
  String get id;
  @override
  String get path;
  @override
  String get name;
  @override
  String? get thumbnailPath;
  @override
  List<String> get tagIds;
  @override
  DateTime get lastModified;
  @override
  String? get bookmarkData;

  /// Create a copy of DirectoryModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DirectoryModelImplCopyWith<_$DirectoryModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
