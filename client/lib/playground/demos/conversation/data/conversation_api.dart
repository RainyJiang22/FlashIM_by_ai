import 'package:dio/dio.dart';

import 'models/conversation_dto.dart';

abstract interface class ConversationRequest {
  Future<List<ConversationDto>> fetchConversations();
}

class DioConversationApi implements ConversationRequest {
  DioConversationApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<ConversationDto>> fetchConversations() async {
    final response = await _dio.get<dynamic>('/conversation');
    final payload = response.data;

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

          return ConversationDto.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
  }
}
