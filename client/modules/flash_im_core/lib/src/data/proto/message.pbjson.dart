// This is a generated file - do not edit.
//
// Generated from message.proto.

// @dart = 3.3

// ignore_for_file: constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use chatMessageDescriptor instead')
const ChatMessage$json = {
  '1': 'ChatMessage',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'conversation_id', '3': 2, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'sender_id', '3': 3, '4': 1, '5': 3, '10': 'senderId'},
    {'1': 'seq', '3': 4, '4': 1, '5': 3, '10': 'seq'},
    {'1': 'type', '3': 5, '4': 1, '5': 5, '10': 'type'},
    {'1': 'content', '3': 6, '4': 1, '5': 9, '10': 'content'},
    {'1': 'extra', '3': 7, '4': 1, '5': 9, '10': 'extra'},
    {'1': 'status', '3': 8, '4': 1, '5': 5, '10': 'status'},
    {'1': 'created_at', '3': 9, '4': 1, '5': 9, '10': 'createdAt'},
    {'1': 'sender_name', '3': 10, '4': 1, '5': 9, '10': 'senderName'},
    {'1': 'sender_avatar', '3': 11, '4': 1, '5': 9, '10': 'senderAvatar'},
  ],
};

final $typed_data.Uint8List chatMessageDescriptor = $convert.base64Decode('');

@$core.Deprecated('Use sendMessageRequestDescriptor instead')
const SendMessageRequest$json = {
  '1': 'SendMessageRequest',
};

final $typed_data.Uint8List sendMessageRequestDescriptor =
    $convert.base64Decode('');

@$core.Deprecated('Use messageAckDescriptor instead')
const MessageAck$json = {
  '1': 'MessageAck',
};

final $typed_data.Uint8List messageAckDescriptor = $convert.base64Decode('');

@$core.Deprecated('Use conversationUpdateDescriptor instead')
const ConversationUpdate$json = {
  '1': 'ConversationUpdate',
};

final $typed_data.Uint8List conversationUpdateDescriptor =
    $convert.base64Decode('');
