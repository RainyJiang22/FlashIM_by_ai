// This is a generated file - do not edit.
//
// Generated from ws.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class WsFrameType extends $pb.ProtobufEnum {
  static const WsFrameType PING =
      WsFrameType._(0, _omitEnumNames ? '' : 'PING');
  static const WsFrameType PONG =
      WsFrameType._(1, _omitEnumNames ? '' : 'PONG');
  static const WsFrameType AUTH =
      WsFrameType._(2, _omitEnumNames ? '' : 'AUTH');
  static const WsFrameType AUTH_RESULT =
      WsFrameType._(3, _omitEnumNames ? '' : 'AUTH_RESULT');
  static const WsFrameType CHAT_MESSAGE =
      WsFrameType._(4, _omitEnumNames ? '' : 'CHAT_MESSAGE');
  static const WsFrameType MESSAGE_ACK =
      WsFrameType._(5, _omitEnumNames ? '' : 'MESSAGE_ACK');
  static const WsFrameType CONVERSATION_UPDATE =
      WsFrameType._(6, _omitEnumNames ? '' : 'CONVERSATION_UPDATE');
  static const WsFrameType FRIEND_REQUEST =
      WsFrameType._(7, _omitEnumNames ? '' : 'FRIEND_REQUEST');
  static const WsFrameType FRIEND_ACCEPTED =
      WsFrameType._(8, _omitEnumNames ? '' : 'FRIEND_ACCEPTED');
  static const WsFrameType FRIEND_REMOVED =
      WsFrameType._(9, _omitEnumNames ? '' : 'FRIEND_REMOVED');
  static const WsFrameType GROUP_JOIN_REQUEST =
      WsFrameType._(10, _omitEnumNames ? '' : 'GROUP_JOIN_REQUEST');

  static const $core.List<WsFrameType> values = <WsFrameType>[
    PING,
    PONG,
    AUTH,
    AUTH_RESULT,
    CHAT_MESSAGE,
    MESSAGE_ACK,
    CONVERSATION_UPDATE,
    FRIEND_REQUEST,
    FRIEND_ACCEPTED,
    FRIEND_REMOVED,
    GROUP_JOIN_REQUEST,
  ];

  static final $core.List<WsFrameType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 10);
  static WsFrameType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WsFrameType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
