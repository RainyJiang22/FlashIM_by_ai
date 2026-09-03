// This is a generated file - do not edit.
//
// Generated from presence.proto.

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

@$core.Deprecated('Use userPresenceEventDescriptor instead')
const UserPresenceEvent$json = {
  '1': 'UserPresenceEvent',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 3, '10': 'userId'},
  ],
};

/// Descriptor for `UserPresenceEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userPresenceEventDescriptor = $convert.base64Decode(
    'ChFVc2VyUHJlc2VuY2VFdmVudBIXCgd1c2VyX2lkGAEgASgDUgZ1c2VySWQ=');

@$core.Deprecated('Use onlineUserListDescriptor instead')
const OnlineUserList$json = {
  '1': 'OnlineUserList',
  '2': [
    {'1': 'user_ids', '3': 1, '4': 3, '5': 3, '10': 'userIds'},
  ],
};

/// Descriptor for `OnlineUserList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List onlineUserListDescriptor = $convert.base64Decode(
    'Cg5PbmxpbmVVc2VyTGlzdBIZCgh1c2VyX2lkcxgBIAMoA1IHdXNlcklkcw==');
