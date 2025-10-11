// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'favorite_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FavoriteModel _$FavoriteModelFromJson(Map<String, dynamic> json) {
  return _FavoriteModel.fromJson(json);
}

/// @nodoc
mixin _$FavoriteModel {
  String get itemId => throw _privateConstructorUsedError;
  FavoriteItemType get itemType => throw _privateConstructorUsedError;
  DateTime get addedAt => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  /// Serializes this FavoriteModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FavoriteModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FavoriteModelCopyWith<FavoriteModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FavoriteModelCopyWith<$Res> {
  factory $FavoriteModelCopyWith(
    FavoriteModel value,
    $Res Function(FavoriteModel) then,
  ) = _$FavoriteModelCopyWithImpl<$Res, FavoriteModel>;
  @useResult
  $Res call({
    String itemId,
    FavoriteItemType itemType,
    DateTime addedAt,
    Map<String, dynamic>? metadata,
  });
}

/// @nodoc
class _$FavoriteModelCopyWithImpl<$Res, $Val extends FavoriteModel>
    implements $FavoriteModelCopyWith<$Res> {
  _$FavoriteModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FavoriteModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? itemId = null,
    Object? itemType = null,
    Object? addedAt = null,
    Object? metadata = freezed,
  }) {
    return _then(
      _value.copyWith(
            itemId: null == itemId
                ? _value.itemId
                : itemId // ignore: cast_nullable_to_non_nullable
                    as String,
            itemType: null == itemType
                ? _value.itemType
                : itemType // ignore: cast_nullable_to_non_nullable
                    as FavoriteItemType,
            addedAt: null == addedAt
                ? _value.addedAt
                : addedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
            metadata: freezed == metadata
                ? _value.metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FavoriteModelImplCopyWith<$Res>
    implements $FavoriteModelCopyWith<$Res> {
  factory _$$FavoriteModelImplCopyWith(
    _$FavoriteModelImpl value,
    $Res Function(_$FavoriteModelImpl) then,
  ) = __$$FavoriteModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String itemId,
    FavoriteItemType itemType,
    DateTime addedAt,
    Map<String, dynamic>? metadata,
  });
}

/// @nodoc
class __$$FavoriteModelImplCopyWithImpl<$Res>
    extends _$FavoriteModelCopyWithImpl<$Res, _$FavoriteModelImpl>
    implements _$$FavoriteModelImplCopyWith<$Res> {
  __$$FavoriteModelImplCopyWithImpl(
    _$FavoriteModelImpl _value,
    $Res Function(_$FavoriteModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FavoriteModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? itemId = null,
    Object? itemType = null,
    Object? addedAt = null,
    Object? metadata = freezed,
  }) {
    return _then(
      _$FavoriteModelImpl(
        itemId: null == itemId
            ? _value.itemId
            : itemId // ignore: cast_nullable_to_non_nullable
                as String,
        itemType: null == itemType
            ? _value.itemType
            : itemType // ignore: cast_nullable_to_non_nullable
                as FavoriteItemType,
        addedAt: null == addedAt
            ? _value.addedAt
            : addedAt // ignore: cast_nullable_to_non_nullable
                as DateTime,
        metadata: freezed == metadata
            ? _value.metadata
            : metadata // ignore: cast_nullable_to_non_nullable
                as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FavoriteModelImpl implements _FavoriteModel {
  const _$FavoriteModelImpl({
    required this.itemId,
    required this.itemType,
    required this.addedAt,
    this.metadata,
  });

  factory _$FavoriteModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$FavoriteModelImplFromJson(json);

  @override
  final String itemId;
  @override
  final FavoriteItemType itemType;
  @override
  final DateTime addedAt;
  @override
  final Map<String, dynamic>? metadata;

  @override
  String toString() {
    return 'FavoriteModel(itemId: $itemId, itemType: $itemType, addedAt: $addedAt, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FavoriteModelImpl &&
            (identical(other.itemId, itemId) || other.itemId == itemId) &&
            (identical(other.itemType, itemType) ||
                other.itemType == itemType) &&
            (identical(other.addedAt, addedAt) || other.addedAt == addedAt) &&
            const DeepCollectionEquality().equals(other.metadata, metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
        runtimeType,
        itemId,
        itemType,
        addedAt,
        const DeepCollectionEquality().hash(metadata),
      );

  /// Create a copy of FavoriteModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FavoriteModelImplCopyWith<_$FavoriteModelImpl> get copyWith =>
      __$$FavoriteModelImplCopyWithImpl<_$FavoriteModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FavoriteModelImplToJson(this);
  }
}

abstract class _FavoriteModel implements FavoriteModel {
  const factory _FavoriteModel({
    required final String itemId,
    required final FavoriteItemType itemType,
    required final DateTime addedAt,
    final Map<String, dynamic>? metadata,
  }) = _$FavoriteModelImpl;

  factory _FavoriteModel.fromJson(Map<String, dynamic> json) =
      _$FavoriteModelImpl.fromJson;

  @override
  String get itemId;
  @override
  FavoriteItemType get itemType;
  @override
  DateTime get addedAt;
  @override
  Map<String, dynamic>? get metadata;

  /// Create a copy of FavoriteModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FavoriteModelImplCopyWith<_$FavoriteModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
