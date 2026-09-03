// This is a generated file - do not edit.
//
// Generated from message.proto.

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

@$core.Deprecated('Use messageTypeDescriptor instead')
const MessageType$json = {
  '1': 'MessageType',
  '2': [
    {'1': 'TEXT', '2': 0},
    {'1': 'IMAGE', '2': 1},
    {'1': 'VIDEO', '2': 2},
    {'1': 'FILE', '2': 3},
    {'1': 'GROUP_INVITATION', '2': 4},
  ],
};

/// Descriptor for `MessageType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List messageTypeDescriptor = $convert.base64Decode(
    'CgtNZXNzYWdlVHlwZRIICgRURVhUEAASCQoFSU1BR0UQARIJCgVWSURFTxACEggKBEZJTEUQAx'
    'IUChBHUk9VUF9JTlZJVEFUSU9OEAQ=');

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
    {'1': 'read_count', '3': 12, '4': 1, '5': 5, '10': 'readCount'},
  ],
};

/// Descriptor for `ChatMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatMessageDescriptor = $convert.base64Decode(
    'CgtDaGF0TWVzc2FnZRIOCgJpZBgBIAEoCVICaWQSJwoPY29udmVyc2F0aW9uX2lkGAIgASgJUg'
    '5jb252ZXJzYXRpb25JZBIbCglzZW5kZXJfaWQYAyABKANSCHNlbmRlcklkEhAKA3NlcRgEIAEo'
    'A1IDc2VxEhIKBHR5cGUYBSABKAVSBHR5cGUSGAoHY29udGVudBgGIAEoCVIHY29udGVudBIUCg'
    'VleHRyYRgHIAEoCVIFZXh0cmESFgoGc3RhdHVzGAggASgFUgZzdGF0dXMSHQoKY3JlYXRlZF9h'
    'dBgJIAEoCVIJY3JlYXRlZEF0Eh8KC3NlbmRlcl9uYW1lGAogASgJUgpzZW5kZXJOYW1lEiMKDX'
    'NlbmRlcl9hdmF0YXIYCyABKAlSDHNlbmRlckF2YXRhchIdCgpyZWFkX2NvdW50GAwgASgFUgly'
    'ZWFkQ291bnQ=');

@$core.Deprecated('Use sendMessageRequestDescriptor instead')
const SendMessageRequest$json = {
  '1': 'SendMessageRequest',
  '2': [
    {'1': 'conversation_id', '3': 1, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'type', '3': 2, '4': 1, '5': 5, '10': 'type'},
    {'1': 'content', '3': 3, '4': 1, '5': 9, '10': 'content'},
    {'1': 'extra', '3': 4, '4': 1, '5': 9, '10': 'extra'},
    {'1': 'client_id', '3': 5, '4': 1, '5': 9, '10': 'clientId'},
  ],
};

/// Descriptor for `SendMessageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendMessageRequestDescriptor = $convert.base64Decode(
    'ChJTZW5kTWVzc2FnZVJlcXVlc3QSJwoPY29udmVyc2F0aW9uX2lkGAEgASgJUg5jb252ZXJzYX'
    'Rpb25JZBISCgR0eXBlGAIgASgFUgR0eXBlEhgKB2NvbnRlbnQYAyABKAlSB2NvbnRlbnQSFAoF'
    'ZXh0cmEYBCABKAlSBWV4dHJhEhsKCWNsaWVudF9pZBgFIAEoCVIIY2xpZW50SWQ=');

@$core.Deprecated('Use messageAckDescriptor instead')
const MessageAck$json = {
  '1': 'MessageAck',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'seq', '3': 2, '4': 1, '5': 3, '10': 'seq'},
  ],
};

/// Descriptor for `MessageAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageAckDescriptor = $convert.base64Decode(
    'CgpNZXNzYWdlQWNrEh0KCm1lc3NhZ2VfaWQYASABKAlSCW1lc3NhZ2VJZBIQCgNzZXEYAiABKA'
    'NSA3NlcQ==');

@$core.Deprecated('Use conversationUpdateDescriptor instead')
const ConversationUpdate$json = {
  '1': 'ConversationUpdate',
  '2': [
    {'1': 'conversation_id', '3': 1, '4': 1, '5': 9, '10': 'conversationId'},
    {
      '1': 'last_message_preview',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'lastMessagePreview'
    },
    {'1': 'last_message_at', '3': 3, '4': 1, '5': 9, '10': 'lastMessageAt'},
    {'1': 'unread_count', '3': 4, '4': 1, '5': 5, '10': 'unreadCount'},
    {'1': 'total_unread', '3': 5, '4': 1, '5': 5, '10': 'totalUnread'},
  ],
};

/// Descriptor for `ConversationUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List conversationUpdateDescriptor = $convert.base64Decode(
    'ChJDb252ZXJzYXRpb25VcGRhdGUSJwoPY29udmVyc2F0aW9uX2lkGAEgASgJUg5jb252ZXJzYX'
    'Rpb25JZBIwChRsYXN0X21lc3NhZ2VfcHJldmlldxgCIAEoCVISbGFzdE1lc3NhZ2VQcmV2aWV3'
    'EiYKD2xhc3RfbWVzc2FnZV9hdBgDIAEoCVINbGFzdE1lc3NhZ2VBdBIhCgx1bnJlYWRfY291bn'
    'QYBCABKAVSC3VucmVhZENvdW50EiEKDHRvdGFsX3VucmVhZBgFIAEoBVILdG90YWxVbnJlYWQ=');

@$core.Deprecated('Use readReceiptDescriptor instead')
const ReadReceipt$json = {
  '1': 'ReadReceipt',
  '2': [
    {'1': 'conversation_id', '3': 1, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'reader_id', '3': 2, '4': 1, '5': 3, '10': 'readerId'},
    {'1': 'previous_read_seq', '3': 3, '4': 1, '5': 3, '10': 'previousReadSeq'},
    {'1': 'read_seq', '3': 4, '4': 1, '5': 3, '10': 'readSeq'},
  ],
};

/// Descriptor for `ReadReceipt`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List readReceiptDescriptor = $convert.base64Decode(
    'CgtSZWFkUmVjZWlwdBInCg9jb252ZXJzYXRpb25faWQYASABKAlSDmNvbnZlcnNhdGlvbklkEh'
    'sKCXJlYWRlcl9pZBgCIAEoA1IIcmVhZGVySWQSKgoRcHJldmlvdXNfcmVhZF9zZXEYAyABKANS'
    'D3ByZXZpb3VzUmVhZFNlcRIZCghyZWFkX3NlcRgEIAEoA1IHcmVhZFNlcQ==');
