// This is a generated file - do not edit.
//
// Generated from group.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use groupJoinRequestNotificationDescriptor instead')
const GroupJoinRequestNotification$json = {
  '1': 'GroupJoinRequestNotification',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'conversation_id', '3': 2, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'group_name', '3': 3, '4': 1, '5': 9, '10': 'groupName'},
    {'1': 'group_avatar', '3': 4, '4': 1, '5': 9, '10': 'groupAvatar'},
    {'1': 'applicant_id', '3': 5, '4': 1, '5': 3, '10': 'applicantId'},
    {'1': 'applicant_name', '3': 6, '4': 1, '5': 9, '10': 'applicantName'},
    {'1': 'applicant_avatar', '3': 7, '4': 1, '5': 9, '10': 'applicantAvatar'},
    {'1': 'message', '3': 8, '4': 1, '5': 9, '10': 'message'},
    {'1': 'status', '3': 9, '4': 1, '5': 5, '10': 'status'},
    {'1': 'created_at', '3': 10, '4': 1, '5': 9, '10': 'createdAt'},
    {'1': 'handled_at', '3': 11, '4': 1, '5': 9, '10': 'handledAt'},
  ],
};

/// Descriptor for `GroupJoinRequestNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List groupJoinRequestNotificationDescriptor = $convert.base64Decode(
    'ChxHcm91cEpvaW5SZXF1ZXN0Tm90aWZpY2F0aW9uEh0KCnJlcXVlc3RfaWQYASABKAlSCXJlcX'
    'Vlc3RJZBInCg9jb252ZXJzYXRpb25faWQYAiABKAlSDmNvbnZlcnNhdGlvbklkEh0KCmdyb3Vw'
    'X25hbWUYAyABKAlSCWdyb3VwTmFtZRIhCgxncm91cF9hdmF0YXIYBCABKAlSC2dyb3VwQXZhdG'
    'FyEiEKDGFwcGxpY2FudF9pZBgFIAEoA1ILYXBwbGljYW50SWQSJQoOYXBwbGljYW50X25hbWUY'
    'BiABKAlSDWFwcGxpY2FudE5hbWUSKQoQYXBwbGljYW50X2F2YXRhchgHIAEoCVIPYXBwbGljYW'
    '50QXZhdGFyEhgKB21lc3NhZ2UYCCABKAlSB21lc3NhZ2USFgoGc3RhdHVzGAkgASgFUgZzdGF0'
    'dXMSHQoKY3JlYXRlZF9hdBgKIAEoCVIJY3JlYXRlZEF0Eh0KCmhhbmRsZWRfYXQYCyABKAlSCW'
    'hhbmRsZWRBdA==');

@$core.Deprecated('Use groupInfoUpdateNotificationDescriptor instead')
const GroupInfoUpdateNotification$json = {
  '1': 'GroupInfoUpdateNotification',
  '2': [
    {'1': 'conversation_id', '3': 1, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'avatar', '3': 3, '4': 1, '5': 9, '10': 'avatar'},
    {'1': 'owner_id', '3': 4, '4': 1, '5': 3, '10': 'ownerId'},
    {'1': 'member_count', '3': 5, '4': 1, '5': 5, '10': 'memberCount'},
    {'1': 'announcement', '3': 6, '4': 1, '5': 9, '10': 'announcement'},
    {
      '1': 'announcement_updated_at',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'announcementUpdatedAt'
    },
    {
      '1': 'announcement_updated_by',
      '3': 8,
      '4': 1,
      '5': 3,
      '10': 'announcementUpdatedBy'
    },
    {'1': 'is_dissolved', '3': 9, '4': 1, '5': 8, '10': 'isDissolved'},
    {
      '1': 'membership_active',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'membershipActive'
    },
    {
      '1': 'current_user_role',
      '3': 11,
      '4': 1,
      '5': 9,
      '10': 'currentUserRole'
    },
    {'1': 'change_type', '3': 12, '4': 1, '5': 9, '10': 'changeType'},
  ],
};

/// Descriptor for `GroupInfoUpdateNotification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List groupInfoUpdateNotificationDescriptor = $convert.base64Decode(
    'ChtHcm91cEluZm9VcGRhdGVOb3RpZmljYXRpb24SJwoPY29udmVyc2F0aW9uX2lkGAEgASgJUg'
    '5jb252ZXJzYXRpb25JZBISCgRuYW1lGAIgASgJUgRuYW1lEhYKBmF2YXRhchgDIAEoCVIGYXZh'
    'dGFyEhkKCG93bmVyX2lkGAQgASgDUgdvd25lcklkEiEKDG1lbWJlcl9jb3VudBgFIAEoBVILbW'
    'VtYmVyQ291bnQSIgoMYW5ub3VuY2VtZW50GAYgASgJUgxhbm5vdW5jZW1lbnQSNgoXYW5ub3Vu'
    'Y2VtZW50X3VwZGF0ZWRfYXQYByABKAlSFWFubm91bmNlbWVudFVwZGF0ZWRBdBI2Chdhbm5vdW'
    '5jZW1lbnRfdXBkYXRlZF9ieRgIIAEoA1IVYW5ub3VuY2VtZW50VXBkYXRlZEJ5EiEKDGlzX2Rp'
    'c3NvbHZlZBgJIAEoCFILaXNEaXNzb2x2ZWQSKwoRbWVtYmVyc2hpcF9hY3RpdmUYCiABKAhSEG'
    '1lbWJlcnNoaXBBY3RpdmUSKgoRY3VycmVudF91c2VyX3JvbGUYCyABKAlSD2N1cnJlbnRVc2Vy'
    'Um9sZRIfCgtjaGFuZ2VfdHlwZRgMIAEoCVIKY2hhbmdlVHlwZQ==');
