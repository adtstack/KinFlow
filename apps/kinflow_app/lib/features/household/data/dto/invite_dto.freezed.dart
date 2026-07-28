// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invite_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InviteDto {

 String get id; String get householdId; String get role; String get expiresAt; String get status;
/// Create a copy of InviteDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InviteDtoCopyWith<InviteDto> get copyWith => _$InviteDtoCopyWithImpl<InviteDto>(this as InviteDto, _$identity);

  /// Serializes this InviteDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InviteDto&&(identical(other.id, id) || other.id == id)&&(identical(other.householdId, householdId) || other.householdId == householdId)&&(identical(other.role, role) || other.role == role)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,householdId,role,expiresAt,status);

@override
String toString() {
  return 'InviteDto(id: $id, householdId: $householdId, role: $role, expiresAt: $expiresAt, status: $status)';
}


}

/// @nodoc
abstract mixin class $InviteDtoCopyWith<$Res>  {
  factory $InviteDtoCopyWith(InviteDto value, $Res Function(InviteDto) _then) = _$InviteDtoCopyWithImpl;
@useResult
$Res call({
 String id, String householdId, String role, String expiresAt, String status
});




}
/// @nodoc
class _$InviteDtoCopyWithImpl<$Res>
    implements $InviteDtoCopyWith<$Res> {
  _$InviteDtoCopyWithImpl(this._self, this._then);

  final InviteDto _self;
  final $Res Function(InviteDto) _then;

/// Create a copy of InviteDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? householdId = null,Object? role = null,Object? expiresAt = null,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,householdId: null == householdId ? _self.householdId : householdId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InviteDto].
extension InviteDtoPatterns on InviteDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InviteDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InviteDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InviteDto value)  $default,){
final _that = this;
switch (_that) {
case _InviteDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InviteDto value)?  $default,){
final _that = this;
switch (_that) {
case _InviteDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String householdId,  String role,  String expiresAt,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InviteDto() when $default != null:
return $default(_that.id,_that.householdId,_that.role,_that.expiresAt,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String householdId,  String role,  String expiresAt,  String status)  $default,) {final _that = this;
switch (_that) {
case _InviteDto():
return $default(_that.id,_that.householdId,_that.role,_that.expiresAt,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String householdId,  String role,  String expiresAt,  String status)?  $default,) {final _that = this;
switch (_that) {
case _InviteDto() when $default != null:
return $default(_that.id,_that.householdId,_that.role,_that.expiresAt,_that.status);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
class _InviteDto implements InviteDto {
  const _InviteDto({required this.id, required this.householdId, required this.role, required this.expiresAt, required this.status});
  factory _InviteDto.fromJson(Map<String, dynamic> json) => _$InviteDtoFromJson(json);

@override final  String id;
@override final  String householdId;
@override final  String role;
@override final  String expiresAt;
@override final  String status;

/// Create a copy of InviteDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InviteDtoCopyWith<_InviteDto> get copyWith => __$InviteDtoCopyWithImpl<_InviteDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InviteDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InviteDto&&(identical(other.id, id) || other.id == id)&&(identical(other.householdId, householdId) || other.householdId == householdId)&&(identical(other.role, role) || other.role == role)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,householdId,role,expiresAt,status);

@override
String toString() {
  return 'InviteDto(id: $id, householdId: $householdId, role: $role, expiresAt: $expiresAt, status: $status)';
}


}

/// @nodoc
abstract mixin class _$InviteDtoCopyWith<$Res> implements $InviteDtoCopyWith<$Res> {
  factory _$InviteDtoCopyWith(_InviteDto value, $Res Function(_InviteDto) _then) = __$InviteDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String householdId, String role, String expiresAt, String status
});




}
/// @nodoc
class __$InviteDtoCopyWithImpl<$Res>
    implements _$InviteDtoCopyWith<$Res> {
  __$InviteDtoCopyWithImpl(this._self, this._then);

  final _InviteDto _self;
  final $Res Function(_InviteDto) _then;

/// Create a copy of InviteDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? householdId = null,Object? role = null,Object? expiresAt = null,Object? status = null,}) {
  return _then(_InviteDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,householdId: null == householdId ? _self.householdId : householdId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$InvitePreviewDto {

 bool get valid; String get householdDisplayName; String get inviterDisplayName; String get role; String get expiresAt;
/// Create a copy of InvitePreviewDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvitePreviewDtoCopyWith<InvitePreviewDto> get copyWith => _$InvitePreviewDtoCopyWithImpl<InvitePreviewDto>(this as InvitePreviewDto, _$identity);

  /// Serializes this InvitePreviewDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvitePreviewDto&&(identical(other.valid, valid) || other.valid == valid)&&(identical(other.householdDisplayName, householdDisplayName) || other.householdDisplayName == householdDisplayName)&&(identical(other.inviterDisplayName, inviterDisplayName) || other.inviterDisplayName == inviterDisplayName)&&(identical(other.role, role) || other.role == role)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,valid,householdDisplayName,inviterDisplayName,role,expiresAt);

@override
String toString() {
  return 'InvitePreviewDto(valid: $valid, householdDisplayName: $householdDisplayName, inviterDisplayName: $inviterDisplayName, role: $role, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $InvitePreviewDtoCopyWith<$Res>  {
  factory $InvitePreviewDtoCopyWith(InvitePreviewDto value, $Res Function(InvitePreviewDto) _then) = _$InvitePreviewDtoCopyWithImpl;
@useResult
$Res call({
 bool valid, String householdDisplayName, String inviterDisplayName, String role, String expiresAt
});




}
/// @nodoc
class _$InvitePreviewDtoCopyWithImpl<$Res>
    implements $InvitePreviewDtoCopyWith<$Res> {
  _$InvitePreviewDtoCopyWithImpl(this._self, this._then);

  final InvitePreviewDto _self;
  final $Res Function(InvitePreviewDto) _then;

/// Create a copy of InvitePreviewDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? valid = null,Object? householdDisplayName = null,Object? inviterDisplayName = null,Object? role = null,Object? expiresAt = null,}) {
  return _then(_self.copyWith(
valid: null == valid ? _self.valid : valid // ignore: cast_nullable_to_non_nullable
as bool,householdDisplayName: null == householdDisplayName ? _self.householdDisplayName : householdDisplayName // ignore: cast_nullable_to_non_nullable
as String,inviterDisplayName: null == inviterDisplayName ? _self.inviterDisplayName : inviterDisplayName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InvitePreviewDto].
extension InvitePreviewDtoPatterns on InvitePreviewDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvitePreviewDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvitePreviewDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvitePreviewDto value)  $default,){
final _that = this;
switch (_that) {
case _InvitePreviewDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvitePreviewDto value)?  $default,){
final _that = this;
switch (_that) {
case _InvitePreviewDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool valid,  String householdDisplayName,  String inviterDisplayName,  String role,  String expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvitePreviewDto() when $default != null:
return $default(_that.valid,_that.householdDisplayName,_that.inviterDisplayName,_that.role,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool valid,  String householdDisplayName,  String inviterDisplayName,  String role,  String expiresAt)  $default,) {final _that = this;
switch (_that) {
case _InvitePreviewDto():
return $default(_that.valid,_that.householdDisplayName,_that.inviterDisplayName,_that.role,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool valid,  String householdDisplayName,  String inviterDisplayName,  String role,  String expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _InvitePreviewDto() when $default != null:
return $default(_that.valid,_that.householdDisplayName,_that.inviterDisplayName,_that.role,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
class _InvitePreviewDto implements InvitePreviewDto {
  const _InvitePreviewDto({required this.valid, required this.householdDisplayName, required this.inviterDisplayName, required this.role, required this.expiresAt});
  factory _InvitePreviewDto.fromJson(Map<String, dynamic> json) => _$InvitePreviewDtoFromJson(json);

@override final  bool valid;
@override final  String householdDisplayName;
@override final  String inviterDisplayName;
@override final  String role;
@override final  String expiresAt;

/// Create a copy of InvitePreviewDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvitePreviewDtoCopyWith<_InvitePreviewDto> get copyWith => __$InvitePreviewDtoCopyWithImpl<_InvitePreviewDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvitePreviewDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvitePreviewDto&&(identical(other.valid, valid) || other.valid == valid)&&(identical(other.householdDisplayName, householdDisplayName) || other.householdDisplayName == householdDisplayName)&&(identical(other.inviterDisplayName, inviterDisplayName) || other.inviterDisplayName == inviterDisplayName)&&(identical(other.role, role) || other.role == role)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,valid,householdDisplayName,inviterDisplayName,role,expiresAt);

@override
String toString() {
  return 'InvitePreviewDto(valid: $valid, householdDisplayName: $householdDisplayName, inviterDisplayName: $inviterDisplayName, role: $role, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$InvitePreviewDtoCopyWith<$Res> implements $InvitePreviewDtoCopyWith<$Res> {
  factory _$InvitePreviewDtoCopyWith(_InvitePreviewDto value, $Res Function(_InvitePreviewDto) _then) = __$InvitePreviewDtoCopyWithImpl;
@override @useResult
$Res call({
 bool valid, String householdDisplayName, String inviterDisplayName, String role, String expiresAt
});




}
/// @nodoc
class __$InvitePreviewDtoCopyWithImpl<$Res>
    implements _$InvitePreviewDtoCopyWith<$Res> {
  __$InvitePreviewDtoCopyWithImpl(this._self, this._then);

  final _InvitePreviewDto _self;
  final $Res Function(_InvitePreviewDto) _then;

/// Create a copy of InvitePreviewDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? valid = null,Object? householdDisplayName = null,Object? inviterDisplayName = null,Object? role = null,Object? expiresAt = null,}) {
  return _then(_InvitePreviewDto(
valid: null == valid ? _self.valid : valid // ignore: cast_nullable_to_non_nullable
as bool,householdDisplayName: null == householdDisplayName ? _self.householdDisplayName : householdDisplayName // ignore: cast_nullable_to_non_nullable
as String,inviterDisplayName: null == inviterDisplayName ? _self.inviterDisplayName : inviterDisplayName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$InviteMemberDto {

 String get id; String get householdId; String get displayName; String get role; bool get activeHouseholdSet;
/// Create a copy of InviteMemberDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InviteMemberDtoCopyWith<InviteMemberDto> get copyWith => _$InviteMemberDtoCopyWithImpl<InviteMemberDto>(this as InviteMemberDto, _$identity);

  /// Serializes this InviteMemberDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InviteMemberDto&&(identical(other.id, id) || other.id == id)&&(identical(other.householdId, householdId) || other.householdId == householdId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.role, role) || other.role == role)&&(identical(other.activeHouseholdSet, activeHouseholdSet) || other.activeHouseholdSet == activeHouseholdSet));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,householdId,displayName,role,activeHouseholdSet);

@override
String toString() {
  return 'InviteMemberDto(id: $id, householdId: $householdId, displayName: $displayName, role: $role, activeHouseholdSet: $activeHouseholdSet)';
}


}

/// @nodoc
abstract mixin class $InviteMemberDtoCopyWith<$Res>  {
  factory $InviteMemberDtoCopyWith(InviteMemberDto value, $Res Function(InviteMemberDto) _then) = _$InviteMemberDtoCopyWithImpl;
@useResult
$Res call({
 String id, String householdId, String displayName, String role, bool activeHouseholdSet
});




}
/// @nodoc
class _$InviteMemberDtoCopyWithImpl<$Res>
    implements $InviteMemberDtoCopyWith<$Res> {
  _$InviteMemberDtoCopyWithImpl(this._self, this._then);

  final InviteMemberDto _self;
  final $Res Function(InviteMemberDto) _then;

/// Create a copy of InviteMemberDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? householdId = null,Object? displayName = null,Object? role = null,Object? activeHouseholdSet = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,householdId: null == householdId ? _self.householdId : householdId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,activeHouseholdSet: null == activeHouseholdSet ? _self.activeHouseholdSet : activeHouseholdSet // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [InviteMemberDto].
extension InviteMemberDtoPatterns on InviteMemberDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InviteMemberDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InviteMemberDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InviteMemberDto value)  $default,){
final _that = this;
switch (_that) {
case _InviteMemberDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InviteMemberDto value)?  $default,){
final _that = this;
switch (_that) {
case _InviteMemberDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String householdId,  String displayName,  String role,  bool activeHouseholdSet)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InviteMemberDto() when $default != null:
return $default(_that.id,_that.householdId,_that.displayName,_that.role,_that.activeHouseholdSet);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String householdId,  String displayName,  String role,  bool activeHouseholdSet)  $default,) {final _that = this;
switch (_that) {
case _InviteMemberDto():
return $default(_that.id,_that.householdId,_that.displayName,_that.role,_that.activeHouseholdSet);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String householdId,  String displayName,  String role,  bool activeHouseholdSet)?  $default,) {final _that = this;
switch (_that) {
case _InviteMemberDto() when $default != null:
return $default(_that.id,_that.householdId,_that.displayName,_that.role,_that.activeHouseholdSet);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
class _InviteMemberDto implements InviteMemberDto {
  const _InviteMemberDto({required this.id, required this.householdId, required this.displayName, required this.role, required this.activeHouseholdSet});
  factory _InviteMemberDto.fromJson(Map<String, dynamic> json) => _$InviteMemberDtoFromJson(json);

@override final  String id;
@override final  String householdId;
@override final  String displayName;
@override final  String role;
@override final  bool activeHouseholdSet;

/// Create a copy of InviteMemberDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InviteMemberDtoCopyWith<_InviteMemberDto> get copyWith => __$InviteMemberDtoCopyWithImpl<_InviteMemberDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InviteMemberDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InviteMemberDto&&(identical(other.id, id) || other.id == id)&&(identical(other.householdId, householdId) || other.householdId == householdId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.role, role) || other.role == role)&&(identical(other.activeHouseholdSet, activeHouseholdSet) || other.activeHouseholdSet == activeHouseholdSet));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,householdId,displayName,role,activeHouseholdSet);

@override
String toString() {
  return 'InviteMemberDto(id: $id, householdId: $householdId, displayName: $displayName, role: $role, activeHouseholdSet: $activeHouseholdSet)';
}


}

/// @nodoc
abstract mixin class _$InviteMemberDtoCopyWith<$Res> implements $InviteMemberDtoCopyWith<$Res> {
  factory _$InviteMemberDtoCopyWith(_InviteMemberDto value, $Res Function(_InviteMemberDto) _then) = __$InviteMemberDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String householdId, String displayName, String role, bool activeHouseholdSet
});




}
/// @nodoc
class __$InviteMemberDtoCopyWithImpl<$Res>
    implements _$InviteMemberDtoCopyWith<$Res> {
  __$InviteMemberDtoCopyWithImpl(this._self, this._then);

  final _InviteMemberDto _self;
  final $Res Function(_InviteMemberDto) _then;

/// Create a copy of InviteMemberDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? householdId = null,Object? displayName = null,Object? role = null,Object? activeHouseholdSet = null,}) {
  return _then(_InviteMemberDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,householdId: null == householdId ? _self.householdId : householdId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,activeHouseholdSet: null == activeHouseholdSet ? _self.activeHouseholdSet : activeHouseholdSet // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$RevokedInviteDto {

 String get id; String get householdId; String get status;
/// Create a copy of RevokedInviteDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RevokedInviteDtoCopyWith<RevokedInviteDto> get copyWith => _$RevokedInviteDtoCopyWithImpl<RevokedInviteDto>(this as RevokedInviteDto, _$identity);

  /// Serializes this RevokedInviteDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RevokedInviteDto&&(identical(other.id, id) || other.id == id)&&(identical(other.householdId, householdId) || other.householdId == householdId)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,householdId,status);

@override
String toString() {
  return 'RevokedInviteDto(id: $id, householdId: $householdId, status: $status)';
}


}

/// @nodoc
abstract mixin class $RevokedInviteDtoCopyWith<$Res>  {
  factory $RevokedInviteDtoCopyWith(RevokedInviteDto value, $Res Function(RevokedInviteDto) _then) = _$RevokedInviteDtoCopyWithImpl;
@useResult
$Res call({
 String id, String householdId, String status
});




}
/// @nodoc
class _$RevokedInviteDtoCopyWithImpl<$Res>
    implements $RevokedInviteDtoCopyWith<$Res> {
  _$RevokedInviteDtoCopyWithImpl(this._self, this._then);

  final RevokedInviteDto _self;
  final $Res Function(RevokedInviteDto) _then;

/// Create a copy of RevokedInviteDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? householdId = null,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,householdId: null == householdId ? _self.householdId : householdId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RevokedInviteDto].
extension RevokedInviteDtoPatterns on RevokedInviteDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RevokedInviteDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RevokedInviteDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RevokedInviteDto value)  $default,){
final _that = this;
switch (_that) {
case _RevokedInviteDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RevokedInviteDto value)?  $default,){
final _that = this;
switch (_that) {
case _RevokedInviteDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String householdId,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RevokedInviteDto() when $default != null:
return $default(_that.id,_that.householdId,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String householdId,  String status)  $default,) {final _that = this;
switch (_that) {
case _RevokedInviteDto():
return $default(_that.id,_that.householdId,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String householdId,  String status)?  $default,) {final _that = this;
switch (_that) {
case _RevokedInviteDto() when $default != null:
return $default(_that.id,_that.householdId,_that.status);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
class _RevokedInviteDto implements RevokedInviteDto {
  const _RevokedInviteDto({required this.id, required this.householdId, required this.status});
  factory _RevokedInviteDto.fromJson(Map<String, dynamic> json) => _$RevokedInviteDtoFromJson(json);

@override final  String id;
@override final  String householdId;
@override final  String status;

/// Create a copy of RevokedInviteDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RevokedInviteDtoCopyWith<_RevokedInviteDto> get copyWith => __$RevokedInviteDtoCopyWithImpl<_RevokedInviteDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RevokedInviteDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RevokedInviteDto&&(identical(other.id, id) || other.id == id)&&(identical(other.householdId, householdId) || other.householdId == householdId)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,householdId,status);

@override
String toString() {
  return 'RevokedInviteDto(id: $id, householdId: $householdId, status: $status)';
}


}

/// @nodoc
abstract mixin class _$RevokedInviteDtoCopyWith<$Res> implements $RevokedInviteDtoCopyWith<$Res> {
  factory _$RevokedInviteDtoCopyWith(_RevokedInviteDto value, $Res Function(_RevokedInviteDto) _then) = __$RevokedInviteDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String householdId, String status
});




}
/// @nodoc
class __$RevokedInviteDtoCopyWithImpl<$Res>
    implements _$RevokedInviteDtoCopyWith<$Res> {
  __$RevokedInviteDtoCopyWithImpl(this._self, this._then);

  final _RevokedInviteDto _self;
  final $Res Function(_RevokedInviteDto) _then;

/// Create a copy of RevokedInviteDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? householdId = null,Object? status = null,}) {
  return _then(_RevokedInviteDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,householdId: null == householdId ? _self.householdId : householdId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
