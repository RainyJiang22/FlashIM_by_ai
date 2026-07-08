import 'package:dio/dio.dart';

import 'message.dart';

abstract interface class MessageRepository {
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    int limit = 50,
  });
}

class DioMessageRepository implements MessageRepository {
  DioMessageRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    int limit = 50,
  }) async {
    final queryParameters = <String, dynamic>{'limit': limit};
    if (beforeSeq != null) {
      queryParameters['before_seq'] = beforeSeq;
    }

    final response = await _dio.get<dynamic>(
      '/conversations/$conversationId/messages',
      queryParameters: queryParameters,
    );

    final payload = response.data;
    if (payload is! List) {
      throw const FormatException('Message payload is not a list.');
    }

    final messages = payload.map((dynamic item) {
      if (item is! Map) {
        throw const FormatException('Message item is not a JSON object.');
      }
      return Message.fromJson(Map<String, dynamic>.from(item));
    }).toList();

    messages.sort(_compareMessagesAscending);
    return messages;
  }
}

int _compareMessagesAscending(Message left, Message right) {
  if (left.seq != right.seq) {
    return left.seq.compareTo(right.seq);
  }
  return left.createdAt.compareTo(right.createdAt);
}
