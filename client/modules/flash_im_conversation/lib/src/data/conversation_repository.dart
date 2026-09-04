import 'package:dio/dio.dart';

import 'conversation.dart';

abstract interface class ConversationRepository {
  Future<List<Conversation>> getList({
    int limit = 20,
    int offset = 0,
    int? type,
  });

  Future<Conversation> getById(String id);

  Future<Conversation> getPrivateByPeerId(int peerUserId);

  Future<Conversation> createGroup({
    required String name,
    required List<int> memberIds,
  });

  Future<void> markRead(String id);

  Future<void> hideFromList(String id);
}

class ConversationRequestException implements Exception {
  const ConversationRequestException([this.serverMessage]);

  final String? serverMessage;
}

class DioConversationRepository implements ConversationRepository {
  DioConversationRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<Conversation>> getList({
    int limit = 20,
    int offset = 0,
    int? type,
  }) async {
    final queryParameters = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'type': ?type,
    };
    final response = await _dio.get<dynamic>(
      '/conversations',
      queryParameters: queryParameters,
    );

    return _parseConversationList(response.data);
  }

  @override
  Future<Conversation> getById(String id) async {
    final response = await _dio.get<dynamic>('/conversations/$id');
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Conversation detail is not a JSON object.');
    }
    return Conversation.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<Conversation> getPrivateByPeerId(int peerUserId) async {
    final response = await _dio.get<dynamic>(
      '/conversations/private/$peerUserId',
    );
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Conversation detail is not a JSON object.');
    }
    return Conversation.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<Conversation> createGroup({
    required String name,
    required List<int> memberIds,
  }) async {
    late final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '/conversations',
        data: <String, dynamic>{
          'type': 'group',
          'name': name,
          'member_ids': memberIds,
        },
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map && data['message'] is String
          ? (data['message'] as String).trim()
          : null;
      throw ConversationRequestException(
        message?.isNotEmpty == true ? message : null,
      );
    }
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Conversation detail is not a JSON object.');
    }
    return Conversation.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> markRead(String id) async {
    await _dio.post<dynamic>('/conversations/$id/read');
  }

  @override
  Future<void> hideFromList(String id) async {
    await _dio.delete<dynamic>('/conversations/$id');
  }
}

List<Conversation> _parseConversationList(dynamic payload) {
  if (payload is! List) {
    throw const FormatException('Conversation payload is not a list.');
  }

  return payload
      .map((dynamic item) {
        if (item is! Map) {
          throw const FormatException(
            'Conversation item is not a JSON object.',
          );
        }
        return Conversation.fromJson(Map<String, dynamic>.from(item));
      })
      .toList(growable: false);
}
