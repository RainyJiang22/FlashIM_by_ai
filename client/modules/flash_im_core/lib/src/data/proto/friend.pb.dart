// This is a generated file - do not edit.
//
// Generated from friend.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class FriendUser extends $pb.GeneratedMessage {
  factory FriendUser({
    $fixnum.Int64? accountId,
    $core.String? nickname,
    $core.String? avatar,
    $core.String? signature,
    $core.String? flashId,
  }) {
    final result = create();
    if (accountId != null) result.accountId = accountId;
    if (nickname != null) result.nickname = nickname;
    if (avatar != null) result.avatar = avatar;
    if (signature != null) result.signature = signature;
    if (flashId != null) result.flashId = flashId;
    return result;
  }

  FriendUser._();

  factory FriendUser.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FriendUser.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FriendUser',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'im'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'accountId')
    ..aOS(2, _omitFieldNames ? '' : 'nickname')
    ..aOS(3, _omitFieldNames ? '' : 'avatar')
    ..aOS(4, _omitFieldNames ? '' : 'signature')
    ..aOS(5, _omitFieldNames ? '' : 'flashId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FriendUser clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FriendUser copyWith(void Function(FriendUser) updates) =>
      super.copyWith((message) => updates(message as FriendUser)) as FriendUser;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FriendUser create() => FriendUser._();
  @$core.override
  FriendUser createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FriendUser getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FriendUser>(create);
  static FriendUser? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get accountId => $_getI64(0);
  @$pb.TagNumber(1)
  set accountId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get nickname => $_getSZ(1);
  @$pb.TagNumber(2)
  set nickname($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNickname() => $_has(1);
  @$pb.TagNumber(2)
  void clearNickname() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get avatar => $_getSZ(2);
  @$pb.TagNumber(3)
  set avatar($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAvatar() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvatar() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get signature => $_getSZ(3);
  @$pb.TagNumber(4)
  set signature($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSignature() => $_has(3);
  @$pb.TagNumber(4)
  void clearSignature() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get flashId => $_getSZ(4);
  @$pb.TagNumber(5)
  set flashId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFlashId() => $_has(4);
  @$pb.TagNumber(5)
  void clearFlashId() => $_clearField(5);
}

class FriendRequestEvent extends $pb.GeneratedMessage {
  factory FriendRequestEvent({
    $core.String? requestId,
    FriendUser? fromUser,
    $core.String? message,
    $core.String? createdAt,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (fromUser != null) result.fromUser = fromUser;
    if (message != null) result.message = message;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  FriendRequestEvent._();

  factory FriendRequestEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FriendRequestEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FriendRequestEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'im'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOM<FriendUser>(2, _omitFieldNames ? '' : 'fromUser',
        subBuilder: FriendUser.create)
    ..aOS(3, _omitFieldNames ? '' : 'message')
    ..aOS(4, _omitFieldNames ? '' : 'createdAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FriendRequestEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FriendRequestEvent copyWith(void Function(FriendRequestEvent) updates) =>
      super.copyWith((message) => updates(message as FriendRequestEvent))
          as FriendRequestEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FriendRequestEvent create() => FriendRequestEvent._();
  @$core.override
  FriendRequestEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FriendRequestEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FriendRequestEvent>(create);
  static FriendRequestEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  FriendUser get fromUser => $_getN(1);
  @$pb.TagNumber(2)
  set fromUser(FriendUser value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFromUser() => $_has(1);
  @$pb.TagNumber(2)
  void clearFromUser() => $_clearField(2);
  @$pb.TagNumber(2)
  FriendUser ensureFromUser() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get createdAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set createdAt($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCreatedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearCreatedAt() => $_clearField(4);
}

class FriendAcceptedEvent extends $pb.GeneratedMessage {
  factory FriendAcceptedEvent({
    $core.String? requestId,
    FriendUser? friend,
    $core.String? conversationId,
    $core.String? acceptedAt,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (friend != null) result.friend = friend;
    if (conversationId != null) result.conversationId = conversationId;
    if (acceptedAt != null) result.acceptedAt = acceptedAt;
    return result;
  }

  FriendAcceptedEvent._();

  factory FriendAcceptedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FriendAcceptedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FriendAcceptedEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'im'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOM<FriendUser>(2, _omitFieldNames ? '' : 'friend',
        subBuilder: FriendUser.create)
    ..aOS(3, _omitFieldNames ? '' : 'conversationId')
    ..aOS(4, _omitFieldNames ? '' : 'acceptedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FriendAcceptedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FriendAcceptedEvent copyWith(void Function(FriendAcceptedEvent) updates) =>
      super.copyWith((message) => updates(message as FriendAcceptedEvent))
          as FriendAcceptedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FriendAcceptedEvent create() => FriendAcceptedEvent._();
  @$core.override
  FriendAcceptedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FriendAcceptedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FriendAcceptedEvent>(create);
  static FriendAcceptedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  FriendUser get friend => $_getN(1);
  @$pb.TagNumber(2)
  set friend(FriendUser value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFriend() => $_has(1);
  @$pb.TagNumber(2)
  void clearFriend() => $_clearField(2);
  @$pb.TagNumber(2)
  FriendUser ensureFriend() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get conversationId => $_getSZ(2);
  @$pb.TagNumber(3)
  set conversationId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConversationId() => $_has(2);
  @$pb.TagNumber(3)
  void clearConversationId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get acceptedAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set acceptedAt($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAcceptedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearAcceptedAt() => $_clearField(4);
}

class FriendRemovedEvent extends $pb.GeneratedMessage {
  factory FriendRemovedEvent({
    FriendUser? friend,
    $core.String? removedAt,
  }) {
    final result = create();
    if (friend != null) result.friend = friend;
    if (removedAt != null) result.removedAt = removedAt;
    return result;
  }

  FriendRemovedEvent._();

  factory FriendRemovedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FriendRemovedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FriendRemovedEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'im'),
      createEmptyInstance: create)
    ..aOM<FriendUser>(1, _omitFieldNames ? '' : 'friend',
        subBuilder: FriendUser.create)
    ..aOS(2, _omitFieldNames ? '' : 'removedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FriendRemovedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FriendRemovedEvent copyWith(void Function(FriendRemovedEvent) updates) =>
      super.copyWith((message) => updates(message as FriendRemovedEvent))
          as FriendRemovedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FriendRemovedEvent create() => FriendRemovedEvent._();
  @$core.override
  FriendRemovedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FriendRemovedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FriendRemovedEvent>(create);
  static FriendRemovedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  FriendUser get friend => $_getN(0);
  @$pb.TagNumber(1)
  set friend(FriendUser value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFriend() => $_has(0);
  @$pb.TagNumber(1)
  void clearFriend() => $_clearField(1);
  @$pb.TagNumber(1)
  FriendUser ensureFriend() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get removedAt => $_getSZ(1);
  @$pb.TagNumber(2)
  set removedAt($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRemovedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearRemovedAt() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
