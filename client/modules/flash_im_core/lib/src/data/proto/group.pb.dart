// This is a generated file - do not edit.
//
// Generated from group.proto.

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

class GroupJoinRequestNotification extends $pb.GeneratedMessage {
  factory GroupJoinRequestNotification({
    $core.String? requestId,
    $core.String? conversationId,
    $core.String? groupName,
    $core.String? groupAvatar,
    $fixnum.Int64? applicantId,
    $core.String? applicantName,
    $core.String? applicantAvatar,
    $core.String? message,
    $core.int? status,
    $core.String? createdAt,
    $core.String? handledAt,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (conversationId != null) result.conversationId = conversationId;
    if (groupName != null) result.groupName = groupName;
    if (groupAvatar != null) result.groupAvatar = groupAvatar;
    if (applicantId != null) result.applicantId = applicantId;
    if (applicantName != null) result.applicantName = applicantName;
    if (applicantAvatar != null) result.applicantAvatar = applicantAvatar;
    if (message != null) result.message = message;
    if (status != null) result.status = status;
    if (createdAt != null) result.createdAt = createdAt;
    if (handledAt != null) result.handledAt = handledAt;
    return result;
  }

  GroupJoinRequestNotification._();

  factory GroupJoinRequestNotification.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GroupJoinRequestNotification.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GroupJoinRequestNotification',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'im'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'conversationId')
    ..aOS(3, _omitFieldNames ? '' : 'groupName')
    ..aOS(4, _omitFieldNames ? '' : 'groupAvatar')
    ..aInt64(5, _omitFieldNames ? '' : 'applicantId')
    ..aOS(6, _omitFieldNames ? '' : 'applicantName')
    ..aOS(7, _omitFieldNames ? '' : 'applicantAvatar')
    ..aOS(8, _omitFieldNames ? '' : 'message')
    ..aI(9, _omitFieldNames ? '' : 'status')
    ..aOS(10, _omitFieldNames ? '' : 'createdAt')
    ..aOS(11, _omitFieldNames ? '' : 'handledAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupJoinRequestNotification clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupJoinRequestNotification copyWith(
          void Function(GroupJoinRequestNotification) updates) =>
      super.copyWith(
              (message) => updates(message as GroupJoinRequestNotification))
          as GroupJoinRequestNotification;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GroupJoinRequestNotification create() =>
      GroupJoinRequestNotification._();
  @$core.override
  GroupJoinRequestNotification createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GroupJoinRequestNotification getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GroupJoinRequestNotification>(create);
  static GroupJoinRequestNotification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get conversationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set conversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConversationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConversationId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get groupName => $_getSZ(2);
  @$pb.TagNumber(3)
  set groupName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGroupName() => $_has(2);
  @$pb.TagNumber(3)
  void clearGroupName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get groupAvatar => $_getSZ(3);
  @$pb.TagNumber(4)
  set groupAvatar($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGroupAvatar() => $_has(3);
  @$pb.TagNumber(4)
  void clearGroupAvatar() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get applicantId => $_getI64(4);
  @$pb.TagNumber(5)
  set applicantId($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasApplicantId() => $_has(4);
  @$pb.TagNumber(5)
  void clearApplicantId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get applicantName => $_getSZ(5);
  @$pb.TagNumber(6)
  set applicantName($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasApplicantName() => $_has(5);
  @$pb.TagNumber(6)
  void clearApplicantName() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get applicantAvatar => $_getSZ(6);
  @$pb.TagNumber(7)
  set applicantAvatar($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasApplicantAvatar() => $_has(6);
  @$pb.TagNumber(7)
  void clearApplicantAvatar() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get message => $_getSZ(7);
  @$pb.TagNumber(8)
  set message($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMessage() => $_has(7);
  @$pb.TagNumber(8)
  void clearMessage() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get status => $_getIZ(8);
  @$pb.TagNumber(9)
  set status($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasStatus() => $_has(8);
  @$pb.TagNumber(9)
  void clearStatus() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get createdAt => $_getSZ(9);
  @$pb.TagNumber(10)
  set createdAt($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCreatedAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearCreatedAt() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get handledAt => $_getSZ(10);
  @$pb.TagNumber(11)
  set handledAt($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasHandledAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearHandledAt() => $_clearField(11);
}

class GroupInfoUpdateNotification extends $pb.GeneratedMessage {
  factory GroupInfoUpdateNotification({
    $core.String? conversationId,
    $core.String? name,
    $core.String? avatar,
    $fixnum.Int64? ownerId,
    $core.int? memberCount,
    $core.String? announcement,
    $core.String? announcementUpdatedAt,
    $fixnum.Int64? announcementUpdatedBy,
    $core.bool? isDissolved,
    $core.bool? membershipActive,
    $core.String? currentUserRole,
    $core.String? changeType,
  }) {
    final result = create();
    if (conversationId != null) result.conversationId = conversationId;
    if (name != null) result.name = name;
    if (avatar != null) result.avatar = avatar;
    if (ownerId != null) result.ownerId = ownerId;
    if (memberCount != null) result.memberCount = memberCount;
    if (announcement != null) result.announcement = announcement;
    if (announcementUpdatedAt != null)
      result.announcementUpdatedAt = announcementUpdatedAt;
    if (announcementUpdatedBy != null)
      result.announcementUpdatedBy = announcementUpdatedBy;
    if (isDissolved != null) result.isDissolved = isDissolved;
    if (membershipActive != null) result.membershipActive = membershipActive;
    if (currentUserRole != null) result.currentUserRole = currentUserRole;
    if (changeType != null) result.changeType = changeType;
    return result;
  }

  GroupInfoUpdateNotification._();

  factory GroupInfoUpdateNotification.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GroupInfoUpdateNotification.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GroupInfoUpdateNotification',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'im'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'conversationId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'avatar')
    ..aInt64(4, _omitFieldNames ? '' : 'ownerId')
    ..aI(5, _omitFieldNames ? '' : 'memberCount')
    ..aOS(6, _omitFieldNames ? '' : 'announcement')
    ..aOS(7, _omitFieldNames ? '' : 'announcementUpdatedAt')
    ..aInt64(8, _omitFieldNames ? '' : 'announcementUpdatedBy')
    ..aOB(9, _omitFieldNames ? '' : 'isDissolved')
    ..aOB(10, _omitFieldNames ? '' : 'membershipActive')
    ..aOS(11, _omitFieldNames ? '' : 'currentUserRole')
    ..aOS(12, _omitFieldNames ? '' : 'changeType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupInfoUpdateNotification clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupInfoUpdateNotification copyWith(
          void Function(GroupInfoUpdateNotification) updates) =>
      super.copyWith(
              (message) => updates(message as GroupInfoUpdateNotification))
          as GroupInfoUpdateNotification;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GroupInfoUpdateNotification create() =>
      GroupInfoUpdateNotification._();
  @$core.override
  GroupInfoUpdateNotification createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GroupInfoUpdateNotification getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GroupInfoUpdateNotification>(create);
  static GroupInfoUpdateNotification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get conversationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set conversationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConversationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearConversationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get avatar => $_getSZ(2);
  @$pb.TagNumber(3)
  set avatar($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAvatar() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvatar() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get ownerId => $_getI64(3);
  @$pb.TagNumber(4)
  set ownerId($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOwnerId() => $_has(3);
  @$pb.TagNumber(4)
  void clearOwnerId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get memberCount => $_getIZ(4);
  @$pb.TagNumber(5)
  set memberCount($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMemberCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearMemberCount() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get announcement => $_getSZ(5);
  @$pb.TagNumber(6)
  set announcement($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAnnouncement() => $_has(5);
  @$pb.TagNumber(6)
  void clearAnnouncement() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get announcementUpdatedAt => $_getSZ(6);
  @$pb.TagNumber(7)
  set announcementUpdatedAt($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAnnouncementUpdatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearAnnouncementUpdatedAt() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get announcementUpdatedBy => $_getI64(7);
  @$pb.TagNumber(8)
  set announcementUpdatedBy($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAnnouncementUpdatedBy() => $_has(7);
  @$pb.TagNumber(8)
  void clearAnnouncementUpdatedBy() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get isDissolved => $_getBF(8);
  @$pb.TagNumber(9)
  set isDissolved($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIsDissolved() => $_has(8);
  @$pb.TagNumber(9)
  void clearIsDissolved() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get membershipActive => $_getBF(9);
  @$pb.TagNumber(10)
  set membershipActive($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasMembershipActive() => $_has(9);
  @$pb.TagNumber(10)
  void clearMembershipActive() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get currentUserRole => $_getSZ(10);
  @$pb.TagNumber(11)
  set currentUserRole($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasCurrentUserRole() => $_has(10);
  @$pb.TagNumber(11)
  void clearCurrentUserRole() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get changeType => $_getSZ(11);
  @$pb.TagNumber(12)
  set changeType($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasChangeType() => $_has(11);
  @$pb.TagNumber(12)
  void clearChangeType() => $_clearField(12);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
