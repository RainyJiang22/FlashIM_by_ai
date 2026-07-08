import 'package:dio/dio.dart';

import 'conversation.dart';

abstract interface class ConversationRepository {
  Future<List<Conversation>> getList({int limit = 20, int offset = 0});

  Future<Conversation> getById(String id);

  Future<void> markRead(String id);
}

class DioConversationRepository implements ConversationRepository {
  DioConversationRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<Conversation>> getList({int limit = 20, int offset = 0}) async {
    final response = await _dio.get<dynamic>(
      '/conversations',
      queryParameters: <String, int>{'limit': limit, 'offset': offset},
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
  Future<void> markRead(String id) async {
    await _dio.post<dynamic>('/conversations/$id/read');
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
