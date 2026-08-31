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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
