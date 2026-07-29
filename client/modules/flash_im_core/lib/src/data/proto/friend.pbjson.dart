// This is a generated file - do not edit.
//
// Generated from friend.proto.

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

@$core.Deprecated('Use friendUserDescriptor instead')
const FriendUser$json = {
  '1': 'FriendUser',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 3, '10': 'accountId'},
    {'1': 'nickname', '3': 2, '4': 1, '5': 9, '10': 'nickname'},
    {'1': 'avatar', '3': 3, '4': 1, '5': 9, '10': 'avatar'},
    {'1': 'signature', '3': 4, '4': 1, '5': 9, '10': 'signature'},
    {'1': 'flash_id', '3': 5, '4': 1, '5': 9, '10': 'flashId'},
  ],
};

/// Descriptor for `FriendUser`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List friendUserDescriptor = $convert.base64Decode(
    'CgpGcmllbmRVc2VyEh0KCmFjY291bnRfaWQYASABKANSCWFjY291bnRJZBIaCghuaWNrbmFtZR'
    'gCIAEoCVIIbmlja25hbWUSFgoGYXZhdGFyGAMgASgJUgZhdmF0YXISHAoJc2lnbmF0dXJlGAQg'
    'ASgJUglzaWduYXR1cmUSGQoIZmxhc2hfaWQYBSABKAlSB2ZsYXNoSWQ=');

@$core.Deprecated('Use friendRequestEventDescriptor instead')
const FriendRequestEvent$json = {
  '1': 'FriendRequestEvent',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {
      '1': 'from_user',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.im.FriendUser',
      '10': 'fromUser'
    },
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
    {'1': 'created_at', '3': 4, '4': 1, '5': 9, '10': 'createdAt'},
  ],
};

/// Descriptor for `FriendRequestEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List friendRequestEventDescriptor = $convert.base64Decode(
    'ChJGcmllbmRSZXF1ZXN0RXZlbnQSHQoKcmVxdWVzdF9pZBgBIAEoCVIJcmVxdWVzdElkEisKCW'
    'Zyb21fdXNlchgCIAEoCzIOLmltLkZyaWVuZFVzZXJSCGZyb21Vc2VyEhgKB21lc3NhZ2UYAyAB'
    'KAlSB21lc3NhZ2USHQoKY3JlYXRlZF9hdBgEIAEoCVIJY3JlYXRlZEF0');

@$core.Deprecated('Use friendAcceptedEventDescriptor instead')
const FriendAcceptedEvent$json = {
  '1': 'FriendAcceptedEvent',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {
      '1': 'friend',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.im.FriendUser',
      '10': 'friend'
    },
    {'1': 'conversation_id', '3': 3, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'accepted_at', '3': 4, '4': 1, '5': 9, '10': 'acceptedAt'},
  ],
};

/// Descriptor for `FriendAcceptedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List friendAcceptedEventDescriptor = $convert.base64Decode(
    'ChNGcmllbmRBY2NlcHRlZEV2ZW50Eh0KCnJlcXVlc3RfaWQYASABKAlSCXJlcXVlc3RJZBImCg'
    'ZmcmllbmQYAiABKAsyDi5pbS5GcmllbmRVc2VyUgZmcmllbmQSJwoPY29udmVyc2F0aW9uX2lk'
    'GAMgASgJUg5jb252ZXJzYXRpb25JZBIfCgthY2NlcHRlZF9hdBgEIAEoCVIKYWNjZXB0ZWRBdA'
    '==');

@$core.Deprecated('Use friendRemovedEventDescriptor instead')
const FriendRemovedEvent$json = {
  '1': 'FriendRemovedEvent',
  '2': [
    {
      '1': 'friend',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.im.FriendUser',
      '10': 'friend'
    },
    {'1': 'removed_at', '3': 2, '4': 1, '5': 9, '10': 'removedAt'},
  ],
};

/// Descriptor for `FriendRemovedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List friendRemovedEventDescriptor = $convert.base64Decode(
    'ChJGcmllbmRSZW1vdmVkRXZlbnQSJgoGZnJpZW5kGAEgASgLMg4uaW0uRnJpZW5kVXNlclIGZn'
    'JpZW5kEh0KCnJlbW92ZWRfYXQYAiABKAlSCXJlbW92ZWRBdA==');
