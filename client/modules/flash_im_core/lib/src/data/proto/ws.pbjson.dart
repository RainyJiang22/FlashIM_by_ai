// This is a generated file - do not edit.
//
// Generated from ws.proto.

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

@$core.Deprecated('Use wsFrameTypeDescriptor instead')
const WsFrameType$json = {
  '1': 'WsFrameType',
  '2': [
    {'1': 'PING', '2': 0},
    {'1': 'PONG', '2': 1},
    {'1': 'AUTH', '2': 2},
    {'1': 'AUTH_RESULT', '2': 3},
  ],
};

/// Descriptor for `WsFrameType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List wsFrameTypeDescriptor = $convert.base64Decode(
    'CgtXc0ZyYW1lVHlwZRIICgRQSU5HEAASCAoEUE9ORxABEggKBEFVVEgQAhIPCgtBVVRIX1JFU1'
    'VMVBAD');

@$core.Deprecated('Use wsFrameDescriptor instead')
const WsFrame$json = {
  '1': 'WsFrame',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.im.WsFrameType',
      '10': 'type'
    },
    {'1': 'payload', '3': 2, '4': 1, '5': 12, '10': 'payload'},
  ],
};

/// Descriptor for `WsFrame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wsFrameDescriptor = $convert.base64Decode(
    'CgdXc0ZyYW1lEiMKBHR5cGUYASABKA4yDy5pbS5Xc0ZyYW1lVHlwZVIEdHlwZRIYCgdwYXlsb2'
    'FkGAIgASgMUgdwYXlsb2Fk');

@$core.Deprecated('Use authRequestDescriptor instead')
const AuthRequest$json = {
  '1': 'AuthRequest',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `AuthRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List authRequestDescriptor =
    $convert.base64Decode('CgtBdXRoUmVxdWVzdBIUCgV0b2tlbhgBIAEoCVIFdG9rZW4=');

@$core.Deprecated('Use authResultDescriptor instead')
const AuthResult$json = {
  '1': 'AuthResult',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `AuthResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List authResultDescriptor = $convert.base64Decode(
    'CgpBdXRoUmVzdWx0EhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGAoHbWVzc2FnZRgCIAEoCV'
    'IHbWVzc2FnZQ==');
