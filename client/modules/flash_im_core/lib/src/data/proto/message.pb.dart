// This is a generated file - do not edit.
//
// Generated from message.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:convert' as $convert;
import 'dart:core' as $core;

class ChatMessage {
  ChatMessage({
    this.id = '',
    this.conversationId = '',
    this.senderId = 0,
    this.seq = 0,
    this.type = 0,
    this.content = '',
    this.extra = '',
    this.status = 0,
    this.createdAt = '',
    this.senderName = '',
    this.senderAvatar = '',
  });

  factory ChatMessage.fromBuffer($core.List<$core.int> data) {
    final fields = _decodeFields(data);
    return ChatMessage(
      id: _string(fields[1]),
      conversationId: _string(fields[2]),
      senderId: _int(fields[3]),
      seq: _int(fields[4]),
      type: _int(fields[5]),
      content: _string(fields[6]),
      extra: _string(fields[7]),
      status: _int(fields[8]),
      createdAt: _string(fields[9]),
      senderName: _string(fields[10]),
      senderAvatar: _string(fields[11]),
    );
  }

  $core.String id;
  $core.String conversationId;
  $core.int senderId;
  $core.int seq;
  $core.int type;
  $core.String content;
  $core.String extra;
  $core.int status;
  $core.String createdAt;
  $core.String senderName;
  $core.String senderAvatar;

  $core.List<$core.int> writeToBuffer() {
    return [
      ..._fieldString(1, id),
      ..._fieldString(2, conversationId),
      ..._fieldVarint(3, senderId),
      ..._fieldVarint(4, seq),
      ..._fieldVarint(5, type),
      ..._fieldString(6, content),
      ..._fieldString(7, extra),
      ..._fieldVarint(8, status),
      ..._fieldString(9, createdAt),
      ..._fieldString(10, senderName),
      ..._fieldString(11, senderAvatar),
    ];
  }
}

class SendMessageRequest {
  SendMessageRequest({
    this.conversationId = '',
    this.type = 0,
    this.content = '',
    this.extra = '',
    this.clientId = '',
  });

  factory SendMessageRequest.fromBuffer($core.List<$core.int> data) {
    final fields = _decodeFields(data);
    return SendMessageRequest(
      conversationId: _string(fields[1]),
      type: _int(fields[2]),
      content: _string(fields[3]),
      extra: _string(fields[4]),
      clientId: _string(fields[5]),
    );
  }

  $core.String conversationId;
  $core.int type;
  $core.String content;
  $core.String extra;
  $core.String clientId;

  $core.List<$core.int> writeToBuffer() {
    return [
      ..._fieldString(1, conversationId),
      ..._fieldVarint(2, type),
      ..._fieldString(3, content),
      ..._fieldString(4, extra),
      ..._fieldString(5, clientId),
    ];
  }
}

class MessageAck {
  MessageAck({this.messageId = '', this.seq = 0});

  factory MessageAck.fromBuffer($core.List<$core.int> data) {
    final fields = _decodeFields(data);
    return MessageAck(messageId: _string(fields[1]), seq: _int(fields[2]));
  }

  $core.String messageId;
  $core.int seq;

  $core.List<$core.int> writeToBuffer() {
    return [..._fieldString(1, messageId), ..._fieldVarint(2, seq)];
  }
}

class ConversationUpdate {
  ConversationUpdate({
    this.conversationId = '',
    this.lastMessagePreview = '',
    this.lastMessageAt = '',
    this.unreadCount = 0,
    this.totalUnread = 0,
  });

  factory ConversationUpdate.fromBuffer($core.List<$core.int> data) {
    final fields = _decodeFields(data);
    return ConversationUpdate(
      conversationId: _string(fields[1]),
      lastMessagePreview: _string(fields[2]),
      lastMessageAt: _string(fields[3]),
      unreadCount: _int(fields[4]),
      totalUnread: _int(fields[5]),
    );
  }

  $core.String conversationId;
  $core.String lastMessagePreview;
  $core.String lastMessageAt;
  $core.int unreadCount;
  $core.int totalUnread;

  $core.List<$core.int> writeToBuffer() {
    return [
      ..._fieldString(1, conversationId),
      ..._fieldString(2, lastMessagePreview),
      ..._fieldString(3, lastMessageAt),
      ..._fieldVarint(4, unreadCount),
      ..._fieldVarint(5, totalUnread),
    ];
  }
}

$core.Map<$core.int, $core.Object> _decodeFields($core.List<$core.int> data) {
  final fields = <$core.int, $core.Object>{};
  var index = 0;
  while (index < data.length) {
    final keyResult = _readVarint(data, index);
    final key = keyResult.value;
    index = keyResult.nextIndex;
    final field = key >> 3;
    final wireType = key & 0x7;
    if (wireType == 0) {
      final valueResult = _readVarint(data, index);
      fields[field] = valueResult.value;
      index = valueResult.nextIndex;
    } else if (wireType == 2) {
      final lengthResult = _readVarint(data, index);
      final length = lengthResult.value;
      index = lengthResult.nextIndex;
      final bytes = data.sublist(index, index + length);
      fields[field] = bytes;
      index += length;
    } else {
      throw $core.FormatException('Unsupported protobuf wire type: $wireType');
    }
  }
  return fields;
}

_VarintRead _readVarint($core.List<$core.int> data, $core.int index) {
  var shift = 0;
  var value = 0;
  while (index < data.length) {
    final byte = data[index];
    index += 1;
    value |= (byte & 0x7f) << shift;
    if (byte < 0x80) {
      return _VarintRead(value, index);
    }
    shift += 7;
  }
  throw const $core.FormatException('Truncated protobuf varint.');
}

$core.List<$core.int> _fieldVarint($core.int field, $core.int value) {
  if (value == 0) {
    return const [];
  }
  return [..._writeVarint(field << 3), ..._writeVarint(value)];
}

$core.List<$core.int> _fieldString($core.int field, $core.String value) {
  if (value.isEmpty) {
    return const [];
  }
  final bytes = $convert.utf8.encode(value);
  return [
    ..._writeVarint((field << 3) | 2),
    ..._writeVarint(bytes.length),
    ...bytes
  ];
}

$core.List<$core.int> _writeVarint($core.int value) {
  final bytes = <$core.int>[];
  var current = value;
  while (current > 0x7f) {
    bytes.add((current & 0x7f) | 0x80);
    current >>= 7;
  }
  bytes.add(current);
  return bytes;
}

$core.String _string($core.Object? value) {
  if (value is $core.List<$core.int>) {
    return $convert.utf8.decode(value);
  }
  return '';
}

$core.int _int($core.Object? value) => value is $core.int ? value : 0;

class _VarintRead {
  const _VarintRead(this.value, this.nextIndex);

  final $core.int value;
  final $core.int nextIndex;
}
