// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'foundation_status_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FoundationStatusDto {

@JsonKey(name: 'sample_id') String get sampleId; String get status;
/// Create a copy of FoundationStatusDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FoundationStatusDtoCopyWith<FoundationStatusDto> get copyWith => _$FoundationStatusDtoCopyWithImpl<FoundationStatusDto>(this as FoundationStatusDto, _$identity);

  /// Serializes this FoundationStatusDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FoundationStatusDto&&(identical(other.sampleId, sampleId) || other.sampleId == sampleId)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sampleId,status);

@override
String toString() {
  return 'FoundationStatusDto(sampleId: $sampleId, status: $status)';
}


}

/// @nodoc
abstract mixin class $FoundationStatusDtoCopyWith<$Res>  {
  factory $FoundationStatusDtoCopyWith(FoundationStatusDto value, $Res Function(FoundationStatusDto) _then) = _$FoundationStatusDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'sample_id') String sampleId, String status
});




}
/// @nodoc
class _$FoundationStatusDtoCopyWithImpl<$Res>
    implements $FoundationStatusDtoCopyWith<$Res> {
  _$FoundationStatusDtoCopyWithImpl(this._self, this._then);

  final FoundationStatusDto _self;
  final $Res Function(FoundationStatusDto) _then;

/// Create a copy of FoundationStatusDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sampleId = null,Object? status = null,}) {
  return _then(_self.copyWith(
sampleId: null == sampleId ? _self.sampleId : sampleId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FoundationStatusDto].
extension FoundationStatusDtoPatterns on FoundationStatusDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FoundationStatusDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FoundationStatusDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FoundationStatusDto value)  $default,){
final _that = this;
switch (_that) {
case _FoundationStatusDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FoundationStatusDto value)?  $default,){
final _that = this;
switch (_that) {
case _FoundationStatusDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'sample_id')  String sampleId,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FoundationStatusDto() when $default != null:
return $default(_that.sampleId,_that.status);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'sample_id')  String sampleId,  String status)  $default,) {final _that = this;
switch (_that) {
case _FoundationStatusDto():
return $default(_that.sampleId,_that.status);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'sample_id')  String sampleId,  String status)?  $default,) {final _that = this;
switch (_that) {
case _FoundationStatusDto() when $default != null:
return $default(_that.sampleId,_that.status);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true)
class _FoundationStatusDto implements FoundationStatusDto {
  const _FoundationStatusDto({@JsonKey(name: 'sample_id') required this.sampleId, required this.status});
  factory _FoundationStatusDto.fromJson(Map<String, dynamic> json) => _$FoundationStatusDtoFromJson(json);

@override@JsonKey(name: 'sample_id') final  String sampleId;
@override final  String status;

/// Create a copy of FoundationStatusDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FoundationStatusDtoCopyWith<_FoundationStatusDto> get copyWith => __$FoundationStatusDtoCopyWithImpl<_FoundationStatusDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FoundationStatusDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FoundationStatusDto&&(identical(other.sampleId, sampleId) || other.sampleId == sampleId)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sampleId,status);

@override
String toString() {
  return 'FoundationStatusDto(sampleId: $sampleId, status: $status)';
}


}

/// @nodoc
abstract mixin class _$FoundationStatusDtoCopyWith<$Res> implements $FoundationStatusDtoCopyWith<$Res> {
  factory _$FoundationStatusDtoCopyWith(_FoundationStatusDto value, $Res Function(_FoundationStatusDto) _then) = __$FoundationStatusDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'sample_id') String sampleId, String status
});




}
/// @nodoc
class __$FoundationStatusDtoCopyWithImpl<$Res>
    implements _$FoundationStatusDtoCopyWith<$Res> {
  __$FoundationStatusDtoCopyWithImpl(this._self, this._then);

  final _FoundationStatusDto _self;
  final $Res Function(_FoundationStatusDto) _then;

/// Create a copy of FoundationStatusDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sampleId = null,Object? status = null,}) {
  return _then(_FoundationStatusDto(
sampleId: null == sampleId ? _self.sampleId : sampleId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
